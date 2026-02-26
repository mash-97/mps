# MPS (MonoPsyches)

MPS (MonoPsyches) is a plain-text based personal productivity management system. It allows you to organize tasks, notes, reminders, and logs in simple text files organized by date, similar to org-mode or journaling systems.

## Features

- **Date-based organization**: Each day gets its own `.mps` file (e.g., `20260226.1730000000.mps`)
- **Structured elements**: Tasks, notes, reminders, logs, and nested MPS entries
- **Vim integration**: Opens files directly in Vim for quick editing
- **Git integration**: Auto-commit, push, and pull your data
- **CLI interface**: Simple commands to manage your MPS files
- **Plain text storage**: Your data is stored as plain text files

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mps'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install mps
```

## Usage

### Quick Start

After installation, simply run:

```bash
mps
```

This opens today's MPS file in Vim.

### Available Commands

#### Open an MPS file

```bash
mps open [date]
```

Opens the MPS file for the specified date. Examples:

```bash
mps open           # Opens today's file
mps open today     # Opens today's file
mps open yesterday # Opens yesterday's file
mps open 20260226  # Opens file for February 26, 2026
mps open "2 days ago"
mps open "last week"
```

#### Git Integration

```bash
mps git status           # Check git status in storage directory
mps git add .            # Stage all changes
mps git commit -m "msg"  # Commit changes
mps git auto             # Auto add, commit, pull, and push
mps git autocommit       # Auto add and commit only
```

#### Run Shell Commands

```bash
mps cmd ls -la    # List files in storage directory
mps cmd pwd       # Show current directory
```

#### Version

```bash
mps version       # Show MPS version
```

## File Format

MPS files use a simple syntax with elements defined in curly braces:

```
@task[tag1, tag2]{
  Complete project documentation
}

@note{
  Important note about the project
}

@reminder[at: 3pm]{
  Meeting with team
}

@log[start: 09:00, end: 12:30]{
  Working on feature implementation
}

@mps{
  @task{
    Nested task inside MPS
  }
}
```

### Element Types

| Element | Syntax | Description |
|---------|--------|-------------|
| Task | `@task[tags]{description}` | A to-do item |
| Note | `@note{content}` | A free-form note |
| Reminder | `@reminder[at: time]{description}` | Time-based reminder |
| Log | `@log[start: time, end: time]{description}` | Time logging |
| MPS | `@mps{...}` | Nested MPS block |

## Configuration

On first run, MPS creates configuration files in your home directory:

- `~/.mps_config.yaml` - Main configuration file
- `~/.mps/` - MPS data directory
- `~/.mps/mps/` - Storage directory for `.mps` files
- `~/.mps/mps.log` - Log file

Default storage location: `~/.mps/mps/`

## Requirements

- Ruby >= 2.3.0
- Vim (for editing)
- Git (for version control features)

## Dependencies

- `strscan` - String scanning
- `thor` - CLI framework
- `tty-editor` - Terminal editor integration
- `chronic` - Date/time parsing
- `cli-ui` - User interface

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mash-97/mps.

## License

The gem is available as open source under the terms of the MIT License.
