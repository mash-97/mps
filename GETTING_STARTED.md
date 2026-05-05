# Getting Started with MPS

MPS is a plain-text productivity system that lives entirely in your terminal. Your tasks, notes, reminders, and logs are just `.mps` files in a folder — readable by any editor, portable, and git-backed. No app to install beyond the gem, no account to create, no sync service to trust.

---

## Install

```bash
gem install mps
```

First run creates everything automatically:

```
~/.mps_config.yaml   ← your config
~/.mps/mps/          ← where your files live
~/.mps/mps.log       ← activity log
```

---

## The file format

Before anything else, it helps to know what you're working with. Each `.mps` file is plain text. Every entry is an **element** — a type, optional arguments in `[]`, and a body in `{}`:

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

@mps[sprint]{
  @task[backend]{
    Nested task inside a sprint block
  }
}
```

The brackets are optional — `@task{ body }` is perfectly valid. Elements nest freely inside `@mps{}` blocks. Files are named `YYYYMMDD.<epoch>.mps` — the epoch allows multiple files per day without collision.

---

## A day in the life

It's Monday morning. You open your terminal:

```bash
mps
```

Vim opens with today's file. You write your sprint plan — a few `@task` entries, a `@note` about something to watch out for — save, and quit. Day started.

If you want a specific date instead:

```bash
mps open yesterday
mps open "last monday"
mps open 20260421
mps open "2 days ago"
```

Natural language dates work everywhere in MPS, powered by [Chronic](https://github.com/mojombo/chronic). Anything Chronic understands, MPS understands.

---

## Reading what you wrote

You're two hours into the day and forget whether you wrote down that reminder. Don't open Vim — just ask:

```bash
mps list
```

```
  [task] (open) Review the API pull request [work]
  [reminder] (10am) Team standup
  [note] The auth token expiry edge case needs a second look
  [@mps] sprint
    [task] (open) Nested backend task [backend]
```

The nested tree is preserved — child elements appear indented under their `[@mps]` group. Each type gets its own color in the terminal.

### Show human-readable refs

Pass `--refs` (or `-r`) to see addressable references alongside each element:

```bash
mps list --refs
```

```
  task-1        [task] (open) Review the API pull request [work]
  reminder-1    [reminder] (10am) Team standup
  note-1        [note] The auth token expiry edge case
  mps-1         [@mps] sprint
    mps-1.1       [task] (open) Nested backend task [backend]
```

These refs (`task-1`, `note-1`, `mps-1.1`, …) can be passed directly to `update` and `done`.

### Filter by type

Only want tasks?

```bash
mps list --type task
mps list -t task
```

### Filter by tag

Everything tagged `work`:

```bash
mps list --tag work
mps list -g work
```

### Filter by status (tasks only)

See only what's still open:

```bash
mps list --status open
mps list -s done
```

### Look at a different day

```bash
mps list yesterday
mps list "last friday"
mps list 20260421
```

### Date ranges with `--since`

Everything from last Monday to today:

```bash
mps list --since "last monday"
```

```
── 2026-04-22 ─────────────
  [task] (done) Set up CI pipeline [devops]
── 2026-04-28 ─────────────
  [task] (open) Review the API pull request [work]
  [note] Token expiry edge case
```

Date headers only appear for days that have entries. Combine filters freely:

```bash
mps list --since yesterday --type task --status open
```

### Across your entire archive with `--all`

See every element you've ever written:

```bash
mps list --all
mps list --all --type task --status open    # all open tasks, ever
mps list --all --since "2026-01-01"         # all of this year
```

---

## Quick-capture without opening Vim

You're deep in a debugging session. A thought hits you. You don't want to break your flow:

```bash
mps append note "Check if the race condition only happens under load"
```

```
  appended  [note] Check if the race condition only happens under load
```

The note lands at the bottom of today's file instantly.

### Append with tags

```bash
mps append task "Fix the token expiry bug" --tags work,backend
```

### Append a task that's already done

```bash
mps append task "Reviewed the PR" --tags work --status done
```

### Log your time

```bash
mps append log "Deep work on auth refactor" --tags work --start-time 09:00 --end-time 12:30
```

The 3h30m duration is computed automatically and shown in `list`, `stats`, and `export`.

### Set a timed reminder

```bash
mps append reminder "Push the hotfix before EOD" --at "5pm"
```

### Type aliases

You can define short names in `~/.mps_config.yaml`:

```yaml
aliases:
  t: task
  n: note
  r: reminder
  l: log
