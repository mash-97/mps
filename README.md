# MPS — MonoPsyches

Your tasks, notes, logs, and reminders in plain-text files. One file per day, stored in `~/.mps/mps/`, opened in Vim, synced through git. No app, no account, no database.

```
$ mps list --refs

  task-1        [task] (open) Review the API pull request [work]
  reminder-1    [reminder] (10am) Team standup
  note-1        [note] Auth token expiry edge case needs a second look
  mps-1         [@mps] sprint
    mps-1.1       [task] (done) Set up the CI pipeline [devops]
    mps-1.2       [task] (open) Write migration script [backend]
```

---

## Install

```bash
gem install mps
```

First run creates `~/.mps_config.yaml` and your storage directory automatically.

---

## Features

- **Plain-text storage** — one `.mps` file per day; grep it, pipe it, open it in any editor
- **Four element types** — `@task`, `@note`, `@log`, `@reminder` with typed arguments
- **Nested elements** — `@mps{ @task{...} }` groups render as an indented tree
- **Quick capture** — `mps append task "idea"` lands in today's file without opening Vim
- **In-place editing** — `mps done task-1` or `mps update task-1 --status done` rewrites the file atomically
- **Full-text search** — across your entire archive; filter by type, tag, or date
- **Tag frequency** — `mps tags --all` renders a bar chart of everything you've ever tagged
- **Stats at a glance** — open/done counts and total logged hours per day, with totals across ranges
- **Natural language dates** — `mps list "last friday"`, `mps stats --since monday`
- **Git integration** — `mps autogit` stages, commits, pulls, and pushes in one shot

---

## Quick start

It's Monday morning. You open your terminal:

```bash
mps                  # open today's file in Vim — write your plan, save, quit
mps list             # see everything you wrote
mps list --refs      # same view, with addressable refs like task-1, note-2
```

You're deep in work. A thought hits you:

```bash
mps append task "Check if the race condition only happens under load" --tags backend
mps done task-1      # mark something finished without leaving the terminal
```

End of week:

```bash
mps stats --since monday          # task counts + logged hours per day
mps tags --all                    # what you've been spending time on
mps search "auth" --type log      # find that debugging session from last week
mps autogit                       # commit and push everything
```

See [GETTING_STARTED.md](GETTING_STARTED.md) for the full walkthrough.

---

## Commands

| Command | What it does |
|---------|-------------|
| `mps [open] [DATE]` | Open today's (or a date's) file in Vim |
| `mps list [DATE]` | Print elements as a nested tree |
| `mps append TYPE BODY` | Add one element to today's file without Vim |
| `mps update REFPATH` | Update an element's attributes in-place |
| `mps done REFPATH` | Mark a task done (shorthand for `update --status done`) |
| `mps search QUERY` | Full-text search across all `.mps` files |
| `mps stats [DATE]` | Element counts and log durations |
| `mps tags [DATE]` | Tag frequency bar chart |
| `mps export [DATE]` | JSON or CSV to stdout |
| `mps config [show\|edit]` | View or edit your configuration |
| `mps autogit` | Stage, commit, pull, push |
| `mps git ARGS` | Any git command inside your storage directory |
| `mps cmd ARGS` | Any shell command inside your storage directory |
| `mps version` | Print version |

Every listing, stats, search, and tags command accepts `--since DATESIGN` for multi-day views and `--all` to span your entire archive.

---

## File format

```
@task[work, release]{
  Ship the API refactor
}

@note{
  Auth token expiry edge case needs a second look
}

@reminder[at: 10am]{
  Team standup
}

@log[start: 09:00, end: 12:30]{
  Debugging the auth flow
}

@mps[sprint]{
  @task[backend]{
    Nested task inside a sprint block
  }
}
```

Brackets are optional — `@task{ body }` is valid. Elements nest freely. Files are named `YYYYMMDD.<epoch>.mps` (epoch disambiguates multiple files per day).

---

## Configuration

On first run MPS writes `~/.mps_config.yaml`:

```yaml
mps_dir: ~/.mps
storage_dir: ~/.mps/mps
log_file: ~/.mps/mps.log
git_remote: origin
git_branch: master
default_command: open    # change to "list" to make bare `mps` list instead of open
aliases: {}              # e.g. {t: task, n: note, l: log, r: reminder}
```

---

## Architecture

MPS follows a layered pipeline: parser → typed elements → store → CLI. The parser is a single-pass stack machine; the store owns all filesystem work; the CLI is a thin Thor dispatcher. See [ARCHITECTURE.md](ARCHITECTURE.md) for the full design document.

---

## Requirements

- Ruby >= 3.1
- Vim (for `open`)
- Git (for `git` / `autogit`)

## Dependencies

- [`thor`](https://github.com/rails/thor) — CLI framework
- [`tty-editor`](https://github.com/piotrmurach/tty-editor) — editor integration
- [`chronic`](https://github.com/mojombo/chronic) — natural-language date parsing
- [`cli-ui`](https://github.com/Shopify/cli-ui) — terminal color and formatting

## See also

- [GETTING_STARTED.md](GETTING_STARTED.md) — full walkthrough with real examples
- [ARCHITECTURE.md](ARCHITECTURE.md) — design document for contributors

## Contributing

Bug reports and pull requests are welcome at https://github.com/mash-97/mps.

## License

MIT License.
