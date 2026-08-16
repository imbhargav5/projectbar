import AppKit
import ProjectBarCore
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let store: ProjectStore
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var timer: Timer?

    init(store: ProjectStore, statusBar: NSStatusBar = .system) {
        self.store = store
        self.statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        self.configureStatusItem()
        self.configurePopover()
        self.store.onDashboardChanged = { [weak self] in
            self?.updateStatusItem()
            self?.updatePopoverSize()
            self?.scheduleNextRefresh()
        }
        self.updateStatusItem()
        self.scheduleNextRefresh()
    }

    func stop() {
        self.timer?.invalidate()
        self.timer = nil
        self.store.onDashboardChanged = nil
        self.popover.close()
    }

    private func configureStatusItem() {
        self.statusItem.autosaveName = "projectbar-main"
        guard let button = self.statusItem.button else { return }
        let image = NSImage(
            systemSymbolName: "rectangle.3.group.fill",
            accessibilityDescription: "ProjectBar")
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        button.target = self
        button.action = #selector(self.togglePopover)
        button.sendAction(on: [.leftMouseUp])
        button.setAccessibilityIdentifier("ProjectBar.StatusItem")
        button.setAccessibilityTitle("ProjectBar")
    }

    private func configurePopover() {
        self.popover.behavior = .transient
        self.popover.animates = true
        self.popover.contentSize = self.desiredPopoverSize
        self.popover.contentViewController = NSHostingController(rootView: ProjectBoardView(
            store: self.store,
            onClose: { [weak self] in
                self?.popover.close()
            }))
    }

    @objc private func togglePopover() {
        if self.popover.isShown {
            self.popover.performClose(nil)
            return
        }
        guard let button = self.statusItem.button else { return }
        self.store.tick()
        self.popover.contentSize = self.desiredPopoverSize
        self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func handleTimer() {
        self.store.tick()
    }

    private func scheduleNextRefresh() {
        self.timer?.invalidate()

        let now = self.store.now
        let calendar = Calendar.autoupdatingCurrent
        let schedule = WorkdaySchedule()
        var candidates: [Date] = []

        if let minuteBoundary = calendar.nextDate(
            after: now,
            matching: DateComponents(second: 0),
            matchingPolicy: .nextTime)
        {
            candidates.append(minuteBoundary)
        }
        if let midnight = calendar.dateInterval(of: .day, for: now)?.end {
            candidates.append(midnight)
        }

        for project in self.store.projects {
            let expected = schedule.expectedRunCount(
                at: now,
                target: project.dailyRunTarget,
                calendar: calendar)
            guard expected < project.dailyRunTarget,
                  let checkpoint = schedule.scheduledDate(
                    forRunNumber: expected + 1,
                    target: project.dailyRunTarget,
                    on: now,
                    calendar: calendar),
                  checkpoint > now
            else { continue }
            candidates.append(checkpoint)
        }

        let nextRefresh = candidates.min() ?? now.addingTimeInterval(60)
        self.timer = Timer.scheduledTimer(
            timeInterval: max(0.2, nextRefresh.timeIntervalSinceNow),
            target: self,
            selector: #selector(self.handleTimer),
            userInfo: nil,
            repeats: false)
    }

    private func updateStatusItem() {
        guard let button = self.statusItem.button else { return }
        let imageName: String
        let title: String

        if self.store.projects.isEmpty {
            imageName = "rectangle.3.group.fill"
            title = ""
        } else if self.store.runsBehind > 0 {
            imageName = "exclamationmark.square.fill"
            title = " \(self.store.runsBehind) due"
        } else if self.store.activeRunCount > 0 {
            imageName = "bolt.horizontal.circle.fill"
            title = " \(self.store.activeRunCount) running"
        } else {
            imageName = "rectangle.3.group.fill"
            title = " \(self.store.completedToday)/\(self.store.totalDailyTarget)"
        }

        let image = NSImage(systemSymbolName: imageName, accessibilityDescription: "ProjectBar")
        image?.isTemplate = true
        button.image = image
        button.title = title
        button.setAccessibilityValue(title.trimmingCharacters(in: .whitespaces))
    }

    private func updatePopoverSize() {
        guard self.popover.isShown else { return }
        self.popover.contentSize = self.desiredPopoverSize
    }

    private var desiredPopoverSize: NSSize {
        NSSize(width: 812, height: self.store.projects.isEmpty ? 420 : 640)
    }
}
