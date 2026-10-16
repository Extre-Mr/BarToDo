# Bar To Do

A compact, native macOS task queue that lives in the menu bar.

Bar To Do keeps tasks in three FIFO columns—**To Do**, **Processing**, and **Done**—and advances the queue with a single action. Everything is stored locally on your Mac.

## Features

- Native SwiftUI interface presented from the macOS menu bar
- Current task and play action directly in the menu bar
- Drag and drop between columns and within a column
- Marquee multi-selection with grouped drag and drop
- FIFO queue automation
- Inline editing, context menus, and completed-task cleanup
- Local, atomic JSON persistence; no account, analytics, or network access
- Keyboard shortcut: `⌘↩` advances the queue while the panel is open
- Apple silicon and Intel Mac support

## Requirements

- macOS 14 Sonoma or newer
- Xcode 16 or newer to build from source

## Install a release

1. Download `Bar-To-Do-v1.0.0-macOS.zip` from the latest GitHub Release.
2. Unzip it and move **Bar To Do.app** to `/Applications`.
3. Because the community build is not notarized, Control-click the app and choose **Open** the first time.

### If macOS blocks the app

Bar To Do is open source, but macOS Gatekeeper checks Developer ID notarization rather than whether source code is public. If Control-click → **Open** is unavailable:

1. Open **System Settings → Privacy & Security**.
2. Find the message about Bar To Do and click **Open Anyway**.

If macOS still blocks the app, remove only its downloaded-file quarantine attribute and launch it again:

```bash
xattr -dr com.apple.quarantine "/Applications/Bar To Do.app"
open "/Applications/Bar To Do.app"
```

You can inspect all source code in this repository or build it yourself with Xcode. The release does not require Xcode to run.

## Build from source

```bash
git clone https://github.com/Extre-Mr/BarToDo.git
cd BarToDo
open CompactFlow.xcodeproj
```

Select the `CompactFlow` scheme and **My Mac**, then press `⌘R`.

Command-line build and tests:

```bash
xcodebuild build \
  -project CompactFlow.xcodeproj \
  -scheme CompactFlow \
  -configuration Debug \
  -destination 'platform=macOS'

xcodebuild test \
  -project CompactFlow.xcodeproj \
  -scheme CompactFlow \
  -configuration Debug \
  -destination 'platform=macOS'
```

## Local data

Tasks are stored at:

```text
~/Library/Application Support/CompactFlow/tasks.json
```

Deleting the application does not automatically delete this data file.

## Architecture

The project uses a small MVVM structure:

- `Models`: task and status types
- `ViewModels`: queue and ordering rules
- `Services`: atomic JSON persistence
- `Views` and `Components`: menu-bar popover UI and reusable controls

There are no third-party dependencies.

## License

[MIT](LICENSE)
