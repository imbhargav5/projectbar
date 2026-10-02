# ProjectBar

Don't lose focus. Track the agents you want to run per project, per day or per week.

<img width="1200" height="860" alt="d971875a-09ff-46e7-834d-2cce30533a38" src="https://github.com/user-attachments/assets/438356e3-8bf5-430a-b3fc-9128de5f87a6" />


ProjectBar is a native macOS menu bar app for keeping agent work moving across projects. Each project has a daily or weekly agent-run target, an evenly divided 10:00–20:00 local-time cadence, and a two-tap run workflow.

## How it works

- Add multiple selected project folders, import every child folder under a chosen parent, or create name-only projects.
- Search project names and filter the card board by **All**, **Behind**, **Running**, or **Complete**. Click the behind/running summary counts to use those filters.
- **Compact** is the default density and fits nine complete cards at the normal 812 × 720 size. Choose **Card density → Comfortable** in the gear menu to show last/next timing; Compact keeps that detail in card help text and accessibility descriptions.
- Choose **Pin Project** in a card's menu to keep it at the top. Pinned and unpinned groups each preserve saved project order, including when runs start or complete. Density and pins are remembered across restarts.
- Daily and weekly progress have separate summaries. Both densities show completed/target counts and expected progress.
- Folder-backed cards have a **Reveal in Finder** button and a **Copy Folder Path** menu action. Unavailable folders report an error without changing the saved path.
- Open a card's **Project Settings…** menu to choose a Daily or Weekly cadence and set its 1–200 target using the number field, stepper, or slider.
- During work hours, an amber **behind pace** badge identifies projects whose completions fall below the evenly spaced cadence.
- Tap **Mark started** after starting an agent yourself, then **Mark complete** when it finishes. ProjectBar tracks runs manually; it does not launch agents. Completion feedback and **Undo** appear in the fixed footer without moving the grid.
- Project configuration, active runs, and completion history persist in `~/Library/Application Support/ProjectBar/state.json`.
- Daily projects reset at local midnight. Weekly projects reset with the local calendar week and spread checkpoints across all seven 10:00–20:00 work windows; cadence pauses overnight.

The status item shows behind-pace and running counts together. When neither applies, it shows completed/target counts labeled **today** and **this week** for the configured cadences. A run in progress still counts toward the completion deficit until you mark it complete.

The board keeps three columns at its normal width and adapts to smaller screens. Search and filters stay visible while cards scroll. Application settings, About, and Quit are in the gear menu.

### Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| ⌘F | Focus search |
| ⌘1–4 | Select All, Behind, Running, or Complete |
| Return in search | Focus the first matching card |
| Arrow keys on a card | Move through the grid and reveal the focused card |
| ⌘Return on a card | Mark started or mark complete; held-key repeats are ignored |
| Escape | Clear search first, otherwise close the board |

Text editing, Tab navigation, and cancellation in open menus and sheets retain their native behavior. Adding projects clears search and status filters and reveals the first new project.

## Build and run

ProjectBar requires macOS 14 or later and Swift 6.2.

```sh
make test
make run
```

`make app` creates an ad-hoc signed `ProjectBar.app` in the repository root.

To render native previews for both densities, light/dark appearances, 0/1/16/50 projects, narrow layouts, and feedback states without changing saved projects:

```sh
PROJECTBAR_PREVIEW_DIR=/tmp/projectbar-previews swift test --filter ProjectBoardRenderingTests
```

### Install a Mac build

```sh
make install
```

This creates a signed release build, installs it at `~/Applications/ProjectBar.app`, and launches it. Re-run the command after rebuilding to replace the installed copy at the same stable path.

To install in the system Applications folder instead, use `PROJECTBAR_INSTALL_DIR=/Applications make install`; macOS may request administrator permission.

### Launch at login

After installing the build, open ProjectBar from the menu bar, choose **Settings…** from the gear menu, and enable **Launch ProjectBar at login**. ProjectBar uses the native macOS Login Items service. If macOS requires approval, the settings panel links directly to the Login Items screen in System Settings.

To install the release build and request launch-at-login registration in one step, run:

```sh
make install-startup
```

## Cadence example

A daily target of 10 creates checkpoints at 10:30, 11:30, …, 19:30. A daily target of 100 creates one checkpoint every six minutes, centered at 10:03, 10:09, …, 19:57.

A weekly target is distributed across the local calendar week's seven daily work windows. For example, a weekly target of 7 creates one checkpoint at 15:00 each day.
