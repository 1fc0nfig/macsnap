# MacSnap Testing Strategy

This strategy validates MacSnap at three layers so we can catch regressions in logic, CLI behavior, and macOS app workflows.

## 1) Automated unit tests (Swift/XCTest)

Run with:

```bash
scripts/test-all.sh --unit
```

Scope:
- `AppConfig` model defaults, migration-safe decoding, and codable round-trips.
- `ConfigManager` key/value API, validation, notifications, directory checks, and persistence of all settings keys.
- `FilenameGenerator` template expansion, sanitization, and counter behavior.
- `FileWriter` output path building, format encoding, and file-size helpers.
- `HotkeyManager` shortcut formatting/validation.
- `Capture` type contracts and deterministic error paths (`invalidRect`, invalid index).

Key design choice:
- Tests run with isolated config state via `MACSNAP_CONFIG_DIR` so no developer/user config is mutated.

## 2) Automated CLI smoke tests

Run with:

```bash
scripts/test-all.sh --cli
```

Scope:
- `list-config --json` output shape.
- `config` get/set happy paths.
- Settings-change workflows for user preferences (including shortcut rebinding).
- `config` validation failures.
- `reset-config --force` behavior.
- Capture-mode validation failure (no screen permission dependency).

## 3) Manual system validation (release gate)

These checks cover features that depend on macOS permissions, UI interaction, and real display/window state.

### Permissions and onboarding
- First launch prompts for Screen Recording + Accessibility.
- App recovers correctly after permissions are granted and relaunched.

### Capture workflows
- Full screen capture from menu + global shortcut.
- Area selection: draw, move, resize, confirm, cancel.
- Window capture via picker.
- Custom region create/reuse/reset.
- Timed capture (3/5/10 sec) with overlay countdown.

### Output workflows
- Clipboard-only, file-only, and dual-output modes.
- Output formats: PNG/JPG/WebP (WebP fallback behavior).
- Organization modes: flat/by-date/by-app.
- Filename template variables render correctly.

### UX and app behavior
- Preview window actions (save/edit/delete).
- Preferences persist across relaunch.
- Dock/menu bar visibility combinations are respected.
- CLI and app coexist without config corruption.

## Recommended CI gate

Use `scripts/test-all.sh` as the default quality gate for pull requests:
- Required: unit + CLI smoke (`scripts/test-all.sh`).
- Optional nightly: manual checklist or scripted UI automation pass.
