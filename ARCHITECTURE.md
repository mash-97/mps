# MPS — Canonical Architecture Document

> Updated for v1.0. Reflects all Phase 1–7 changes.
> For AI agents and developers evolving the system.

---

## 1. Core Vision and Goals

MPS is a **plain-text personal information system**. The file system is the database, the text editor is the UI, and git is the sync layer. The `.mps` DSL is lightweight, human-writable, and machine-parseable without a grammar library.

Philosophy: **structured data that looks like prose**. Every design decision flows from keeping files readable in any text editor while remaining richly queryable at the command line.

---

## 2. Load Order

```
lib/mps.rb
  require mps/version
  require mps/mps          ← MPS module methods
  require mps/constants
  require mps/config
  require mps/interpolators/interpolators
  require mps/elements/elements
  require mps/engines/engines
  require mps/ref_resolver      ← Phase 3
  require mps/query             ← Phase 7
  require mps/presenter         ← Phase 7
  require mps/store
  require cli/mps               ← thin dispatcher (defines MPS::CLI::MPS)
  require mps/cli/commands      ← auto-discovers lib/mps/cli/commands/*.rb
```

Each layer depends only on layers above it. No circular dependencies.

---

## 3. Macro Architecture

```
exe/mps
  └─ MPS::CLI::MPS (Thor, thin dispatcher)
       │   shared helpers: init, store, date_range, type_badge,
       │                   print_tree, format_duration, auto_git_cmd
       │
       ├─ lib/mps/cli/commands/*.rb  (self-registering via class_eval)
       │    open, list, append, update, done, search, stats,
       │    export, git, autogit, cmd, config, tags, version
       │
       ├─ MPS::Query          ← filter predicate object (Phase 7)
       ├─ MPS::Presenter      ← rendering object (Phase 7)
       ├─ MPS::RefResolver    ← human↔epoch ref translation (Phase 3)
       │
       └─ MPS::Store          ← all filesystem operations
            └─ MPS::Engines::Parser  ← stack machine parser
                 └─ MPS::Elements.*  ← typed value objects
```

---

## 4. Micro Architecture

### 4.1 The `.mps` DSL (unchanged from v0.5)

```
@type[arg1, key: val]{
  body
  @nested_type{ child }
}
```

Optional brackets; arbitrary nesting; comma-separated args where bare words → tags and `key: val` → named attrs.

### 4.2 Element Schema DSL (Phase 2)

The core architectural addition of v1. Each element class declares a typed attribute schema using a class macro:

```ruby
class Task
  include Element
  SIGNATURE_STAMP = "task"
  SIGNATURE_REGEX = /\Atask\z/

  attribute :status, type: :string, default: "open", flag: "status", aliases: ["-s"]
end
```

`Element.included` extends the class with `ClassMethods`, which provides:
- `attribute(name, type:, default:, flag:, aliases:)` — declares a schema entry
- `schema` — frozen public view of declared attributes
- `_schema` — mutable backing store (used internally and in tests)
- `parse_args(raw)` — schema-driven implementation; subclasses no longer override this

**Guiding principle**: adding a new attribute to an element requires exactly one schema declaration. The parser, filter predicates, export output, and future CLI option generation all derive from that single declaration.

Current schema per type:

| Type | Attributes |
|------|------------|
| Task | `:status` (default: "open") |
| Log | `:start`, `:end` |
| Reminder | `:at` |
| Note | — (tags only) |
| MPS | — (tags only) |

### 4.3 Parser (unchanged algorithm, extended interface)

Single-pass stack machine. Position-advancing via `Regexp#match(str, pos)`. Returns a flat `{ "YYYYMMDD.n.m" => element }` hash. Ref-path encoding: date integer (YYYYMMDD) as the epoch base, then sequential child counters.

**v1 extension**: accepts `interpolator_classes:` keyword argument. After the main parse loop, `_apply_interpolations` mutates body strings in-place for any registered interpolator patterns.

Backward-compat alias: `Engines::MPS = Engines::Parser` retained.

### 4.4 RefResolver (Phase 3)

`MPS::RefResolver.new(elements_hash)` builds a bidirectional mapping between epoch refs and human refs at construction time.

