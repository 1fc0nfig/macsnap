<p align="center">
  <img src="Sources/MacSnap/Resources/AppIcon.png" alt="MacSnap" width="128" height="128">
</p>

<h1 align="center">MacSnap</h1>

<p align="center">
  A lightweight, native macOS screenshot utility that saves to both clipboard and filesystem simultaneously.
</p>

## Features

- **Dual Output**: Every capture goes to both clipboard (for instant pasting) and filesystem (for organization)
- **Multiple Capture Modes**: Full screen, selected area, window capture, custom region, and timed capture
- **Hover State Preservation**: Captures UI hover effects by freezing screen state when hotkey is pressed
- **Configurable Hotkeys**: Default shortcuts (Cmd+Shift+1-4) can be customized
- **Smart Organization**: Auto-organize screenshots by date or application
- **Flexible Formats**: PNG, JPG (with quality control), or WebP
- **Preview Window**: Optional floating preview with quick actions and drag-and-drop to other apps
- **Menu Bar App**: Lightweight, always accessible from the menu bar
- **CLI Tool**: Full command-line interface for automation and scripting
- **Flexible Visibility**: Show in menu bar, dock, or both

## Requirements

- macOS 12.0 (Monterey) or later
- Screen Recording permission (required for screenshots)
- Accessibility permission (required for global hotkeys)

## Installation

### Homebrew

```bash
# Add the tap
brew tap 1fc0nfig/macsnap

# Install the menu bar app + macsnap-cli
brew install --cask macsnap

# Or install CLI only
brew install macsnap-cli
```

### Manual App Install (DMG)

If you install by dragging `MacSnap.app` into `/Applications`, link the bundled CLI manually:

```bash
ln -sf /Applications/MacSnap.app/Contents/MacOS/macsnap-cli /usr/local/bin/macsnap-cli
```

### Building from Source

```bash
# Clone the repository
git clone https://github.com/1fc0nfig/macsnap.git
cd macsnap

# Build release version
swift build -c release

# The binaries will be in .build/release/
# - MacSnap (menu bar app)
# - macsnap-cli (CLI tool)
```

### Running the App

```bash
# Run the menu bar app
.build/release/MacSnap

# Or use the CLI
.build/release/macsnap-cli capture full
```

## Usage

### Menu Bar App

Click the MacSnap icon in your menu bar to:
- Capture full screen
- Select area to capture (remembers last selection)
- Capture a specific window
- Capture custom region (one-time selection)
- Set a timed capture (3, 5, or 10 seconds)
- View recent captures
- Open output folder
- Access preferences

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+Shift+1 | Capture full screen |
| Cmd+Shift+2 | Select area to capture |
| Cmd+Shift+3 | Capture window |
| Cmd+Shift+4 | Capture custom region |

**During Area Selection:**
- Press **Enter** or **Cmd+Shift+2** to capture
- Press **Escape** to cancel
- Drag corners to resize selection
- Drag inside selection to move it

All shortcuts can be customized in Preferences.

### Preview Thumbnail

After each capture (when preview is enabled), the floating thumbnail supports:

- **Click**: Open in Preview for editing
- **Drag & Drop**: Drag the thumbnail into another app (Messages, Notes, Slack, etc.)
- **Two-finger Swipe**: Dismiss the thumbnail
- **Auto-save Timeout**: If untouched, it closes after the configured preview duration

### CLI

```bash
# Basic captures
macsnap-cli capture full          # Full screen
macsnap-cli capture area          # Area selection
macsnap-cli capture window        # Window capture
macsnap-cli capture full --delay 5  # Delayed capture

# With options
macsnap-cli capture full --format jpg --quality 80
macsnap-cli capture full --no-clipboard --output ./screenshot.png
macsnap-cli capture full --verbose

# Configuration
macsnap-cli config output.directory ~/Desktop/shots
macsnap-cli config output.format jpg
macsnap-cli config capture.includeCursor true

# View all settings
macsnap-cli list-config
macsnap-cli list-config --json

# Reset to defaults
macsnap-cli reset-config
```

## Configuration

Configuration is stored at `~/.config/macsnap/config.json`.

### Filename Templates

Use these variables in your filename template:

| Variable | Example |
|----------|---------|
| `{datetime}` | 2025-01-28_143052 |
| `{date}` | 2025-01-28 |
| `{time}` | 143052 |
| `{timestamp}` | 1706280652 |
| `{mode}` | area, full, window |
| `{app}` | Safari, Finder |
| `{counter}` | 001, 002 (daily reset) |

Default template: `macsnap_{datetime}_{mode}`

### Organization Modes

- **flat**: All screenshots in one folder
- **by-date**: Organized into YYYY-MM-DD subfolders
- **by-app**: Organized by source application name

### Preferences

Access preferences from the menu bar or by re-launching the app:

- **General**: Capture options, preview settings, retina scale
- **Shortcuts**: Customize keyboard shortcuts
- **Output**: Directory, format, filename template
- **Permissions**: Check and grant required permissions
- **About**: App information

**Visibility Options:**
- Show in Dock
- Show in Menu Bar

Note: The app must be visible in at least one location.

## Permissions

MacSnap requires the following permissions:

1. **Screen Recording**: System Settings > Privacy & Security > Screen Recording
2. **Accessibility** (for global hotkeys): System Settings > Privacy & Security > Accessibility

The app will prompt for these permissions on first launch. After granting permissions, you may need to restart MacSnap.

## Project Structure

```
macsnap/
├── Sources/
│   ├── MacSnapCore/          # Shared library
│   │   ├── Config/           # Configuration management
│   │   ├── Capture/          # Screenshot engine
│   │   ├── Output/           # Clipboard and file handling
│   │   └── Hotkeys/          # Global hotkey management
│   ├── MacSnap/              # Menu bar application
│   │   ├── App/              # App delegate and entry point
│   │   └── UI/               # SwiftUI views
│   └── macsnap-cli/          # Command-line interface
│       └── Commands/         # CLI commands
├── Tests/                    # Unit tests
└── Resources/                # Info.plist, entitlements
```

## Development

```bash
# Build debug version
swift build

# Build release version
swift build -c release

# Run the full automated test strategy (unit + CLI smoke)
scripts/test-all.sh

# Or run just unit tests
scripts/test-all.sh --unit

# Run the app
swift run MacSnap

# Run the CLI
swift run macsnap-cli capture full
```

See `TESTING.md` for the full testing strategy and manual release checklist.

## Troubleshooting

### Hotkeys not working
1. Check Accessibility permission is granted
2. Restart MacSnap after granting permissions
3. Verify shortcuts aren't conflicting with other apps

### Screenshots are blank or show wallpaper only
1. Check Screen Recording permission is granted
2. Restart MacSnap after granting permissions

### Can't access the app
If you hid the app from both menu bar and dock, launch it again from Finder or Spotlight - it will open the preferences window.

## License

MIT License