```

Then use the short form:

```bash
mps append t "Quick capture"    # same as: mps append task
mps append n "Remember this"    # same as: mps append note
```

All types supported by `append`: `task`, `note`, `log`, `reminder`.

---

## Updating elements in-place

Found a task you finished? Mark it done without opening Vim:

```bash
mps done task-1
```

Need to change an arbitrary attribute?

```bash
mps update task-1 --status done
mps update reminder-1 --at "6pm"
mps update log-1 --end-time 13:00
```

Refs can be the human-readable form (`task-1`, `note-2`, `mps-1.1`) shown by `mps list --refs`, or the epoch-based form (`20260428.1`) which encodes the date and position.

```bash
# Epoch ref — works for any date, no --date needed
mps done 20260421.2

# Human ref — defaults to today
mps done task-1

# Human ref for a different day
mps done task-1 --date yesterday
```

---

## Search across all your files

End of quarter. You vaguely remember logging something about "auth" in March. You don't know which file.

```bash
mps search "auth"
```

```
20260428 [log] (3h30m) Debugging the auth flow [work, backend]
20260421 [task] (done) Fix auth token expiry [backend]
(2 results)
```

Every `.mps` file in your storage directory is searched. Results show the date, type badge, and first line of the body.

### Narrow the search

Filter to a specific type:

```bash
mps search "auth" --type log
mps search "auth" -t task
```

Filter to a tag:

```bash
mps search "auth" --tag backend
mps search "auth" -g work
```

Limit to recent files:

```bash
mps search "auth" --since "last month"
mps search "auth" -S "2026-04-01"
```

All filters compose: `mps search "auth" --type task --tag backend --since "last week"`.

---

## Tag usage summary

See which tags you're using most:

```bash
mps tags
```

```
  Tag          Count  Frequency
  -----------  -----  ------------------------
  work             7  ████████████████████████
  backend          4  ██████████████
  personal         2  ███████
```

Across your entire archive:

```bash
mps tags --all
```

Filter by type or date range:

```bash
mps tags --type task --since monday
mps tags --all --since "2026-01-01"
```

---

## Your productivity at a glance

Friday afternoon. How did the week go?

```bash
mps stats --since monday
```

```
2026-04-22 — 2 tasks (1 open, 1 done), 1 note, 1 log (2h)
2026-04-23 — 1 task (0 open, 1 done), 2 logs (5h30m)
2026-04-28 — 3 tasks (2 open, 1 done), 1 note, 1 reminder, 1 log (3h30m)
────────────────────────────────────────────
Total: 6 tasks, 3 notes, 1 reminder, 3 logs (11h total)
```

For a single day:

```bash
mps stats
mps stats yesterday
mps stats 20260421
```

For everything, ever:

```bash
mps stats --all
mps stats --all --since "2026-01-01"
```

---

## Export your data

Need to feed your data into a spreadsheet, script, or another tool?

```bash
mps export --format json
```

```json
[
  {
    "date": "2026-04-28",
    "ref": "20260428.1",
    "type": "task",
    "tags": "work",
    "body": "Review the API pull request",
    "status": "open"
  }
]
```

CSV format:

```bash
mps export --format csv
```

All the same filters apply:

```bash
# Export all tasks this week
mps export --since monday --type task --format csv > this_week_tasks.csv

# Export a specific day as JSON
mps export 20260421 --format json > april21.json

# Pipe into jq
mps export --since "last month" --format json | jq '[.[] | select(.status == "done")]'
```

---

## Git backup — one command

Your files live in `~/.mps/mps/`. Initialize that directory as a git repo once, then let MPS handle sync:

```bash
mps autogit
```

This does: `git add .` → `git commit -m "$(date)"` → `git pull` → `git push`. Run it at the end of each day.

For manual control:

```bash
mps git status
mps git log --oneline -5
mps git commit -m "end of sprint retrospective"
mps git auto         # same as autogit
mps git autocommit   # stage and commit only, no push
```

Every `mps git` command runs inside your storage directory — no `cd` needed.

### Configure your remote and branch

Edit `~/.mps_config.yaml`:

```yaml
git_remote: origin
git_branch: main
```

---

## Configuration management

View your current configuration:

```bash
mps config show
```

```
MPS configuration
  config file : /home/you/.mps_config.yaml
  mps_dir     : /home/you/.mps
  storage_dir : /home/you/.mps/mps
  log_file    : /home/you/.mps/mps.log
  git_remote  : origin
  git_branch  : master
  default_cmd : open
