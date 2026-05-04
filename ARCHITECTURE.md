# MPS — Canonical Architecture Document

> Produced by deep first-principles analysis of the v0.5.0 codebase.  
> For AI agents and developers evolving the system.

---

## 1. Core Vision and Goals

MPS is a **plain-text personal information system**, not merely a CLI todo-list. The ambition is to make the file system the database, the text editor the UI, and git the sync layer — eliminating every category of lock-in (app, cloud, account, format) while retaining structure and queryability.

The philosophical center: **structured data that looks like prose**. The `.mps` file format is a lightweight DSL — human-writable by hand, machine-parseable without a grammar library. This is the central design constraint everything else flows from.

The project name "MonoPsyches" (mono + psyche — single mind) encodes the intent: one plain-text system for a single human's cognitive life.

---

## 2. Macro Architecture

```
exe/mps
  └─ MPS::CLI::MPS (Thor)          ← thin command dispatcher
       ├─ MPS::Store                ← filesystem + query layer
       │    └─ MPS::Engines::Parser ← stack machine parser
       │         └─ MPS::Elements.* ← typed value objects
       └─ MPS::Config               ← YAML config holder
            └─ Logger

lib/mps.rb                          ← load sequencer
  ir() custom loader                ← require_relative with debug tracing
MPS::Constants                      ← anchors (regexps, paths, lambdas)
MPS::Interpolators.*                ← stub expansion system (not yet wired)
```

**Load order** (strictly enforced by `lib/mps.rb`):
```
version → mps/mps (defines ir + MPS module methods)
  → constants → config → interpolators → elements → engines → store → cli/mps
```

Each layer depends only on layers above it in this list. No circular dependencies exist in the current codebase.

---

## 3. Micro Architecture

### 3.1 The `.mps` DSL

```
@type[arg1, key: val, arg2]{
  body text (multi-line, arbitrary)
  @nested_type{
    nested body
  }
}
```

**Grammar rules (inferred from parser):**
- Element open: `@[a-zA-Z0-9_]+(\[...\])?{`
- Element close: `}` not surrounded by single-quotes
- Args: comma-separated; bare words → tags, `key: value` pairs → named attrs
- Nesting: arbitrary depth, no type restrictions on parent-child relationships
- Brackets: fully optional — `@task{ body }` and `@task[]{ body }` are identical

The DSL is deliberately **not** a traditional grammar (no PEG, no parslet, no BNF). It is a bracket-balanced expression language scanned positionally.

### 3.2 Parser (`lib/mps/engines/mps.rb`)

**Algorithm**: single-pass, position-advancing stack machine.

```
wrapped_content = "@mps[]{\n" + file_content + "\n}"
pos = 0
stack = []

while pos < size:
  open_match  = AT_REGEXP.match(wrapped, pos)
  close_match = END_CURLY_REGEXP.match(wrapped, pos)
  
  if open comes first:
    push frame { sign, args, body_start, child_counter, ref_path }
    advance pos to after open token
  else:
    pop frame
    extract body_str = content[body_start..close_pos]
    instantiate element by SIGNATURE_REGEX dispatch
    store in flat hash: "epoch.child_n.grandchild_n" => element_instance
    advance pos to after close token
```

Key design decisions:
- **Synthetic root wrapping**: file content is wrapped in `@mps[]{}` before parsing. This means the root-level MPS element always exists and provides a uniform nesting model. Every file is conceptually one `@mps` document.
- **Flat hash with ref-paths**: despite tree structure during parsing, the result is a flat `{ref => element}` hash. The hierarchy is encoded into the key string (`"1745000000.2.1"` = file epoch, 2nd top-level element, 1st child). This enables O(1) lookup of any element by address.
- **Exact element dispatch**: `SIGNATURE_REGEX = /\Atype\z/` prevents partial matches (e.g. `@taskboard` does not match `task`). This was a bug in pre-v0.5 code.
- **Unknown-element Struct**: unrecognized element types become `Engines::Parser::Unknown` Structs rather than being silently dropped or raising. The system is tolerant of forward-compatibility extensions.
- **No eval**: class lookup uses `Elements.const_get(k)` — safe reflection, not `eval`.

### 3.3 Element Type Registry

```
MPS::Elements::Task      SIGNATURE_STAMP="task"    SIGNATURE_REGEX=/\Atask\z/
MPS::Elements::Note      SIGNATURE_STAMP="note"    SIGNATURE_REGEX=/\Anote\z/
MPS::Elements::Log       SIGNATURE_STAMP="log"     SIGNATURE_REGEX=/\Alog\z/
MPS::Elements::Reminder  SIGNATURE_STAMP="reminder" SIGNATURE_REGEX=/\Areminder\z/
MPS::Elements::MPS       SIGNATURE_STAMP="mps"     SIGNATURE_REGEX=/\Amps\z/
```

