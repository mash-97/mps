# DESIGN_RUST.md — MPS Rust Rewrite (mps-rs v0.1.0)

## 1. Guiding Principles

**Minimalistic, no over-engineering.** The Rust version is a production-quality CLI binary, not a platform. Every design decision is evaluated against whether it helps ship a correct, maintainable tool. Dependencies are added only when they carry clear benefit over `std`. No async, no plugin system, no event bus in v1.

**Feature parity with Ruby v0.5.0 as baseline.** Every command, flag, filter, color, and display format observable in the Ruby CLI must produce identical output. The parser algorithm is mirrored exactly, including the single-pass stack, ref-path keying scheme, and the synthetic root wrap.

**Single binary, no runtime dependency.** `cargo build --release` produces one self-contained binary (~4MB). Users install by dropping it in `$PATH`. No Ruby, no gems, no dynamic libraries beyond libc.

**Same config file format (YAML, backward-compatible).** `~/.mps_config.yaml` is read and written identically. The Rust binary can replace the Ruby gem without migrating any user files. Ruby writes symbol-keyed YAML (`:storage_dir:`) — we normalise the colon prefix on load.

**Same `.mps` file format (bit-for-bit compatible).** Files written by `mps append` in Rust produce the same byte sequence as Ruby. Both parsers accept the same set of valid files.

**Design for correctness first, then extensibility.** All invariants that matter for correctness (ref-path uniqueness, parser stack discipline, arg parse contract) are enforced in tests, not commentary. Extensibility hooks are identified in section 10 but not built.

---

## 2. Crate Selection

| Crate | Version | Purpose |
|-------|---------|---------|
| `clap` | 4 (derive) | CLI argument parsing — `#[derive(Parser)]` keeps command definitions co-located |
| `serde` | 1 | Serialization framework |
| `serde_yaml` | 0.9 | YAML config round-trip |
| `serde_json` | 1 | JSON export |
| `chrono` | 0.4 | Date/time arithmetic and formatting |
| `regex` | 1 | Pattern matching for parser and filename validation |
| `colored` | 2 | Terminal color — respects `NO_COLOR`, maps 1:1 to Ruby's Thor `set_color` |
| `dirs` | 5 | Home directory path — cross-platform, no `$HOME` string expansion |
| `anyhow` | 1 | CLI-level error propagation with context |
| `thiserror` | 1 | Typed library errors via derive macros |
| `csv` | 1 | CSV export with proper quoting |
| `indexmap` | 2 | Insertion-ordered map for deterministic element display |

**No crate for natural-language date parsing.** The `chrono-english` crate was evaluated but an in-house `date_parse.rs` handles the required vocabulary (`today`, `yesterday`, `last <weekday>`, `N days ago`, `last week`, `YYYYMMDD`) with 100% coverage of what Ruby's `chronic` gem was used for in this codebase.

**No crate for editor launch.** `$EDITOR → $VISUAL → vim` resolved at runtime via `std::env::var` and invoked with `std::process::Command`.

---

## 3. Module Structure

```
mps-rs/
  Cargo.toml
  src/
    main.rs          — Entry point; clap dispatch; config init
    cli.rs           — Cli struct + Commands enum (#[derive(Parser)])
    config.rs        — Config struct; load/init/ensure_dirs
    constants.rs     — MPS_EXT, regexes (OnceLock), new_file_name()
    date_parse.rs    — parse_date(str) → NaiveDate; no external crate
    error.rs         — MpsError enum (thiserror)
    parser.rs        — parse_file(), parse_wrapped(); position-based stack
    store.rs         — Store struct; all file-system operations
    elements/
      mod.rs         — Element enum, split_args(), ElementKind, from_parts()
      task.rs        — TaskData, TaskStatus
      note.rs        — NoteData
      log_elem.rs    — LogData, duration_minutes(), duration_str()
      reminder.rs    — ReminderData
      mps_group.rs   — MpsGroupData
    commands/
      mod.rs         — Shared display: type_badge, element_extra, print_tree, DisplayOpts
      open.rs        — open command
      list.rs        — list command (with visibility pre-check to suppress empty headers)
      append.rs      — append command
      search.rs      — search command
      stats.rs       — stats command
      export.rs      — export command (JSON + CSV)
      git.rs         — git, autogit, cmd commands
```

