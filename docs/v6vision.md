Good. Now I have the full picture. Let me lay out the comprehensive plan.

---

## MPS v0.6.0 — General Notification System

### Current State

`ReminderData` today is just `{ tags, at: Option<String> }` — the `at` field is a raw string ("5pm") with no time parsing, no status, and no delivery mechanism. Zero infrastructure for notifying the user.

---

### Design Decisions (before we touch code)

**1. One-shot check, not a daemon.**
`mps check` runs once, checks due reminders, fires notifications. The OS scheduler (systemd timer, launchd, cron) calls it. No background process means: no PID files, no crash recovery, no "is the daemon running?" problem. Composable and testable.

**2. In-place file update for status.**
When the user acks a notification, we rewrite the args string of that element in its `.mps` file. The file stays the single source of truth — no separate state file to get out of sync. Implementation: read raw bytes, locate the element's args span via the ref-path, splice, write back.

**3. `NotificationSpec` struct, not a Rust trait.**
Since `Element` is an enum (not trait objects), the cleanest API is `element.notification_spec(date, ref_key) -> Option<NotificationSpec>`. Each variant can opt in. Future elements (tasks with `due: 5pm`) just add an arm.

**4. `notify-rust` crate for delivery.**
Cross-platform: dbus on Linux, NSUserNotification on macOS, WinRT on Windows. Graceful terminal fallback when no display server is present (CI, SSH sessions).

**5. Status is backward-compatible.**
Existing `@reminder[at: 5pm]{}` without `status` field defaults to `Open`. No migration needed.

---

### File Format (new fields)

```
@reminder[at: 5pm]{ Team standup }                          # existing, Open (default)
@reminder[at: 5pm, status: notified]{ Team standup }        # notification fired
@reminder[at: 5pm, status: snoozed, snooze: 5:30pm]{ ... } # snoozed until 5:30pm today
@reminder[at: 5pm, status: dismissed]{ Team standup }       # user dismissed
@reminder[at: 5pm, status: done]{ Team standup }            # user acted on it
```

---

### New Types

**`ReminderStatus` enum** (in `elements/reminder.rs`):
```
Open → Notified → Done
                → Snoozed (loops back to Open at snooze_until)
                → Dismissed
```

**`NotificationSpec` struct** (in `elements/mod.rs`):
```rust
pub struct NotificationSpec {
    pub ref_key:  String,
    pub title:    String,        // element type + first body line
    pub body:     String,        // remaining body or empty
    pub due_at:   NaiveDateTime, // today's date + parsed `at` time
    pub status:   NotificationStatus, // Open or Notified
}
```

**`Element::notification_spec(date, ref_key) -> Option<NotificationSpec>`** — `Reminder` with a parseable `at` and non-terminal status returns `Some`. Everything else returns `None`. Future: `Task { data: TaskData { due_at: Some(..), .. } }` can return `Some` too.

---

### New Module: `time_parse.rs`

Parses reminder `at` strings:

| Input      | Output |
| ---------- | ------ |
| `5pm`      | 17:00  |
| `5:30pm`   | 17:30  |
| `17:30`    | 17:30  |
| `9am`      | 09:00  |
| `noon`     | 12:00  |
| `midnight` | 00:00  |
| `3:00 PM`  | 15:00  |

No external crate — same approach as `date_parse.rs`.

---

### Store Layer Changes

Two new methods on `Store`:

```rust
// Locate which file contains ref_key, return file path + cloned element
fn find_element_by_ref(&self, ref_key: &str) -> Result<(PathBuf, Element), MpsError>

// Rewrite element's raw_args in the file, in-place
fn update_element_args(&self, path: &Path, ref_key: &str, new_args: &str) -> Result<(), MpsError>
```

The update strategy: parse the file to find the element's position, then do a targeted string replacement of the `[old_args]` span in the raw content. Since `raw_args` is preserved verbatim in every `Element` variant, we can search for the original args string.

---

### New Commands (v0.6.0)