All classes `include MPS::Element` mixin. The mixin provides:
- `initialize(args:, refs:, body_str:)` — standardized constructor
- `parsed_args` — calls `self.class.parse_args(raw_args)` if defined, else `{}`
- `tags` — `parsed_args.fetch(:tags, [])`
- `raw_args` — original unparsed arg string
- `display_str` — indented text rendering (currently unused by CLI)

**Discovery mechanism**: `Elements.constants.map { |k| Elements.const_get(k) }.select { |x| x.class == Class }` — dynamic, no explicit registration list. Adding a new element type means creating a file with the right class constants; the engine picks it up automatically.

**Dual identity constants**:
- `SIGNATURE_STAMP` — used for *writing* (appending to file, filtering, display badges)
- `SIGNATURE_REGEX` — used for *reading* (dispatch during parse)

This separation is intentional: reading and writing paths are decoupled, allowing future evolution of either without touching the other.

### 3.4 Argument Parsing

`Element.split_args("work, release, status: done")` → `{ attrs: { status: "done" }, tags: ["work", "release"] }`

The rule: parts containing `:` become named attrs; bare parts become tags. This is a fixed grammar built on comma-splitting — minimal, fragile for edge cases (colons in tag names), but sufficient for the current type system.

Each element class implements `self.parse_args(raw)` to project from the generic `{ attrs, tags }` hash into its semantic domain:
- Task: extracts `status` (default: `"open"`)
- Log: extracts `start` and `end`, derives `duration_minutes` and `duration_str`
- Reminder: extracts `at`
- Note, MPS: tags only

### 3.5 Store Layer

`MPS::Store` owns all filesystem operations. The CLI holds a `Store` instance and never touches `File`, `Dir`, or `IO` directly.

```ruby
Store#find_file(date)           → path | nil
Store#find_files(date)          → [path, ...]
Store#find_or_create_path(date) → path (new or existing, file not created)
Store#parse_date(date)          → { ref => element }
Store#append(type:, body:, ...)
Store#all_files                 → [path, ...]
Store#files_since(date)         → [path, ...]
Store#search(query, ...)        → [{ element:, file:, date_str: }, ...]
```

File naming: `YYYYMMDD.epoch.mps` (epoch from `Time.now.to_i` at creation). The epoch disambiguates multiple files per day. `MPS_FILE_NAME_CLIPPER` lambda extracts the epoch for use as the `base_ref` in ref-paths.

**Important**: `Store` takes `storage_dir` as its only constructor argument and is reinstantiated on every CLI command. It is stateless beyond the directory path — no caching, no in-memory index.

### 3.6 Configuration

`MPS::Config` is a thin YAML wrapper:
- `Config.init(path)` — writes defaults
- `Config.load_conf_hash(path)` — reads + validates (raises typed errors on missing keys)
- `Config.new(**hash)` — holds typed values + Logger instance

Required keys: `storage_dir`, `log_file`, `mps_dir`  
Optional keys (with defaults): `git_remote` (`"origin"`), `git_branch` (`"master"`)

The Logger formatter produces compact single-char severity codes: `[2026-05-05 14:30:00] I: message`.

### 3.7 The `ir()` Loader

```ruby
def ir(rltv_rb_fp)
  clf = caller_locations.first
  f, l = clf.path, clf.lineno
  rltv_rb_fp = File.expand_path(rltv_rb_fp, File.dirname(f))
  r = require_relative(rltv_rb_fp)
  puts("#{f} at #{l} for #{rltv_rb_fp}  #=> #{r}") if ENV["MPS_DEBUG"]=="true"
end
```

`ir` is a global function (not in any namespace) that wraps `require_relative` with caller-location resolution. It resolves paths relative to the *caller's* file, not `__dir__`. This enables indirection files (like `elements/elements.rb`, which just calls `ir "./task"` etc.) to chain requires without encoding absolute paths.

`MPS_DEBUG=true` activates verbose load tracing — every `ir` call prints `caller_file at line for resolved_path => already_loaded?`. This is a bespoke developer tool, not a standard Ruby pattern.

---

## 4. Design Patterns (Explicit and Emergent)

### Explicit

