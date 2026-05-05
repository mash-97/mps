# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MPS (MonoPsyches) is a Ruby gem — a plain-text personal productivity CLI. Users store tasks, notes, reminders, and logs in date-stamped `.mps` files (e.g. `20260226.1730000000.mps`) inside a configurable storage directory (`~/.mps/mps/` by default). Files are opened in Vim; git integration handles sync.

## Commands

```bash
# Install dependencies
bundle install

# Run all tests
bundle exec rake test:with_groups

# Run a single test file
bundle exec ruby -Itest -Ilib test/config_test.rb

# Run a single test by name
bundle exec ruby -Itest -Ilib test/config_test.rb -n test_name

# Build the gem
gem build mps.gemspec

# Run the CLI locally
bundle exec exe/mps
```

```bash
# List parsed elements from today's (or a given date's) file
bundle exec exe/mps list [DATESIGN] [--type task|note|log|reminder]

# Append a single element without opening Vim
bundle exec exe/mps append TYPE BODY [--tags work,release] [--at 3pm]

# Auto stage, commit, pull, and push inside storage_dir
bundle exec exe/mps autogit
```

## Architecture

### Entry point
`exe/mps` calls `MPS::CLI::MPS.start(ARGV)` — a Thor-based CLI defined in `lib/cli/mps.rb`. All commands (`open`, `git`, `autogit`, `list`, `append`, `cmd`, `version`) live there and delegate to the library layer.

### Load order (`lib/mps.rb`)
```
mps/version → mps/mps (MPS module methods) →
  mps/constants → mps/config → mps/interpolators → mps/elements → mps/engines →
  mps/ref_resolver → mps/query → mps/presenter → mps/store → cli/mps → mps/cli/commands
```

### Parsing pipeline (`lib/mps/engines/mps.rb`)
`Engines::Parser.parse_mps_file_to_elements_hash` reads an `.mps` file and uses a position-based stack parser with `Regexp#match(str, pos)`. It wraps the raw file contents in a synthetic `@mps[]{}` root element, then iterates using two regexes from `Constants`: `AT_REGEXP` (opening `@element[args]{`) and `END_CURLY_REGEXP` (closing `}`). A stack tracks nesting; each closed element is instantiated and stored in a flat hash keyed by a dotted ref path (e.g. `"1234567890.1.2"`). `Engines::MPS` is a backward-compat alias for `Engines::Parser`.

### Elements (`lib/mps/elements/`)
Each element type (Task, Note, Reminder, Log, MPS) is a class that `include`s the `MPS::Element` mixin. The mixin provides `initialize(args:, refs:, body_str:)`, `display_str`, and `attr_reader :body_str`. Each class must define `SIGNATURE_STAMP` (used when generating filenames/wrapping) and `SIGNATURE_REGEX` (matched against the parsed element sign to dispatch). The engine discovers all element classes dynamically via `MPS::Elements.constants`.

### Interpolators (`lib/mps/interpolators/`)
Interpolator classes (e.g. `Interpolators::Time`) are discovered the same way as elements — via `const_get` on the module's `constants`. Each defines `SIGNATURE_REGEX` and `get_str`. The parser applies them to body strings after the main parse loop via `_apply_interpolations`.

### Configuration (`lib/mps/config.rb` + `lib/mps/constants.rb`)
`Config.init(path)` writes a default YAML config. `Config.new(**hash)` holds `storage_dir`, `mps_dir`, `log_file`, and a `Logger`. Two additional optional YAML keys are supported: `git_remote` (default `"origin"`) and `git_branch` (default `"master"`); both are exposed as `attr_reader`s and used by `git` and `autogit` commands. The CLI re-reads the config on every invocation via `load_config`; it auto-creates missing directories and the log file.

## File format

```
@task[tag1, tag2]{
  Task body text
}

@note{
  Free-form note
}

@reminder[at: 3pm]{
  Meeting description
}

@log[start: 09:00, end: 12:30]{
  Time log entry
}

@mps{
  @task{ nested task }
}
```

File names follow `YYYYMMDD.<epoch>.mps`; the epoch disambiguates multiple files per day. The regexp for valid names is `Constants::MPS_FILE_NAME_REGEXP`.

## Testing

Tests use Minitest with `fakefs` for filesystem isolation. The test helper at `test/test_helper.rb` sets up the load path and does `include MPS`, so all constants and module methods are available directly in test classes.

`test/engine_test.rb` tests the parser directly: it uses a `parse_content(str)` helper that writes a fixture file under `FakeFS` at `/tmp/20260101.mps` and calls `Engines::Parser.parse_mps_file_to_elements_hash` on it. Covers empty files, single and multiple elements, unknown element fallback to `Struct`, nested `@mps{}`, `matched_element_class`, and `look_ahead_pos` edge cases.

`test/config_test.rb` covers `Config.init`, `Config.load_conf_hash` (including `git_remote`/`git_branch` defaults), logger formatting, and `LoadError` on missing keys.
