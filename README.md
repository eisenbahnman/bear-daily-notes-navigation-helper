# Bear Daily Notes navigation helper

Navigate between daily notes in [Bear](https://bear.app) with a keyboard shortcut. Jump to the next or previous note titled with a date (`YYYY-MM-DD`).

## How it works

1. Reads the currently open note title from Bear's UI via the macOS Accessibility API
2. Queries Bear's local SQLite database (read-only) for the adjacent daily note by title.
3. Opens the target note in Bear via `bear://` URL scheme

**Notes:**
- Does not handle duplicates. If you have two notes with the exact same date in the title, and they happen to be adjacent to your current daily note, Bear will decide which one to open.
- Only matches `YYYY-MM-DD`. Will not match `YYYY-MM-DD <extra context>`.
- Also searches through Archived notes.

## Requirements

- macOS 13+
- Bear 2.x
- Swift 5.9+ (for building)
- Accessibility permissions for the calling app (Terminal, Alfred, etc.)

## Build

```
swiftc -O -o bear-nav bear-nav.swift -lsqlite3
```

Optionally move the binary somewhere on your PATH:

```
mv bear-nav ~/.local/bin/
```

## Usage

```
bear-nav next
bear-nav previous
```

If no argument is given, it defaults to `next`.

If there is no next or previous daily note, a macOS notification is shown.

## Accessibility permissions

The binary reads Bear's UI via the Accessibility API. The app that launches it (Terminal, Alfred, etc.) needs Accessibility access:

**System Settings → Privacy & Security → Accessibility**

If the title can't be read, the tool exits with an error message.

## Daily note format

The tool looks for notes whose titles match the pattern `YYYY-MM-DD` exactly. Notes with any other title format are ignored.

## What it doesn't do

- It doesn't modify Bear's database. The SQLite connection is opened read-only.
- It doesn't run in the background. It executes, navigates, and exits.


## License

MIT