| Pattern | Where |
|---------|-------|
| Registry via module constants | `Elements.constants`, `Interpolators.constants` |
| Mixin composition | `Element` mixin included by all element classes |
| Value objects | Element instances are immutable after construction (no mutation methods) |
| Store/Repository | `MPS::Store` isolates all file I/O |
| Two-identity class constants | `SIGNATURE_STAMP` (write) + `SIGNATURE_REGEX` (read) |
| Synthetic root wrapping | Parser wraps file in `@mps{}` for uniform model |
| Stack machine | Parser uses explicit stack, not recursive descent |

### Emergent (not documented but visible in code)

| Pattern | Evidence |
|---------|----------|
| Convention-over-configuration element registration | No `register_element` call; naming convention triggers automatic inclusion |
| Ref-path addressing scheme | Dotted epoch-based keys provide stable element addresses |
| Two-level module namespacing | `MPS::Elements::Task`, `MPS::Interpolators::Time` — each subsystem in its own module |
| Flat hash with encoded hierarchy | Parse tree → flat hash preserving structure in key strings |
| Idempotent config initialization | `Config.init` only called when config doesn't exist; always reloads on every command |

---

## 5. Dependency and Layering Philosophy

The dependency graph is strictly hierarchical:

```
Constants  ←  Config  ←  Elements  ←  Engines  ←  Store  ←  CLI
    ↑              ↑          ↑            ↑
  (no deps)     Constants   Element mixin  Elements
```

**Key discipline**: the parser knows about element types via the `element_classes` parameter (dependency injection), not by directly requiring them. `Store` passes `Elements.constants`-derived classes to `Engines::Parser`. This is the most architecturally mature aspect of the system.

**External dependencies** are intentionally minimal:
- `thor` — CLI framework (command parsing, option handling, colored output)
- `chronic` — natural language date parsing (the only "smart" external dep)
- `tty-editor` — editor integration (abstracts Vim invocation)
- `cli-ui` — multi-file prompt selector
- `strscan` — listed but actually not used in current parser (uses `String#match(pos)` instead)

Note: `strscan` appears in gemspec but the parser uses `Regexp#match(string, pos)` directly. `StringScanner` appears only in `look_ahead_pos` (a public utility method that may be vestigial from an earlier implementation).

---

## 6. Composition and Extensibility Strategy

### Current extensibility model

**Adding a new element type** (e.g., `@habit`):
1. Create `lib/mps/elements/habit.rb` with class `MPS::Elements::Habit` that includes `Element`
2. Define `SIGNATURE_STAMP = "habit"` and `SIGNATURE_REGEX = /\Ahabit\z/`
3. Optionally define `self.parse_args(raw)` for custom attributes
4. Add `ir "./habit"` to `elements/elements.rb`

That's it. The parser, store, and registry all pick it up automatically. This is the intended extensibility mechanism — the system is designed to be grown this way.

**Adding a new interpolator** (e.g., `:env`):
1. Create `lib/mps/interpolators/env.rb` with class `MPS::Interpolators::Env`
2. Define `SIGNATURE_REGEX = /:env/` and `get_str(**ref)`
3. Add `ir "./env"` to `interpolators/interpolators.rb`

The interpolator registry is ready. **Wiring into the parser is missing** (see §9).

### Extensibility gaps

- No plugin system for third-party element types (would require modifying `elements/elements.rb`)
- No way to define custom display formatting for new element types without modifying CLI
- `print_tree` and `element_extra` in CLI are hardcoded to known element types via `is_a?` and `case` statements — new element types would render generically

---

## 7. Naming and Semantic Modeling Philosophy

**MonoPsyches primitives map directly to cognitive categories:**
- `task` — something to do (actionable, has status)
- `note` — something to remember (passive, no action)
- `log` — something that happened (retrospective, has duration)
- `reminder` — something at a time (prospective, has `at`)
- `mps` — a grouping/container (structural, no semantic content of its own)

This is a **minimal productive ontology** — not an elaborate taxonomy, just the five primitives a personal productivity system needs.

**Arg parsing as type system**: each element's `parse_args` defines what attributes are valid for that type. Tasks have `status`; logs have `start`/`end`; reminders have `at`. This is not enforced at the file level (any element can have any args string) but is enforced at the Ruby object level.

**File naming as identity**: `YYYYMMDD.epoch.mps` — the epoch is both a unique disambiguator and the root of the ref-path addressing scheme. Files are ordered chronologically by lexicographic sort on the filename prefix (YYYYMMDD sorts correctly as-is).

---

## 8. Architectural Strengths

1. **Parser correctness**: the position-advancing `Regexp#match(str, pos)` approach is clean, robust, and O(n) in document size. Eliminates the flip-flop boolean bug of v0.4.