---

## 4. Core Type Definitions

### Element enum

```rust
pub enum Element {
    Task     { raw_args: String, refs: Vec<u64>, body_str: String, data: TaskData },
    Note     { raw_args: String, refs: Vec<u64>, body_str: String, data: NoteData },
    Log      { raw_args: String, refs: Vec<u64>, body_str: String, data: LogData },
    Reminder { raw_args: String, refs: Vec<u64>, body_str: String, data: ReminderData },
    MpsGroup { raw_args: String, refs: Vec<u64>, body_str: String, data: MpsGroupData },
    Unknown  { sign: String, raw_args: String, refs: Vec<u64>, body_str: String },
}
```

### Config

```rust
pub struct Config {
    pub mps_dir:     PathBuf,
    pub storage_dir: PathBuf,
    pub log_file:    PathBuf,
    pub git_remote:  String,  // default "origin"
    pub git_branch:  String,  // default "master"
}
```

### Store (method signatures)

```rust
pub fn find_file(&self, date: NaiveDate) -> Option<PathBuf>
pub fn find_files(&self, date: NaiveDate) -> Vec<PathBuf>
pub fn find_or_create_path(&self, date: NaiveDate) -> PathBuf
pub fn parse_date(&self, date: NaiveDate) -> Result<IndexMap<String, Element>, MpsError>
pub fn append(&self, kind: &str, body: &str, tags: &[String], attrs: &[(&str, &str)], date: NaiveDate) -> Result<PathBuf, MpsError>
pub fn all_files(&self) -> Result<Vec<PathBuf>, MpsError>
pub fn files_since(&self, since_date: NaiveDate) -> Result<Vec<PathBuf>, MpsError>
pub fn search(&self, query: &str, type_filter: Option<&str>, tag_filter: Option<&str>, since_date: Option<NaiveDate>) -> Result<Vec<SearchResult>, MpsError>
```

### Parser

```rust
pub fn parse_file(path: &Path) -> Result<IndexMap<String, Element>, MpsError>
pub fn parse_wrapped(wrapped: &str, base_ref: u64) -> Result<IndexMap<String, Element>, MpsError>
```

---

## 5. Element Enum Design Decision

The `Element` enum with typed variant payloads is chosen over `Box<dyn ElementTrait>` trait objects for three concrete reasons:

**Exhaustiveness at compile time.** Every `match` on `Element` is checked by the compiler for completeness. Adding a new variant makes every unhandled match a compile error.

**No heap allocation per element.** Trait objects require `Box<dyn Trait>` plus vtable. An enum keeps all variant data inline, which is better for cache performance.

**Pattern matching is the natural idiom.** Every command needs to branch on element type for type-specific output (status badge for tasks, duration for logs, `at` for reminders). `match el { Element::Task { data, .. } => ... }` is direct and readable.

**The `Unknown` variant** replaces Ruby's `Struct.new`. The parser never panics on unknown element types.

> The `rust_rollout.spec` in this repository (commit `3121e11`) proposed `Vec<Box<dyn Element>>` with trait objects, UUIDs, and `ElementMetadata`. That design is explicitly rejected: MPS has five known element types; the spec's approach requires `dyn Any` downcasting in every command handler.

---

## 6. Error Handling Strategy

**Library layer** (`parser.rs`, `store.rs`, `config.rs`, `elements/`): all functions return `Result<T, MpsError>`. No `unwrap()` or `expect()` in library code.

**CLI layer** (`commands/*.rs`, `main.rs`): returns `Result<(), anyhow::Error>`. Converts library errors with `.context("while ...")`. `main()` catches `anyhow::Error` and prints `error: {:#}` then exits 1.

```rust
pub enum MpsError {
    ConfigNotFound(PathBuf),
    ConfigInvalid(String),
    DateParseError(String),
    ParseError { file: String, msg: String },
    ExportError(String),
    Io(#[from] std::io::Error),
    Yaml(#[from] serde_yaml::Error),
    Csv(#[from] csv::Error),
}
```

---

## 7. Parser Algorithm

