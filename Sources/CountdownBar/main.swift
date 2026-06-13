import AppKit
import Foundation

struct Countdown: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var date: Date
    var showInMenuBar: Bool
    var includeTime: Bool

    init(id: UUID = UUID(), title: String, date: Date, showInMenuBar: Bool = false, includeTime: Bool = true) {
        self.id = id
        self.title = title
        self.date = date
        self.showInMenuBar = showInMenuBar
        self.includeTime = includeTime
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case date
        case showInMenuBar
        case includeTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        showInMenuBar = try container.decode(Bool.self, forKey: .showInMenuBar)
        includeTime = try container.decodeIfPresent(Bool.self, forKey: .includeTime) ?? true
    }
}

final class CountdownStore {
    private(set) var countdowns: [Countdown] = []
    let fileURL: URL

    init() {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CountdownBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        fileURL = supportDirectory.appendingPathComponent("countdowns.json")
        load()
    }

    func load() {
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                countdowns = try decoder.decode([Countdown].self, from: data)
                ensureSingleMenuBarCountdown()
            } else {
                countdowns = [
                    Countdown(title: "New Year", date: CountdownStore.nextNewYear(), showInMenuBar: true)
                ]
                save()
            }
        } catch {
            countdowns = [Countdown(title: "New Countdown", date: Date().addingTimeInterval(24 * 60 * 60), showInMenuBar: true)]
            save()
            NSLog("CountdownBar: failed to load countdowns: \(error.localizedDescription)")
        }
    }

    func save() {
        do {
            ensureSingleMenuBarCountdown()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(countdowns)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("CountdownBar: failed to save countdowns: \(error.localizedDescription)")
        }
    }

    func sortedCountdowns() -> [Countdown] {
        countdowns.sorted { left, right in
            if left.date == right.date { return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending }
            return left.date < right.date
        }
    }

    func menuBarCountdown(now: Date = Date()) -> Countdown? {
        if let selected = countdowns.first(where: { $0.showInMenuBar }) {
            return selected
        }
        return sortedCountdowns().first(where: { $0.date >= now }) ?? sortedCountdowns().first
    }

    func upsert(_ countdown: Countdown) {
        if let index = countdowns.firstIndex(where: { $0.id == countdown.id }) {
            countdowns[index] = countdown
        } else {
            countdowns.append(countdown)
        }
        save()
    }

    func delete(id: UUID) {
        let deletedWasSelected = countdowns.first(where: { $0.id == id })?.showInMenuBar == true
        countdowns.removeAll { $0.id == id }
        if deletedWasSelected, !countdowns.isEmpty {
            countdowns[0].showInMenuBar = true
        }
        save()
    }

    func setMenuBarCountdown(id: UUID) {
        for index in countdowns.indices {
            countdowns[index].showInMenuBar = countdowns[index].id == id
        }
        save()
    }

    func countdown(id: UUID) -> Countdown? {
        countdowns.first { $0.id == id }
    }

    private func ensureSingleMenuBarCountdown() {
        var alreadySelected = false
        for index in countdowns.indices {
            if countdowns[index].showInMenuBar {
                if alreadySelected {
                    countdowns[index].showInMenuBar = false
                }
                alreadySelected = true
            }
        }
        if !alreadySelected, !countdowns.isEmpty {
            countdowns[0].showInMenuBar = true
        }
    }

    private static func nextNewYear() -> Date {
        var components = Calendar.current.dateComponents([.year], from: Date())
        components.year = (components.year ?? 2026) + 1
        components.month = 1
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components) ?? Date().addingTimeInterval(30 * 24 * 60 * 60)
    }
}

final class CountdownFormatter {
    static func menuBarTitle(for countdown: Countdown?, now: Date = Date()) -> String {
        guard let countdown else { return "No countdowns" }
        let remaining = countdown.includeTime
            ? compactRemaining(until: countdown.date, now: now)
            : compactDaysRemaining(until: countdown.date, now: now)
        return "\(countdown.title): \(remaining)"
    }

    static func menuLine(for countdown: Countdown, now: Date = Date()) -> String {
        let remaining = countdown.includeTime
            ? fullRemaining(until: countdown.date, now: now)
            : fullDaysRemaining(until: countdown.date, now: now)
        return "\(countdown.title): \(remaining)"
    }