**`mps check [--date DATE]`**
1. Load all elements for date (default: today)
2. Collect `notification_spec()` for every element
3. Filter: due (current time ≥ `due_at` and within a 5-minute window) and status is `Open`
4. Fire desktop notification via `notify-rust` for each
5. Update each notified element's status to `Notified` in-place
6. Print summary: "Sent N notification(s)"

The 5-minute look-ahead window means running `mps check` every minute from cron won't spam — `Notified` status gates re-firing.

**`mps ack <REF> [--snooze DURATION | --dismiss | --done]`**
- Default (no flag): `--done`
- `--snooze 15m` → compute `snooze_until = now + 15m`, set `status: snoozed, snooze: HH:MM`
- `--snooze 5:30pm` → set `status: snoozed, snooze: 5:30pm`
- `--dismiss` → set `status: dismissed`
- `--done` → set `status: done`
- Rewrites args in-place, prints confirmation

**`mps reminders [DATE]`**
- Lists all `@reminder` elements for date range
- `--status open|notified|snoozed|dismissed|done|all` (default: `open`)
- `--since DATE`
- Shows: `[reminder] (5pm) (open) Team standup [work]`

**`mps install-scheduler [--interval N]`**
- Linux: writes `~/.config/systemd/user/mps-check.{service,timer}`, runs `systemctl --user enable --now mps-check.timer`
- macOS: writes `~/Library/LaunchAgents/com.mps.check.plist`, runs `launchctl load`
- Fallback: prints the cron line to add manually
- `--interval N` minutes (default: 1)

---

### Cargo.toml Additions

```toml
notify-rust = { version = "4", features = ["async-std"] }
```

`notify-rust` v4 is the stable cross-platform choice. No async actually needed for our use case, but the feature flag keeps compile size down.

Actually: `notify-rust = "4"` (default features) is sufficient.

---

### Implementation Phases

| Phase | What                                                            | Files                                               |
| ----- | --------------------------------------------------------------- | --------------------------------------------------- |
| 1     | `time_parse.rs`, `ReminderStatus` enum, extended `ReminderData` | `time_parse.rs`, `elements/reminder.rs`             |
| 2     | `NotificationSpec`, `Element::notification_spec()`              | `elements/mod.rs`, `elements/reminder.rs`           |
| 3     | `Store::find_element_by_ref`, `Store::update_element_args`      | `store.rs`                                          |
| 4     | `commands/check.rs` + wire to `cli.rs` + `main.rs`              | `commands/check.rs`, `cli.rs`, `main.rs`            |
| 5     | `commands/ack.rs`                                               | `commands/ack.rs`, `cli.rs`, `main.rs`              |
| 6     | `commands/reminders.rs`                                         | `commands/reminders.rs`, `cli.rs`, `main.rs`        |
| 7     | `commands/scheduler.rs`                                         | `commands/scheduler.rs`, `cli.rs`, `main.rs`        |
| 8     | Tests for all new modules                                       | `time_parse.rs`, `store.rs`, `elements/reminder.rs` |
| 9     | Bump version → 0.2.0, update README                             | `Cargo.toml`, `README.md`                           |

Phases 1–3 are pure library (no I/O side effects), fully testable in isolation. Phases 4–7 are thin command wrappers over the library. Phase 8 can run in parallel once Phase 3 is done.

---

### Scope boundary for v0.6.0

**In:**
- Time parsing for `at` field
- `ReminderStatus` with Open/Notified/Snoozed/Dismissed/Done
- Desktop notification delivery (`mps check`)
- In-place status update (`mps ack`)
- Reminder list with status filter (`mps reminders`)
- Scheduler installation (`mps install-scheduler`)
- `NotificationSpec` general protocol for future element types

**Out (v0.7.0+):**
- Cross-day reminder carry-forward ("remind me tomorrow")
- Notification action buttons (requires more complex dbus/native API)
- Recurring reminders (`@reminder[at: 9am, repeat: daily]`)
- Task `due:` time notifications
- Email/Slack delivery channels

---

Ready to start Phase 1? I can begin immediately with `time_parse.rs` and the extended `ReminderData`, or if you want to adjust scope/decisions first, let's discuss those now.