**Human ref format**:
- Top-level: `{type}-{n}` where `n` is sequential per type (e.g. `task-1`, `note-2`)
- Nested: `{parent_human}.{child_index}` (e.g. `mps-1.1`, `task-2.3`)

**API**:
- `to_human(epoch_ref)` → human ref string or nil
- `to_epoch(human_ref)` → epoch ref string or nil
- `resolve(ref_str)` → epoch ref (accepts either form)
- `all_epoch_refs` → sorted list

The resolver is ephemeral — instantiated per-request, not cached. Store exposes `resolver_for(date)`.

### 4.5 Store (extended for Phase 3 + Phase 4)

`MPS::Store.new(storage_dir)` now also collects `@interpolator_classes` and passes them to every parser call.

**New methods**:
- `resolver_for(date)` → `RefResolver` for that date's elements
- `rewrite_element(ref_str, new_attrs, date: Date.today)` → boolean

`rewrite_element` accepts both epoch refs and human refs. Human refs are resolved using a `RefResolver` for the given date. The rewrite:
1. Reads the file into memory
2. Parses to find the element and its `raw_args`
3. Merges `new_attrs` over existing `parsed_args`, preserving tags
4. Builds a new args string (`attr: val` pairs first, then tags)
5. Replaces the `@type[old_args]{` opening via `String#sub` with a compiled regex
6. Writes to `path.tmp.PID` then `File.rename` (atomic on POSIX)

**Known limitation**: if the same type+args combination appears multiple times in a file, `sub` replaces only the first occurrence. For typical personal files this is acceptable.

### 4.6 Query (Phase 7)

`MPS::Query.new(opts)` encapsulates all filter logic. No Thor dependency.

- `apply(elements_hash)` → filtered hash (MPS containers excluded)
- `apply_for_tree(elements_hash)` → filtered hash preserving MPS containers when their children are visible

Schema-driven attr filters: iterates all element classes' schemas, maps `flag:` → `opts[flag_sym]`, applies as filter predicates. Adding `attribute :location, flag: "location"` to Task automatically makes `Query.new(location: "home")` filter by location.

### 4.7 Presenter (Phase 7)

`MPS::Presenter.new(elements_hash, color_fn:, resolver:, with_refs:)` renders to string without Thor dependency.

- `render_tree` → [rendered_string, shown_count]
- `render_element(el, depth:)` → single line string
- `render_tag_table` → tag frequency table string

Colorization is injected via `color_fn:` proc. CLI passes `method(:set_color)` from Thor context. Tests use the default ANSI fallback or plain text (color_fn: nil disables ANSI).

### 4.8 CLI Modularization (Phase 5)

`lib/cli/mps.rb` is now a **thin dispatcher**. It defines:
- Thor class header (class_option, default_task, exit_on_failure)
- `self.start` override for `default_command` config
- `version` command (tiny, lives here)
- All private shared helpers

**Each command is a separate file** under `lib/mps/cli/commands/`. Commands self-register by calling `MPS::CLI::MPS.class_eval { ... }` at load time. This works because `cli/mps.rb` (the dispatcher) is loaded before `mps/cli/commands` in `lib/mps.rb`.

`lib/mps/cli/commands.rb` auto-discovers and loads all `*.rb` files in the `commands/` directory:

```ruby
Dir[File.join(__dir__, "commands", "*.rb")].sort.each { |f| require f }
```

**Adding a command = adding a file. No other changes required.**

---

## 5. Design Patterns

| Pattern | Where |
|---------|-------|
| Schema DSL (class macro) | `Element.attribute` |
| Registry via module constants | Elements, Interpolators auto-discovery |
| Mixin composition | `Element` mixin included by all element types |
| Command self-registration | `class_eval` on dispatcher |
| Auto-discovery loader | `mps/cli/commands.rb` globs directory |
| Dependency injection | `color_fn:` in Presenter |
| Atomic file write | tmp + rename in `rewrite_element` |
| Resolver pattern | `RefResolver` translates between ref forms |
| Query object | `MPS::Query` encapsulates filter predicates |

---

## 6. Dependency Layering