    static func compactRemaining(until date: Date, now: Date = Date()) -> String {
        let past = date < now
        let interval = abs(Int(date.timeIntervalSince(now)))
        let days = interval / 86_400
        let hours = (interval % 86_400) / 3_600
        let minutes = (interval % 3_600) / 60
        let seconds = interval % 60

        let value: String
        if days >= 1 {
            value = hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
        } else if hours >= 1 {
            value = minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else if minutes >= 1 {
            value = "\(minutes)m"
        } else {
            value = "\(seconds)s"
        }
        return past ? "\(value) ago" : value
    }

    static func fullRemaining(until date: Date, now: Date = Date()) -> String {
        let past = date < now
        let interval = abs(Int(date.timeIntervalSince(now)))
        let days = interval / 86_400
        let hours = (interval % 86_400) / 3_600
        let minutes = (interval % 3_600) / 60
        let seconds = interval % 60

        var parts: [String] = []
        if days > 0 { parts.append("\(days) day" + (days == 1 ? "" : "s")) }
        if hours > 0 { parts.append("\(hours) hour" + (hours == 1 ? "" : "s")) }
        if minutes > 0 { parts.append("\(minutes) minute" + (minutes == 1 ? "" : "s")) }
        if days == 0, hours == 0, minutes == 0 { parts.append("\(seconds) second" + (seconds == 1 ? "" : "s")) }

        let text = parts.prefix(3).joined(separator: ", ")
        return past ? "\(text) ago" : text
    }

    static func compactDaysRemaining(until date: Date, now: Date = Date()) -> String {
        let days = dayDifference(until: date, now: now)
        if days == 0 { return "today" }
        let value = "\(abs(days))d"
        return days < 0 ? "\(value) ago" : value
    }

    static func fullDaysRemaining(until date: Date, now: Date = Date()) -> String {
        let days = dayDifference(until: date, now: now)
        if days == 0 { return "today" }
        let dayText = "\(abs(days)) day" + (abs(days) == 1 ? "" : "s")
        return days < 0 ? "\(dayText) ago" : dayText
    }

    private static func dayDifference(until date: Date, now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let targetDay = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: today, to: targetDay).day ?? 0
    }
}

@MainActor
final class ModalButtonHandler: NSObject {
    weak var datePicker: NSDatePicker?
    weak var includeTimeButton: NSButton?

    @objc func accept(_ sender: Any?) {
        NSApp.stopModal(withCode: .OK)
    }

    @objc func cancel(_ sender: Any?) {
        NSApp.stopModal(withCode: .cancel)
    }

    @objc func toggleIncludeTime(_ sender: NSButton) {
        updateDatePickerElements(includeTime: sender.state == .on)
    }