2. **Element registry pattern**: new types require no modification to the parser or store. The `const_get` discovery is idiomatic Ruby metaprogramming without being opaque.

3. **Store isolation**: CLI has zero direct file I/O. This means the entire storage model can be swapped (e.g., to a database backend) by replacing `Store` without touching CLI logic.

4. **Ref-path addressing**: every element has a stable, unique address (`epoch.1.2`) that encodes both its file and its position. This is the seed of a future cross-reference or linking system.

5. **Composable filters**: `--type`, `--tag`, `--status`, `--since` compose freely across `list`, `search`, `stats`, `export`. The filtering logic in `visible?` is a single predicate reused across commands.

6. **FakeFS-isolated tests**: the test suite uses `FakeFS` for all filesystem operations, making tests fast, isolated, and portable. The `parse_content` helper in `engine_test.rb` is a particularly clean pattern.

7. **Asset-based integration tests**: `test/assets/` contains real `.mps` fixture files tested against the live parser. These catch parser regressions that unit tests might miss.

---

## 9. Weaknesses, Inconsistencies, and Technical Debt

### Dead code in Element mixin

- `attr_accessor :disp_str` — mutable attribute, never written to by anything
- `PADDING = '  '` and `display_str(...)` — defined but CLI uses `print_element` instead. Two parallel rendering paths exist; the mixin's path is the dead one.

### Interpolators are loaded but never invoked

`Engines::Parser#initialize` discovers `@interpolator_classes` from `Interpolators.constants`, but no code ever calls `get_str` on any interpolator. The `:time` interpolator (`Interpolators::Time`) is a complete, correctly structured stub — but it is an orphan. The call-site in the parser is missing.

### `MPS.get_filename_from_date` vs `MPS_NEW_FILE_NAME_GEN`

`MPS.get_filename_from_date(date)` returns `"YYYYMMDD.mps"` (no epoch). `Constants::MPS_NEW_FILE_NAME_GEN` returns `"YYYYMMDD.epoch.mps"`. The Store uses the lambda; the module method is used in tests and `get_filenames_from_date_range`. The test `mps_test.rb#test_date_range_file_names` asserts the no-epoch format, meaning it tests behavior that doesn't match what `Store` actually uses. This test is effectively wrong.

### `Engines::Parser` vs `Engines::MPS` naming

The real class is `Engines::Parser`. `Engines::MPS = Parser` is a backward-compat alias. `Store` uses `Engines::Parser` correctly. Engine tests use `Engines::MPS`. This split creates confusion about the canonical name.

### `look_ahead_pos` using `StringScanner`

This public class method uses `StringScanner` for what is effectively a one-shot `scan_until`. But the actual parser doesn't use it at all — it uses `Regexp#match(str, pos)` directly. `look_ahead_pos` appears to be a residue of an intermediate implementation. It's tested but not used in production paths.

### `git` and `autogit` code duplication

The `auto` subcommand of `git` and the `autogit` command have identical string-building logic. If the format changes (e.g., a different commit message), it must be updated in two places.

### `stats` command duplicates duration logic

Log duration computation (hours + minutes from `duration_minutes`) is duplicated inline in `stats` rather than delegating to `duration_str`. This creates two implementations of the same formatting logic.

### Config `mps_dir` not exposed

`Config` stores `@mps_dir` but has no `attr_reader :mps_dir`. It is only accessed via `conf_hash[:mps_dir]` in the CLI's `load_tangible_config_hash` method — never via a Config instance method.

### Argument parsing fragility

`Element.split_args` splits on `,` and then on `:`. This means any argument value containing a comma will be incorrectly split. Log times like `start: 09:00, end: 12:30` work because the colon is only in the key-value separator position — but this is fragile. A value like `at: "Monday, Tuesday"` would break.

---

## 10. Scalability and Evolution Potential

### What scales well

- **Storage model**: flat files sorted by date scale to thousands of files without index degradation. The `files_since` filter is `O(n)` string comparison — adequate for personal use at any realistic scale.
- **Element type system**: the registry pattern handles an unbounded number of element types without architectural change.
- **Search**: currently `O(files * elements)` linear scan. Sufficient for personal archives (< 10k files), inadequate for team or multi-year shared collections.

### What requires architectural change to scale

- **Search**: needs an index (SQLite, or even a flat text index) for sub-second queries over large archives.
- **Cross-file references**: the ref-path scheme (`epoch.1.2`) is stable within a file but has no inter-file linking mechanism. A `@ref[1745000000.2]` element type could be introduced, but the resolver doesn't exist.
- **Multi-user or shared storage**: the git integration is a naive personal-sync model. Concurrent writes to the same file are not handled.
- **Element mutation**: there's no way to update an existing element's status or attributes via CLI. `mps append` is append-only. Changing a task from open to done requires opening Vim.

