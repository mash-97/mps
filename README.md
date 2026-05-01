# MPS (MonoPsyches)

MPS is a plain-text personal productivity CLI. Tasks, notes, reminders, and logs live in date-stamped `.mps` files stored in `~/.mps/mps/`. Files are opened in Vim; a git integration handles sync. Everything is plain text — no app, no database, no account.

## Features

- **Date-based files** — one or more `.mps` files per day (`20260428.1745000000.mps`)
- **Structured elements** — tasks (with status), notes, reminders (with time), logs (with duration)
- **Nested elements** — `@mps{ @task{ ... } }` for grouping; `list` renders the tree
- **Typed argument parsing** — tags and named attrs (`status: done`, `at: 5pm`, `start: 09:00, end: 12:30`)
- **Full command set** — `list`, `append`, `search`, `stats`, `export`, `open`, `git`, `autogit`, `cmd`
- **Date ranges** — every listing/search/stats/export command accepts `--since` for multi-day views
- **Git integration** — configurable remote and branch; `autogit` stages, commits, pulls, and pushes in one shot
- **Plain text storage** — grep it, pipe it, open it in any editor

## Installation

```bash
gem install mps
```

Or add to your Gemfile:

```ruby
gem 'mps'
```

## Quick start

```bash
mps                   # open today's file in Vim
mps list              # print today's elements (nested tree)
mps append task "Fix the token bug" --tags backend --status open
mps search "token" --type task --since "last week"
mps stats --since monday
mps export --format csv --since "2026-04-01" > april.csv
mps autogit           # stage + commit + pull + push
```

See [GETTING_STARTED.md](GETTING_STARTED.md) for a full walkthrough with examples.

## Commands

| Command | Description |
|---------|-------------|
| `mps [open] [date]` | Open a date's file in Vim (default: today) |
| `mps list [date]` | Print elements as an indented tree |
| `mps append TYPE BODY` | Append one element to today's file without Vim |
| `mps search QUERY` | Full-text search across all `.mps` files |
| `mps stats [date]` | Element counts and log durations |
| `mps export [date]` | JSON or CSV to stdout |
| `mps autogit` | Stage, commit, pull, push |
| `mps git ARGS` | Any git command inside storage dir |
| `mps cmd ARGS` | Any shell command inside storage dir |
| `mps version` | Print version |

## File format

```
@task[work, release]{
  Ship the API refactor
}

@note{
  The auth token expiry edge case needs a second look
}

@reminder[at: 10am]{
  Team standup
}

@log[start: 09:00, end: 12:30]{
  Debugging the auth flow
}

@mps{
  @task[backend]{
    Nested task inside a sub-block
  }
}
```

Brackets are optional — `@task{ body }` is valid. Elements nest freely.

## Configuration

On first run MPS writes `~/.mps_config.yaml`:

```yaml
mps_dir: ~/.mps
storage_dir: ~/.mps/mps
log_file: ~/.mps/mps.log
git_remote: origin
git_branch: main
```

## Architecture

MPS follows a layered architecture: parser → element types → store → CLI.

### Load order

```
mps/version → mps/mps (defines ir()) →
  mps/constants → mps/config → mps/interpolators →
  mps/elements → mps/engines → mps/store → cli/mps
```

### Parser (`lib/mps/engines/mps.rb`)

A single-pass, position-based stack parser. Each iteration finds the nearest `@element[args]{` or `}` from the current position; whichever comes first wins. A stack frame carries the element sign, args, body start offset, child counter, and ref path. Closed frames become element instances, keyed by dotted ref paths (`epoch.1.2` = second child of first top-level element).

### Elements (`lib/mps/elements/`)

Each type includes the `Element` mixin which provides `split_args`, `parsed_args`, `raw_args`, and `tags`. Type-specific `parse_args` class methods handle named attributes: tasks have `status`, logs have `start`/`end` (from which `duration_minutes` and `duration_str` are derived), reminders have `at`.

### Store (`lib/mps/store.rb`)

A library class that owns all filesystem work — finding files by date, creating new paths, parsing, appending, searching. The CLI delegates entirely to Store; there are no direct file operations in `lib/cli/mps.rb`.

---

## Before and after: what Claude changed

The pre-Claude baseline (commit `66ac095`) had only five commands (`open`, `git`, `autogit`, `cmd`, `version`) and a fragile engine. Here is what changed and why.

### Parser

| Before | After |
|--------|-------|
| Flip-flop `at_first` boolean; double `scan_until` per loop | Position-based stack: `Regexp#match(str, pos)` picks nearer of open/close each iteration |
| `AT_REGEXP` required brackets — `@task{ }` was invisible | Brackets made optional: `(?:\[(?<args>[^\]]*)\])?` |
| Partial sign match `/task/` could match `@taskboard` | Exact match `/\Atask\z/` |
| `eval("::MPS::Elements::#{k}")` for class lookup | `Elements.const_get(k)` — no code evaluation |
| `instance_eval("attr_accessor :disp_str")` on Unknown | `Unknown = Struct.new(:ecn, :args, :refs, :body_str)` |
| `rescue Exception` swallowed signals | `rescue StandardError` throughout |

### Element types

| Before | After |
|--------|-------|
| No argument parsing — args string was opaque | `split_args` parses `"work, status: done"` → tags + attrs hash |
| No status, duration, or time accessors | `done?`, `open?`, `duration_str`, `duration_minutes`, `at` |
| `# frozen string_literal: true` (space typo, magic comment inactive) | `# frozen_string_literal: true` |

### Store layer

Before: CLI methods did their own `Dir.glob`, `File.read`, and `File.write`. No shared abstraction.

After: `MPS::Store` owns all file operations. One place to fix bugs; CLI is thin orchestration only.

A specific fix during Store development: `Dir.glob().grep(MPS_FILE_NAME_REGEXP)` matched against full paths (e.g. `/home/you/.mps/mps/20260428.mps`) while the regexp was anchored to basenames. Changed to `.select { |f| File.basename(f) =~ regexp }`.

### CLI

| Before | After |
|--------|-------|
| `open`, `git`, `autogit`, `cmd`, `version` | + `list`, `append`, `search`, `stats`, `export` |
| `git pull orign master` typo | `git pull #{git_remote} #{git_branch}` (configurable) |
| `git_remote`/`git_branch` hardcoded | Read from config YAML |
| No output formatting | Colorized type badges, status/duration/time extras, nested tree |

## Requirements

- Ruby >= 2.3.0
- Vim (for `open` / default command)
- Git (for `git` / `autogit`)

## Dependencies

- `thor` — CLI framework
- `tty-editor` — editor integration
- `chronic` — natural-language date parsing
- `cli-ui` — terminal UI (multi-file prompt)
- `strscan` — string scanning in parser

## Contributing

Bug reports and pull requests are welcome at https://github.com/mash-97/mps.

## License

MIT License.
