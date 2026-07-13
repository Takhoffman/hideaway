import AppKit
import Sparkle
import SwiftUI

private enum Protection: String, CaseIterable, Identifiable {
    case desktop
    case widgets
    case dock
    case menuBar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .desktop: "Desktop files"
        case .widgets: "Desktop widgets"
        case .dock: "Dock"
        case .menuBar: "Menu bar"
        }
    }

    var detail: String {
        switch self {
        case .desktop: "Hide files without moving them"
        case .widgets: "Hide photos, weather, and calendar"
        case .dock: "Keep apps and badges off screen"
        case .menuBar: "Reveal it by moving the pointer up"
        }
    }

    var symbol: String {
        switch self {
        case .desktop: "doc.on.doc"
        case .widgets: "rectangle.3.group"
        case .dock: "dock.rectangle"
        case .menuBar: "menubar.rectangle"
        }
    }
}

@MainActor
final class HideawayController: ObservableObject {
    @Published private(set) var isActive: Bool
    @Published var lastError: String?

    @Published var protectDesktop: Bool {
        didSet { preferences.set(protectDesktop, forKey: Key.protectDesktop) }
    }
    @Published var protectWidgets: Bool {
        didSet { preferences.set(protectWidgets, forKey: Key.protectWidgets) }
    }
    @Published var protectDock: Bool {
        didSet { preferences.set(protectDock, forKey: Key.protectDock) }
    }
    @Published var protectMenuBar: Bool {
        didSet { preferences.set(protectMenuBar, forKey: Key.protectMenuBar) }
    }

    private enum Key {
        static let active = "hideaway.active"
        static let protectDesktop = "hideaway.protect.desktop"
        static let protectWidgets = "hideaway.protect.widgets"
        static let protectDock = "hideaway.protect.dock"
        static let protectMenuBar = "hideaway.protect.menuBar"
        static let changedPrefix = "hideaway.session.changed."
        static let existedPrefix = "hideaway.session.existed."
        static let valuePrefix = "hideaway.session.value."
    }

    private struct PreferenceLocation {
        let id: String
        let domain: String
        let key: String
    }

    private static let desktop = PreferenceLocation(
        id: "desktop",
        domain: "com.apple.finder",
        key: "CreateDesktop"
    )
    private static let standardWidgets = PreferenceLocation(
        id: "widgets.standard",
        domain: "com.apple.WindowManager",
        key: "StandardHideWidgets"
    )
    private static let stageManagerWidgets = PreferenceLocation(
        id: "widgets.stageManager",
        domain: "com.apple.WindowManager",
        key: "StageManagerHideWidgets"
    )
    private static let dock = PreferenceLocation(
        id: "dock",
        domain: "com.apple.dock",
        key: "autohide"
    )
    private static let menuBar = PreferenceLocation(
        id: "menuBar",
        domain: "NSGlobalDomain",
        key: "_HIHideMenuBar"
    )

    private let preferences: UserDefaults

    init(preferences: UserDefaults = .standard) {
        preferences.register(defaults: [
            Key.protectDesktop: true,
            Key.protectWidgets: true,
            Key.protectDock: true,
            Key.protectMenuBar: true
        ])
        self.preferences = preferences
        self.isActive = preferences.bool(forKey: Key.active)
        self.protectDesktop = preferences.bool(forKey: Key.protectDesktop)
        self.protectWidgets = preferences.bool(forKey: Key.protectWidgets)
        self.protectDock = preferences.bool(forKey: Key.protectDock)
        self.protectMenuBar = preferences.bool(forKey: Key.protectMenuBar)
    }

    var enabledProtectionCount: Int {
        [protectDesktop, protectWidgets, protectDock, protectMenuBar].filter { $0 }.count
    }

    fileprivate func isEnabled(_ protection: Protection) -> Bool {
        switch protection {
        case .desktop: protectDesktop
        case .widgets: protectWidgets
        case .dock: protectDock
        case .menuBar: protectMenuBar
        }
    }

    fileprivate func setEnabled(_ protection: Protection, to value: Bool) {
        switch protection {
        case .desktop: protectDesktop = value
        case .widgets: protectWidgets = value
        case .dock: protectDock = value
        case .menuBar: protectMenuBar = value
        }
    }