```

Open your config file in `$EDITOR`:

```bash
mps config edit
```

### Configuring the default command

By default, bare `mps` opens today's file in Vim. To make `mps` show today's list instead:

```yaml
default_command: list
```

---

## Run any shell command in your storage directory

Need to see what files exist, or grep across everything raw?

```bash
mps cmd ls -la
mps cmd grep -r "token expiry" .
mps cmd wc -l *.mps
```

Everything runs inside `~/.mps/mps/`.

---

## Version

```bash
mps version
```

---

## Full reference

### Commands

| Command | What it does |
|---------|-------------|
| `mps` / `mps open [DATE]` | Open a date's file in Vim (default: today) |
| `mps list [DATE]` | Print elements in tree order (default: today) |
| `mps append TYPE BODY` | Add one element to today's file without Vim |
| `mps update REFPATH [--attr val]` | Update an element's attributes in-place |
| `mps done REFPATH` | Mark a task as done (shorthand for `update --status done`) |
| `mps search QUERY` | Full-text search across all files |
| `mps tags [DATE]` | Tag frequency bar chart |
| `mps stats [DATE]` | Element counts and log durations |
| `mps export [DATE]` | Export elements as JSON or CSV to stdout |
| `mps config [show\|edit]` | View or edit configuration |
| `mps autogit` | Stage, commit, pull, push in one shot |
| `mps git ARGS` | Run any git command inside storage dir |
| `mps cmd ARGS` | Run any shell command inside storage dir |
| `mps version` | Print current version |

### list options

| Option | Short | Description |
|--------|-------|-------------|
| `--type TYPE` | `-t` | Filter by: `task`, `note`, `log`, `reminder` |
| `--tag TAG` | `-g` | Filter by tag name |
| `--status STATUS` | `-s` | Filter tasks by: `open`, `done` |
| `--since DATESIGN` | `-S` | Show elements from SINCE up to DATESIGN |
| `--all` | `-a` | List elements across all dates |
| `--refs` | `-r` | Show human-readable ref column |

### append options

| Option | Description |
|--------|-------------|
| `--tags t1,t2` | Comma-separated tags |
| `--status open\|done` | Task status (default: open) |
| `--at TIME` | Time for reminders (e.g. `5pm`) |
| `--start-time HH:MM` | Start time for logs |
| `--end-time HH:MM` | End time for logs |

### update options

| Option | Description |
|--------|-------------|
| `--status STATUS` | New status value |
| `--at TIME` | New time for reminders |
| `--start-time HH:MM` | New start time for logs |
| `--end-time HH:MM` | New end time for logs |
| `--date DATESIGN` | Date context for human refs (default: today) |

### search options

| Option | Short | Description |
|--------|-------|-------------|
| `--type TYPE` | `-t` | Filter by element type |
| `--tag TAG` | `-g` | Filter by tag |
| `--since DATESIGN` | `-S` | Search from this date onward |

### stats options

| Option | Short | Description |
|--------|-------|-------------|
| `--since DATESIGN` | `-S` | Stats from SINCE up to DATESIGN |
| `--all` | `-a` | Stats across all dates |

### tags options

| Option | Short | Description |
|--------|-------|-------------|
| `--type TYPE` | `-t` | Filter by element type |
| `--since DATESIGN` | `-S` | Tags from SINCE up to DATESIGN |
| `--all` | `-a` | Count tags across all dates |
| `--status STATUS` | `-s` | Filter tasks by status before counting |

### export options

| Option | Short | Description |
|--------|-------|-------------|
| `--format FORMAT` | `-f` | Output format: `json` (default), `csv` |
| `--type TYPE` | `-t` | Filter by element type |
| `--since DATESIGN` | `-S` | Export from SINCE up to DATESIGN |

### Date formats accepted everywhere

| Input | Meaning |
|-------|---------|
| `today`, `yesterday` | Relative day |
| `monday`, `last friday` | Day of week |
| `2 days ago`, `last week` | Natural language |
| `20260421` | Explicit YYYYMMDD |

### Ref formats accepted by `update` and `done`

| Format | Example | Scope |
|--------|---------|-------|
| Human top-level | `task-1` | Today's file (or `--date`) |
| Human nested | `mps-1.1` | Today's file (or `--date`) |
| Epoch-based | `20260428.2` | Any date (date encoded in prefix) |
