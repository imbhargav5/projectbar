# ProjectBar

Dont lose focus. Track agents you want to run per project per day.

<img width="1200" height="860" alt="d971875a-09ff-46e7-834d-2cce30533a38" src="https://github.com/user-attachments/assets/438356e3-8bf5-430a-b3fc-9128de5f87a6" />


ProjectBar is a native macOS menu bar app for keeping agent work moving across projects. Each project has a daily agent-run target, an evenly divided 10:00–20:00 local-time cadence, and a two-tap run workflow.

## How it works

- Add multiple selected project folders, import every child folder under a chosen parent, or create name-only projects.
- Open a card's **Project Settings…** menu to set its 1–200 daily target with the numeric slider.
- During work hours, cards turn red when their completed runs fall behind the evenly spaced cadence.
- Tap **Start agent**, then tap the morphed **Confirm complete** action when the run finishes.
- Project configuration, active runs, and completion history persist in `~/Library/Application Support/ProjectBar/state.json`.
- The local day resets at midnight. Before 10:00 nothing is due; after 20:00 the full daily target is due until midnight.

The status item shows the total completed/target count when on cadence, the number of overdue runs when behind, or the number of active runs.

## Build and run

ProjectBar requires macOS 14 or later and Swift 6.2.

```sh
make test
make run
```

`make app` creates an ad-hoc signed `ProjectBar.app` in the repository root.

## Cadence example

A target of 10 runs/day creates checkpoints at 10:30, 11:30, …, 19:30. A target of 100 creates one checkpoint every six minutes, centered at 10:03, 10:09, …, 19:57.
