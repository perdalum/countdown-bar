# CountdownBar

A tiny native macOS menu bar app for tracking multiple countdowns. One countdown is shown directly in the menu bar; all countdowns are visible from the menu bar dropdown.

## Features

- Shows the selected countdown in the macOS menu bar.
- Lists all countdowns in the dropdown menu.
- Add, edit, delete, and copy countdowns.
- Choose which countdown appears in the menu bar.
- Per countdown, choose whether to include the exact time or count whole days only.
- Stores countdowns as JSON at:

  ```text
  ~/Library/Application Support/CountdownBar/countdowns.json
  ```

## Develop

Run directly from Swift Package Manager:

```bash
swift run CountdownBar
```

Build a `.app` bundle:

```bash
./scripts/build-app.sh
open .build/CountdownBar.app
```

## JSON format

```json
[
  {
    "id": "2B1F1C35-5C61-4D1E-BD5C-1D7961270B52",
    "title": "Launch day",
    "date": "2026-09-01T09:00:00Z",
    "showInMenuBar": true,
    "includeTime": true
  }
]
```

Exactly one countdown is kept selected for the menu bar. If none is selected, CountdownBar selects the first countdown automatically.

Set `includeTime` to `false` for date-only countdowns that show whole days (`today`, `1d`, `2 days ago`, etc.). Older config files without `includeTime` default to `true`.
