# Getting Started with MPS

MPS is a plain-text productivity system that lives in your terminal. Your notes, tasks, logs, and reminders are just `.mps` files in a folder — readable, portable, and git-backed.

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

## A day in the life

It's Monday morning. You open your terminal and type:

```bash
mps
```

Vim opens. Today's file is blank — `20260428.1745000000.mps`. You write:

```
@task[work]{
  Review the API pull request
}

@reminder[at: 10am]{
  Team standup
}

@note{
  The new auth flow needs a second look — token expiry edge case
}
```

Save and quit. That's your morning captured.

---

## Check what you wrote — without opening Vim

Later you forget what you logged. Instead of opening the file:

```bash
mps list
```

```
[task] Review the API pull request
[reminder] Team standup
[note] The new auth flow needs a second look — token expiry edge case
```

Only want your tasks?

```bash
mps list --type task
```

```
[task] Review the API pull request
```

---

## Quick-capture mid-flow

You're deep in a debugging session. A thought hits you. You don't want to break focus and open Vim:

```bash
mps append note "Check if the race condition only happens under load"
```

```
  appended  [note] Check if the race condition only happens under load
```

Done. Back to debugging. The note is at the bottom of today's file.

Need to log time on a task? Same idea:

```bash
mps append log "Debugging auth token expiry" --tags work,backend
```

Setting a reminder for yourself:

```bash
mps append reminder "Push the hotfix before 5pm" --at "5pm"
```

---

## Jump to any day

End of week. You want to review what you did on Wednesday:

```bash
mps list wednesday
```

Or dig into last Monday's full file in Vim:

```bash
mps open "last monday"
```

Natural language dates work: `yesterday`, `2 days ago`, `last week`, `20260421`.

---

## Git backup — one command

Your files live in `~/.mps/mps/`. If you've initialised that folder as a git repo, MPS can sync it for you:

```bash
mps autogit
```

This stages everything, commits with the current timestamp, pulls, and pushes — in one shot. Run it at the end of each day.

For more control:

```bash
mps git status
mps git log --oneline -5
mps git commit -m "end of sprint notes"
```

---

## Configure your remote and branch

By default MPS pushes to `origin` on `master`. Change that in `~/.mps_config.yaml`:

```yaml
mps_dir: /home/you/.mps
storage_dir: /home/you/.mps/mps
log_file: /home/you/.mps/mps.log
git_remote: origin
git_branch: main
```

---

## Run any shell command in your storage directory

Need to see how many files you have?

```bash
mps cmd ls -la
mps cmd grep -r "token expiry" .
```

Everything runs inside `~/.mps/mps/` — no `cd` needed.

---

## The file format

MPS files are plain text. Every entry is an element: a type, optional args in `[]`, and a body in `{}`.

```
@task[tag1, tag2]{
  What needs doing
}

@note{
  Anything you want to remember
}

@reminder[at: 3pm]{
  What to be reminded of
}

@log[start: 09:00, end: 12:30]{
  What you worked on
}

@mps{
  @task{
    Nested task inside a sub-block
  }
}
```

Elements nest freely. The file is just text — open it in any editor, grep it, pipe it.

---

## Reference

| Command | What it does |
|---------|-------------|
| `mps` | Open today's file in Vim |
| `mps open [date]` | Open a specific date's file in Vim |
| `mps list [date]` | Print all elements from a file |
| `mps list [date] --type task` | Print only tasks |
| `mps append TYPE BODY` | Add one element to today's file without Vim |
| `mps append reminder BODY --at TIME` | Add a reminder with a time |
| `mps append task BODY --tags t1,t2` | Add a tagged task |
| `mps autogit` | Stage, commit, pull, push in one command |
| `mps git ARGS` | Run any git command inside storage dir |
| `mps git auto` | Same as autogit |
| `mps cmd ARGS` | Run any shell command inside storage dir |
| `mps version` | Print current version |