    func toggleStash() {
        isActive ? restore() : stash()
    }

    func openFocusSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    private func stash() {
        guard !isActive, enabledProtectionCount > 0 else { return }
        lastError = nil

        let changes: [(PreferenceLocation, Bool)] = [
            (Self.desktop, false),
            (Self.standardWidgets, true),
            (Self.stageManagerWidgets, true),
            (Self.dock, true),
            (Self.menuBar, true)
        ]

        let selectedIDs = Set([
            protectDesktop ? Self.desktop.id : nil,
            protectWidgets ? Self.standardWidgets.id : nil,
            protectWidgets ? Self.stageManagerWidgets.id : nil,
            protectDock ? Self.dock.id : nil,
            protectMenuBar ? Self.menuBar.id : nil
        ].compactMap { $0 })

        for (location, _) in changes where selectedIDs.contains(location.id) {
            saveSnapshot(for: location)
        }

        // Mark the session active before changing system settings so recovery is
        // still offered if Hideaway is interrupted partway through the update.
        preferences.set(true, forKey: Key.active)
        isActive = true

        var failed = false
        for (location, value) in changes where selectedIDs.contains(location.id) {
            if !writeBoolean(value, to: location) { failed = true }
        }
        restartAffectedServices(for: selectedIDs)

        if failed {
            lastError = "Some settings could not be changed. Restore is still available."
        }
    }

    private func restore() {
        guard isActive else { return }
        lastError = nil

        let locations = [
            Self.desktop,
            Self.standardWidgets,
            Self.stageManagerWidgets,
            Self.dock,
            Self.menuBar
        ]
        let changedIDs = Set(locations.filter(wasChanged).map(\.id))
        var failed = false

        for location in locations where wasChanged(location) {
            let existed = preferences.bool(forKey: Key.existedPrefix + location.id)
            let succeeded: Bool
            if existed {
                let value = preferences.bool(forKey: Key.valuePrefix + location.id)
                succeeded = writeBoolean(value, to: location)
            } else {
                succeeded = deletePreference(location)
            }
            if !succeeded { failed = true }
        }

        restartAffectedServices(for: changedIDs)

        if failed {
            lastError = "Your Mac could not be fully restored. Try Restore again."
            return
        }

        locations.forEach(clearSnapshot)
        preferences.removeObject(forKey: Key.active)
        isActive = false
    }

    private func saveSnapshot(for location: PreferenceLocation) {
        let value = readBoolean(from: location)
        preferences.set(true, forKey: Key.changedPrefix + location.id)
        preferences.set(value != nil, forKey: Key.existedPrefix + location.id)
        if let value {
            preferences.set(value, forKey: Key.valuePrefix + location.id)
        } else {
            preferences.removeObject(forKey: Key.valuePrefix + location.id)
        }
    }

    private func clearSnapshot(for location: PreferenceLocation) {
        preferences.removeObject(forKey: Key.changedPrefix + location.id)
        preferences.removeObject(forKey: Key.existedPrefix + location.id)
        preferences.removeObject(forKey: Key.valuePrefix + location.id)
    }

    private func wasChanged(_ location: PreferenceLocation) -> Bool {
        preferences.bool(forKey: Key.changedPrefix + location.id)
    }

    private func readBoolean(from location: PreferenceLocation) -> Bool? {
        let result = run("/usr/bin/defaults", ["read", location.domain, location.key], captureOutput: true)
        guard result.status == 0 else { return nil }
        switch result.output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes": return true
        case "0", "false", "no": return false
        default: return nil
        }
    }

    private func writeBoolean(_ value: Bool, to location: PreferenceLocation) -> Bool {
        run(
            "/usr/bin/defaults",
            ["write", location.domain, location.key, "-bool", value ? "true" : "false"]
        ).status == 0
    }

    private func deletePreference(_ location: PreferenceLocation) -> Bool {
        let result = run("/usr/bin/defaults", ["delete", location.domain, location.key])
        return result.status == 0
    }

    private func restartAffectedServices(for changedIDs: Set<String>) {
        if changedIDs.contains(Self.desktop.id) {
            _ = run("/usr/bin/killall", ["Finder"])
        }
        if changedIDs.contains(Self.standardWidgets.id) || changedIDs.contains(Self.stageManagerWidgets.id) {
            _ = run("/usr/bin/killall", ["WindowManager"])
        }
        if changedIDs.contains(Self.dock.id) {
            _ = run("/usr/bin/killall", ["Dock"])
        }
        if changedIDs.contains(Self.menuBar.id) {
            _ = run("/usr/bin/killall", ["SystemUIServer"])
        }
    }

    private func run(
        _ executable: String,
        _ arguments: [String],
        captureOutput: Bool = false
    ) -> (status: Int32, output: String) {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        task.standardOutput = captureOutput ? pipe : FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            let data = captureOutput ? pipe.fileHandleForReading.readDataToEndOfFile() : Data()
            return (task.terminationStatus, String(decoding: data, as: UTF8.self))
        } catch {
            return (-1, "")
        }
    }
}