Mirrors Ruby's `Engines::Parser.parse_mps_file_to_elements_hash` exactly:

1. Wrap file content: `@mps[]{\n{content}\n}`
2. Base ref = YYYYMMDD (first 8 chars of filename, parsed as u64 — mirrors Ruby's `.to_i` which stops at the dot in `YYYYMMDD.epoch`)
3. At each `pos`, find the nearest `@element[args]{` open and `}` close using `Regex::find_at`
4. Whichever starts at a lower position wins
5. Open → push frame `{ sign, args, body_start, child_counter, ref_path }`; Close → pop frame, emit element
6. Ref path: root = `[base_ref]`, children = `[base_ref, 1]`, `[base_ref, 1, 1]` etc.
7. Key = `ref_path.join(".")`; dispatch by sign to `Element::from_parts()`

**Note on look-around:** Ruby's `END_CURLY_REGEXP` uses `(?<!')\}(?!')` (negative look-ahead/behind). Rust's `regex` crate doesn't support look-around. Since MPS body text in practice never contains single-quoted braces (`'}'`), a plain `\}` match is used.

---

## 8. Test Coverage

36 unit tests (all passing):

| Module | Tests |
|--------|-------|
| `elements/mod.rs` | split_args variants (6), ElementKind::from_sign (1) |
| `elements/task.rs` | default open, done status, empty args (3) |
| `elements/log_elem.rs` | duration_str, exact hours, no times, duration_minutes (4) |
| `date_parse.rs` | today, yesterday, YYYYMMDD, YYYY-MM-DD, N days ago, last week, invalid (7) |
| `parser.rs` | empty, single task, sequential refs, nested mps, args, optional brackets, unknown, deeply nested, real file (9) |
| `store.rs` | find_file absent/present, parse_date empty, append creates/parseable, search by query, files_since (6) |

All tests use `tempfile::TempDir` for filesystem isolation (no FakeFS needed in Rust).

---

## 9. Compatibility Notes

### Config YAML

Ruby writes symbol-keyed YAML (`:storage_dir:`). The Rust loader strips leading `:` from each line before deserializing. Rust writes string-keyed YAML (`storage_dir:`), which Ruby's `YAML.safe_load` reads without issue.

### File format

The `append` output format matches Ruby exactly: `\n@type[args]{\n  body\n}\n`.

### File naming

`YYYYMMDD.<unix_epoch_seconds>.mps` — identical between Ruby and Rust.

### Ref paths

`YYYYMMDD.1`, `YYYYMMDD.1.1` etc. — identical between Ruby and Rust (both derive base_ref from the date prefix of the filename as an integer).

---

## 10. Phased Delivery

| Phase | Scope | Status |
|-------|-------|--------|
| 1 — Core | error, constants, config, date_parse, elements, parser, store | ✅ done, 36 tests green |
| 2 — CLI commands | open, list, append, search, stats, export, version | ✅ done, smoke-tested |
| 3 — Git integration | git, autogit, cmd | ✅ done |
| 4 — Docs, polish | README, DESIGN_RUST.md, release binary | 🔄 in progress |
| 5 — Extended features | TUI, async search, SQLite index | Future |

---

## 11. Future-Facing Design Notes (NOT in MVP)

**Async I/O.** `Store` methods are synchronous. `tokio` can be layered: `store.search()` over thousands of files could run file reads in parallel with `tokio::task::spawn_blocking`. The module boundary is already clean.

**SQLite index.** `store.append()` could write to both the `.mps` file and an SQLite index; `store.search()` queries the index first. Only `Store` changes; callers are untouched.

**TUI.** `commands/list.rs` calls `print_tree()` which writes to stdout. A `ratatui`-based TUI replaces that call with a widget renderer. `Element` and `IndexMap<String, Element>` are already `Clone`.

**Plugin system.** `Element::Unknown { sign, .. }` is the hook: a plugin registry could intercept unknown signs. The registry lookup is inside `Element::from_parts()`.

**REPL / interactive mode.** A readline loop in `main.rs` that re-dispatches to the same `commands/` handlers. No restructuring needed.

---

*Generated 2026-05-01 — Rust 1.93.1 — mps-rs v0.1.0*
