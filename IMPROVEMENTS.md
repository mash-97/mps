# MPS Improvements & Feature Roadmap

## Bugs

| # | File | Issue | Severity |
|---|------|-------|----------|
| B1 | `lib/mps/elements/*.rb` | `# frozen string_literal: true` missing the `_` — magic comment is silently ignored | Medium |
| B2 | `lib/cli/mps.rb:61` | `git pull orign master` — typo `orign` instead of `origin` | High |
| B3 | `lib/mps/engines/mps.rb:12` | Uses `eval("::MPS::Elements::#{k}")` — unsafe; use `const_get` | Medium |
| B4 | `test/config_test.rb` | All test bodies are commented out — zero test coverage on Config | High |
| B5 | `lib/mps/interpolators/` | Interpolators are loaded into `Engines::MPS` but never invoked anywhere | Medium |

## Code Quality

| # | Issue | Fix |
|---|-------|-----|
| Q1 | `ir()` is defined as a bare global method in `lib/mps/mps.rb` — pollutes `Object` | Move inside `MPS` module as `MPS.ir` or keep but at least document it |
| Q2 | Element classes are identical boilerplate — only `SIGNATURE_STAMP` / `SIGNATURE_REGEX` differ | Extract a `MPS::Elements.define(stamp)` factory or use a shared DSL |
| Q3 | `Engines::MPS` class name clashes with `Elements::MPS` class — confusing namespace | Rename engine to `Engines::Parser` |
| Q4 | `Exception` is rescued in every CLI command instead of `StandardError` — catches `SignalException`, `SystemExit` | Use `StandardError` |
| Q5 | Config is re-read on every CLI invocation but never cached or validated beyond key presence | Add type-checked struct |

## New Features

### F1 — `list` command
Display parsed elements from any `.mps` file in the terminal, with optional type filter.

```
mps list                    # today's file
mps list yesterday          # yesterday's file
mps list 20260226 --type task
```

### F2 — `search` command
Full-text search across all `.mps` files in storage, return matching elements.

```
mps search "meeting"
mps search "deploy" --type task --since 7.days.ago
```

### F3 — `stats` command
Print a summary of element counts per type for a date (or range).

```
mps stats                   # today
mps stats --since last.week
```

### F4 — `append` command (non-Vim fast entry)
Append a single element to today's file without opening Vim.

```
mps append task "Write release notes" --tags work,release
mps append note "Idea: dark mode"
mps append reminder "Standup" --at "9am"
```

### F5 — Typed element attribute parsing
Currently `@log[start: 09:00, end: 12:30]` args are raw strings. Parse them into typed structs so `list`/`stats` can compute duration, countdown to reminder time, etc.

### F6 — Export command
Serialize parsed elements to JSON or CSV.

```
mps export --format json > today.json
mps export --format csv --since last.week > week.csv
```

### F7 — Configurable branch / remote for git sync
`git auto` hardcodes `master` and `origin`. Make both configurable in `~/.mps_config.yaml`.

```yaml
git_remote: origin
git_branch: main
```

## Implementation Priority

1. **B1, B2, B3** — straightforward, low-risk fixes
2. **Q4** — safety (rescue `StandardError` not `Exception`)
3. **B4** — restore test coverage (Config + Engine parser)
4. **F1 `list`** — most immediately useful, builds on existing parser
5. **F4 `append`** — second most useful daily-driver feature
6. **F7 git config** — removes hardcoded branch/remote
7. **Q3 rename engine** — minor breaking internal rename
8. **F5 typed args** — enables F1/F3 to show richer output
9. **F2 `search`** — builds on F1 infrastructure
10. **F3 `stats`** — builds on F2
11. **F6 `export`** — nice-to-have