```
Constants → Config → Elements (schema DSL)
                   → Engines::Parser (uses element classes + interpolators)
                   → RefResolver (uses elements hash)
                   → Query (uses element schemas)
                   → Presenter (uses element classes + Query)
                   → Store (uses Parser + RefResolver)
                   → CLI dispatcher (uses Store + Query + Presenter)
                        → command files (CLI layer)
```

**The CLI never instantiates Elements directly.** Store is the only gateway.

---

## 7. Resolved Technical Debt (v0.5 → v1.0)

| Debt item | Resolution |
|-----------|-----------|
| `git` / `autogit` code duplication | Extracted `auto_git_cmd` private method |
| Dead `display_str` / `disp_str` / `PADDING` | Removed from Element mixin |
| `get_filename_from_date` epoch mismatch | Delegates to `MPS_NEW_FILE_NAME_GEN` |
| `Engines::MPS` in tests | Updated to `Engines::Parser` |
| `Config#mps_dir` missing | Added `attr_reader :mps_dir` |
| `stats` inline duration math | Uses `format_duration` helper |
| Bespoke `parse_args` per element | Replaced by schema-driven `ClassMethods#parse_args` |
| `visible?` hardcoded `:status` | Schema-driven attr filters in `Query` |
| CLI monolith | Modularized into `commands/` directory |
| Interpolators unconnected | Wired via `interpolator_classes:` param |
| No mutation path | `Store#rewrite_element` + `update`/`done` commands |
| No human-readable refs | `RefResolver` + `--refs` flag on `list` |

---

## 8. Remaining Known Issues

| Issue | Notes |
|-------|-------|
| `rewrite_element` replaces first occurrence only | Acceptable for personal files; needs position tracking for robustness |
| `Engines::MPS = Parser` alias | Retained for backward compat; can be removed in v1.1 |
| Human refs for today only | Epoch refs work for any date; human refs require `--date` for non-today |

---

## 9. Extension Points

### Adding a new element type

1. Create `lib/mps/elements/widget.rb` with `class MPS::Elements::Widget; include Element; SIGNATURE_STAMP = "widget"; SIGNATURE_REGEX = /\Awidget\z/`
2. Declare attributes: `attribute :foo, type: :string, flag: "foo"`
3. Add `require_relative "./widget"` to `elements/elements.rb`

Parser, Store, Query, and Presenter all pick it up automatically. The CLI `append` command accepts the type. `update` options are generated from the schema at class-load time.

### Adding a new command

1. Create `lib/mps/cli/commands/mycommand.rb`
2. Write `MPS::CLI::MPS.class_eval { desc "mycommand ARGS", "desc"; def mycommand(...) ... end }`
3. No other changes required — the auto-discovery loader picks it up

### Adding a new interpolator

1. Create `lib/mps/interpolators/myinterp.rb` with `SIGNATURE_REGEX = /:myinterp/` and `get_str`
2. Add `require_relative "./myinterp"` to `interpolators/interpolators.rb`

The store passes all discovered interpolators to the parser automatically.

---

## 10. Phase Roadmap Summary

| Phase | Scope | Status |
|-------|-------|--------|
| 1 | Technical debt cleanup | ✓ Done |
| 2 | Element attribute schema DSL | ✓ Done |
| 3 | RefResolver (human-readable refs) | ✓ Done |
| 4 | Element mutation (`rewrite_element`, `update`, `done`) | ✓ Done |
| 5 | CLI modularization (self-registering commands) | ✓ Done |
| 6 | Surface expansion (`tags`, `config`, `default_command`, `aliases`, interpolators) | ✓ Done |
| 7 | Query + Presenter extraction | ✓ Done |

**Out of scope for v1**: interactive TUI, LLM integration, cross-file `@ref` linking, SQLite search index.

---

## 11. Next Architectural Moves (v1.1+)

- **Position tracking in parser**: store byte offsets per element for robust rewrite (no collision risk)
- **SQLite search index**: for sub-second search over large archives
- **Cross-file `@ref` element**: using epoch refs as stable identifiers
- **Query language**: `mps query "type:task AND tag:work since:monday"`
- **Rust parser rewrite**: for performance-critical path (parser + store)
- **Remove `Engines::MPS` alias** now that all callers use `Engines::Parser`