---

## 11. Architectural Risks and Future Bottlenecks

### Risk 1: CLI fat vs store thin

The CLI currently holds rendering logic (`print_tree`, `element_extra`, `type_badge`) and filter logic (`visible?`, `filtered_elements`). As commands grow, the CLI file will become a God object. The Store layer only handles retrieval — it has no concept of "render" or "filter by display criteria." If more commands are added (e.g., a `tui` or `web` command), all the filter/render logic would need to be extracted to a separate Presenter or Query layer.

### Risk 2: Interpolator subsystem is a time bomb

The interpolator registry exists, is loaded on every run, and is tested nowhere. When someone finally wires it into the parser, it will need to handle: interpolation at parse time vs. render time, interpolation inside body vs. args, error handling for unknown interpolators, and recursive interpolation. None of these design questions have been resolved. The stub as written (`get_str(**ref)` returning a string) doesn't specify where in the element the substitution happens.

### Risk 3: Argument parsing is a leaky abstraction

The comma/colon parsing in `split_args` is not the same as the file-level `AT_REGEXP` argument parsing (which captures everything between `[` and `]`). These two parsers have different edge cases. A future richer argument syntax (quoted strings, nested brackets, typed values) would require replacing both parsers simultaneously.

### Risk 4: `ir()` as a global function

`ir` is defined in `lib/mps/mps.rb` as a top-level kernel-space method. This pollutes the global method namespace and can conflict with any gem that defines a method named `ir`. It also means the debug output is always available to anyone requiring `mps` — it's not scoped to the gem's own internals.

### Risk 5: No element mutation path

The system has no `update` or `edit-in-place` operation. All writes are append-only. This means tasks can only be marked done by opening the file in Vim. A future `mps done REFPATH` command would require a text rewrite of the file — a significantly more complex operation than append.

---

## 12. What This Project Is Naturally Evolving Into

Looking at what is implemented vs. what is stubbed vs. what the design patterns imply:

### Near-term: completion of the interpolation layer

The interpolator registry is built and ready. The next logical step is wiring `Interpolators` into the parser so that element bodies can contain dynamic content like `:time` or `:date`. This would make `.mps` files into **templates**, not just records.

### Medium-term: a personal knowledge graph DSL

The ref-path addressing scheme (`epoch.1.2.3`) is a flat, stable addressing system. Combined with an `@ref[path]` element type, this could become a cross-file linking mechanism. You'd be able to reference tasks from notes, link logs to tasks, and build a graph of connections across your daily files — a plain-text personal knowledge graph.

### Medium-term: query language

The composable filter flags (`--type`, `--tag`, `--status`, `--since`) are clearly evolving toward a more expressive query syntax. The natural next step is `mps query "type:task AND tag:work AND status:open since:monday"` — a mini query language over the file archive.

### Long-term: a personal data runtime

The architecture — DSL file format, typed element registry, ref-path addressing, interpolation hooks, store abstraction, CLI command set, git sync — is the skeleton of a **personal data runtime**: a system where plain-text files are the source of truth, the DSL is extensible, and the tooling layer is composable and scriptable. This is closer in spirit to Org-mode or Zettelkasten than to a task manager.

The Rust rewrite initiative (referenced in project memory) suggests the author envisions higher performance for the parser and store layer — likely driven by the search bottleneck that will become visible as the archive grows.

---

## Reference: Intentional vs. Accidental Architecture

| Decision | Type | Evidence |
|----------|------|----------|
| Registry via `const_get` | Intentional | Consistent across Elements and Interpolators |
| Synthetic root `@mps` wrapper | Intentional | Clean uniform model, clearly designed |
| `SIGNATURE_STAMP` vs `SIGNATURE_REGEX` duality | Intentional | Symmetrical across all element types |
| Ref-path addressing | Intentional | Tested, documented, used in export |
| `ir()` global loader | Intentional | Has debug mode, clearly maintained |
| `display_str` / `disp_str` dead code | Accidental | Leftover from pre-CLI rendering path |
| Interpolators unconnected | Accidental/incomplete | Ready structure, missing call-site |
| `Engines::MPS` alias | Intentional | Explicit backward-compat comment |
| `look_ahead_pos` unused | Accidental | Residue from intermediate implementation |
| `get_filename_from_date` epoch mismatch | Accidental | Test failure confirms it's an oversight |
| Duplicate git/autogit logic | Accidental | Copy-paste, no abstraction attempted |