@MainActor
private final class UpdateController {
    private let controller: SPUStandardUpdaterController?

    init() {
        guard Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil else {
            controller = nil
            return
        }

        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var isAvailable: Bool { controller != nil }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}

private struct HideawayPopover: View {
    @ObservedObject var controller: HideawayController
    let updates: UpdateController

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            primaryAction
            Divider()
            protectionList
            Divider()
            focusAction
            Divider()
            footer
        }
        .frame(width: 360)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: controller.isActive ? "tray.full.fill" : "sparkles.rectangle.stack.fill")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(controller.isActive ? Color.green : Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("Hideaway")
                    .font(.headline)
                Text(controller.isActive ? "Your Mac is stashed" : "Clear the clutter in one click")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(controller.isActive ? Color.green : Color.secondary.opacity(0.35))
                .frame(width: 8, height: 8)
                .accessibilityLabel(controller.isActive ? "Active" : "Inactive")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
    }

    private var primaryAction: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(controller.isActive ? "Your desktop is tucked away" : "Ready when you are")
                    .font(.system(size: 18, weight: .semibold))
                Text(primaryDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: controller.toggleStash) {
                Label(
                    controller.isActive ? "Restore My Mac" : "Stash My Mac",
                    systemImage: controller.isActive ? "arrow.counterclockwise" : "tray.and.arrow.down.fill"
                )
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(controller.isActive ? .orange : .accentColor)
            .disabled(!controller.isActive && controller.enabledProtectionCount == 0)

            if let error = controller.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
    }

    private var primaryDescription: String {
        if controller.isActive {
            return "Your original settings are saved. Move the pointer to the top of the screen to reveal a hidden menu bar."
        }
        let count = controller.enabledProtectionCount
        return count == 1 ? "1 protection will turn on." : "\(count) protections will turn on together."
    }

    private var protectionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("WHAT TO HIDE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 6)

            ForEach(Protection.allCases) { protection in
                protectionRow(protection)
            }
        }
        .padding(.bottom, 10)
    }

    private func protectionRow(_ protection: Protection) -> some View {
        HStack(spacing: 12) {
            Image(systemName: protection.symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(controller.isEnabled(protection) ? Color.accentColor : Color.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(protection.title)
                    .font(.system(size: 13, weight: .medium))
                Text(protection.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { controller.isEnabled(protection) },
                set: { controller.setEnabled(protection, to: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(controller.isActive)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .opacity(controller.isActive ? 0.72 : 1)
    }

    private var focusAction: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text("Silence notifications")
                    .font(.system(size: 13, weight: .medium))
                Text("Use a Focus to prevent surprise banners")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("Open Focus…", action: controller.openFocusSettings)
                .controlSize(.small)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var footer: some View {
        HStack {
            Text(controller.isActive ? "Settings locked until restored" : "Selections are remembered")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()

            if updates.isAvailable {
                Button("Check for Updates…", action: updates.checkForUpdates)
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()
                    .frame(height: 12)
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }
}

@main
struct HideawayApp: App {
    @StateObject private var controller = HideawayController()
    private let updates = UpdateController()

    var body: some Scene {
        MenuBarExtra {
            HideawayPopover(controller: controller, updates: updates)
        } label: {
            Image(systemName: controller.isActive ? "tray.full.fill" : "sparkles.rectangle.stack")
                .accessibilityLabel(controller.isActive ? "Hideaway is active" : "Hideaway")
        }
        .menuBarExtraStyle(.window)
    }
}