    func updateDatePickerElements(includeTime: Bool) {
        datePicker?.datePickerElements = includeTime ? [.yearMonthDay, .hourMinute] : [.yearMonthDay]
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = CountdownStore()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.toolTip = "CountdownBar"
        updateStatusTitle()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusTitle()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func updateStatusTitle() {
        statusItem.button?.title = CountdownFormatter.menuBarTitle(for: store.menuBarCountdown())
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let countdowns = store.sortedCountdowns()
        if countdowns.isEmpty {
            let empty = NSMenuItem(title: "No countdowns yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for countdown in countdowns {
                let item = NSMenuItem(title: CountdownFormatter.menuLine(for: countdown), action: nil, keyEquivalent: "")
                let submenu = NSMenu()

                let showItem = NSMenuItem(title: "Show in Menu Bar", action: #selector(showInMenuBar(_:)), keyEquivalent: "")
                showItem.target = self
                showItem.representedObject = countdown.id.uuidString
                showItem.state = countdown.showInMenuBar ? .on : .off
                submenu.addItem(showItem)

                let editItem = NSMenuItem(title: "Edit…", action: #selector(editCountdown(_:)), keyEquivalent: "")
                editItem.target = self
                editItem.representedObject = countdown.id.uuidString
                submenu.addItem(editItem)

                let copyItem = NSMenuItem(title: "Copy Countdown", action: #selector(copyCountdown(_:)), keyEquivalent: "")
                copyItem.target = self
                copyItem.representedObject = countdown.id.uuidString
                submenu.addItem(copyItem)

                submenu.addItem(.separator())

                let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteCountdown(_:)), keyEquivalent: "")
                deleteItem.target = self
                deleteItem.representedObject = countdown.id.uuidString
                submenu.addItem(deleteItem)

                item.submenu = submenu
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let addItem = NSMenuItem(title: "Add Countdown…", action: #selector(addCountdown), keyEquivalent: "n")
        addItem.target = self
        menu.addItem(addItem)

        let reloadItem = NSMenuItem(title: "Reload Countdowns", action: #selector(reloadCountdowns), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)

        let configItem = NSMenuItem(title: "Open JSON Config", action: #selector(openConfig), keyEquivalent: ",")
        configItem.target = self
        menu.addItem(configItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit CountdownBar", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func addCountdown() {
        presentCountdownDialog(existing: nil)
    }

    @objc private func editCountdown(_ sender: NSMenuItem) {
        guard let countdown = countdown(from: sender) else { return }
        presentCountdownDialog(existing: countdown)
    }

    @objc private func showInMenuBar(_ sender: NSMenuItem) {
        guard let countdown = countdown(from: sender) else { return }
        store.setMenuBarCountdown(id: countdown.id)
        updateStatusTitle()
    }

    @objc private func copyCountdown(_ sender: NSMenuItem) {
        guard let countdown = countdown(from: sender) else { return }
        let text = CountdownFormatter.menuLine(for: countdown)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func deleteCountdown(_ sender: NSMenuItem) {
        guard let countdown = countdown(from: sender) else { return }
        let alert = NSAlert()
        alert.messageText = "Delete \"\(countdown.title)\"?"
        alert.informativeText = "This cannot be undone."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            store.delete(id: countdown.id)
            updateStatusTitle()
        }
    }

    @objc private func reloadCountdowns() {
        store.load()
        updateStatusTitle()
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(store.fileURL)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func countdown(from sender: NSMenuItem) -> Countdown? {
        guard let string = sender.representedObject as? String, let id = UUID(uuidString: string) else { return nil }
        return store.countdown(id: id)
    }

    private func presentCountdownDialog(existing: Countdown?) {
        let handler = ModalButtonHandler()
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 470),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = existing == nil ? "Add Countdown" : "Edit Countdown"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.center()

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = contentView

        let headingLabel = NSTextField(labelWithString: existing == nil ? "Add Countdown" : "Edit Countdown")
        headingLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        headingLabel.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Title")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let titleField = NSTextField(string: existing?.title ?? "")
        titleField.placeholderString = "Vacation, Launch day, Birthday…"
        titleField.translatesAutoresizingMaskIntoConstraints = false

        let dateLabel = NSTextField(labelWithString: "Target date")
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        let includeTimeButton = NSButton(checkboxWithTitle: "Include time", target: handler, action: #selector(ModalButtonHandler.toggleIncludeTime(_:)))
        includeTimeButton.state = (existing?.includeTime ?? true) ? .on : .off
        includeTimeButton.translatesAutoresizingMaskIntoConstraints = false

        let datePicker = NSDatePicker()
        datePicker.datePickerStyle = .clockAndCalendar
        datePicker.dateValue = existing?.date ?? Date().addingTimeInterval(24 * 60 * 60)
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        handler.datePicker = datePicker
        handler.includeTimeButton = includeTimeButton
        handler.updateDatePickerElements(includeTime: includeTimeButton.state == .on)

        let cancelButton = NSButton(title: "Cancel", target: handler, action: #selector(ModalButtonHandler.cancel(_:)))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        let saveButton = NSButton(title: existing == nil ? "Add" : "Save", target: handler, action: #selector(ModalButtonHandler.accept(_:)))
        saveButton.keyEquivalent = "\r"
        saveButton.bezelStyle = .rounded
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(headingLabel)
        contentView.addSubview(titleLabel)
        contentView.addSubview(titleField)
        contentView.addSubview(dateLabel)
        contentView.addSubview(includeTimeButton)
        contentView.addSubview(datePicker)
        contentView.addSubview(cancelButton)
        contentView.addSubview(saveButton)

        NSLayoutConstraint.activate([
            headingLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headingLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            headingLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            titleLabel.topAnchor.constraint(equalTo: headingLabel.bottomAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            titleField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            titleField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            dateLabel.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 18),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            includeTimeButton.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 8),
            includeTimeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            includeTimeButton.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),

            datePicker.topAnchor.constraint(equalTo: includeTimeButton.bottomAnchor, constant: 8),
            datePicker.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            datePicker.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),
            datePicker.heightAnchor.constraint(greaterThanOrEqualToConstant: 230),

            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -8),
            cancelButton.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor)
        ])

        panel.initialFirstResponder = titleField
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        let response = NSApp.runModal(for: panel)
        panel.close()

        guard response == .OK else { return }

        let title = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let includeTime = includeTimeButton.state == .on
        let selectedDate = includeTime ? datePicker.dateValue : Calendar.current.startOfDay(for: datePicker.dateValue)
        var countdown = existing ?? Countdown(title: title, date: selectedDate, showInMenuBar: store.countdowns.isEmpty, includeTime: includeTime)
        countdown.title = title
        countdown.date = selectedDate
        countdown.includeTime = includeTime
        store.upsert(countdown)
        updateStatusTitle()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
