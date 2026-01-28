import SwiftUI
import MacSnapCore
import AppKit

/// Main preferences window
public struct PreferencesView: View {
    @State private var selectedTab = 0

    private let tabs = [
        (name: "General", icon: "gearshape"),
        (name: "Shortcuts", icon: "keyboard"),
        (name: "Output", icon: "folder"),
        (name: "Permissions", icon: "lock.shield"),
        (name: "About", icon: "info.circle")
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar that won't collapse
            HStack(spacing: 2) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    VStack(spacing: 4) {
                        Image(systemName: tabs[index].icon)
                            .font(.system(size: 16))
                        Text(tabs[index].name)
                            .font(.system(size: 11))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedTab == index ? Color.accentColor.opacity(0.15) : Color.clear)
                    .foregroundColor(selectedTab == index ? .accentColor : .secondary)
                    .cornerRadius(6)
                    .contentShape(Rectangle())  // Make entire area clickable
                    .onTapGesture {
                        selectedTab = index
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case 0: GeneralTab()
                case 1: ShortcutsTab()
                case 2: OutputTab()
                case 3: PermissionsTab()
                case 4: AboutTab()
                default: GeneralTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: 540)
    }
}

/// General settings tab
struct GeneralTab: View {
    @State private var config = ConfigManager.shared.config

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Capture Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Include cursor in screenshots", isOn: $config.capture.includeCursor)
                            .onChange(of: config.capture.includeCursor) { newValue in
                                ConfigManager.shared.update(\.capture.includeCursor, to: newValue)
                            }

                        Toggle("Include window shadow", isOn: $config.capture.includeShadow)
                            .onChange(of: config.capture.includeShadow) { newValue in
                                ConfigManager.shared.update(\.capture.includeShadow, to: newValue)
                            }

                        Toggle("Preserve hover states", isOn: $config.capture.preserveHoverStates)
                            .onChange(of: config.capture.preserveHoverStates) { newValue in
                                ConfigManager.shared.update(\.capture.preserveHoverStates, to: newValue)
                            }

                        Text("Freezes screen when hotkey is pressed to capture hover effects")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)

                        Toggle("Play sound on capture", isOn: $config.capture.soundEnabled)
                            .onChange(of: config.capture.soundEnabled) { newValue in
                                ConfigManager.shared.update(\.capture.soundEnabled, to: newValue)
                            }

                        Toggle("Show notification after capture", isOn: $config.capture.showNotification)
                            .onChange(of: config.capture.showNotification) { newValue in
                                ConfigManager.shared.update(\.capture.showNotification, to: newValue)
                            }

                        Divider()

                        Toggle("Show preview after capture", isOn: $config.capture.showPreview)
                            .onChange(of: config.capture.showPreview) { newValue in
                                ConfigManager.shared.update(\.capture.showPreview, to: newValue)
                            }

                        if config.capture.showPreview {
                            HStack {
                                Text("Preview duration:")
                                Spacer()
                                Picker("", selection: $config.capture.previewDuration) {
                                    Text("3 seconds").tag(3.0)
                                    Text("5 seconds").tag(5.0)
                                    Text("7 seconds").tag(7.0)
                                    Text("10 seconds").tag(10.0)
                                }
                                .labelsHidden()
                                .frame(width: 120)
                                .onChange(of: config.capture.previewDuration) { newValue in
                                    ConfigManager.shared.update(\.capture.previewDuration, to: newValue)
                                }
                            }
                            .padding(.leading, 20)

                            Text("Click preview to edit in Preview.app. Option+click to delete.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                        }

                        Divider()

                        HStack {
                            Text("Retina scale:")
                            Spacer()
                            Picker("", selection: $config.capture.retinaScale) {
                                ForEach(RetinaScale.allCases, id: \.self) { scale in
                                    Text(scale.displayName).tag(scale)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                            .onChange(of: config.capture.retinaScale) { newValue in
                                ConfigManager.shared.update(\.capture.retinaScale, to: newValue)
                            }
                        }
                    }
                    .padding(4)
                } label: {
                    Label("Capture", systemImage: "camera")
                        .font(.headline)
                }

                // Startup Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Launch at login", isOn: $config.advanced.launchAtLogin)
                            .onChange(of: config.advanced.launchAtLogin) { newValue in
                                ConfigManager.shared.update(\.advanced.launchAtLogin, to: newValue)
                            }

                        Toggle("Show in Dock", isOn: $config.advanced.showInDock)
                            .onChange(of: config.advanced.showInDock) { newValue in
                                // Prevent hiding from both Dock and Menu Bar
                                if !newValue && !config.advanced.showInMenuBar {
                                    // Force show in menu bar if hiding from dock
                                    config.advanced.showInMenuBar = true
                                    ConfigManager.shared.update(\.advanced.showInMenuBar, to: true)
                                }
                                ConfigManager.shared.update(\.advanced.showInDock, to: newValue)
                            }

                        Toggle("Show in Menu Bar", isOn: $config.advanced.showInMenuBar)
                            .onChange(of: config.advanced.showInMenuBar) { newValue in
                                // Prevent hiding from both Dock and Menu Bar
                                if !newValue && !config.advanced.showInDock {
                                    // Force show in dock if hiding from menu bar
                                    config.advanced.showInDock = true
                                    ConfigManager.shared.update(\.advanced.showInDock, to: true)
                                }
                                ConfigManager.shared.update(\.advanced.showInMenuBar, to: newValue)
                            }

                        Text("App must be visible in at least one location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(4)
                } label: {
                    Label("Startup", systemImage: "power")
                        .font(.headline)
                }

                Spacer()
            }
            .padding(20)
        }
    }
}

/// Keyboard shortcuts tab
struct ShortcutsTab: View {
    @State private var config = ConfigManager.shared.config

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Enable/Disable Section
                GroupBox {
                    Toggle("Enable global shortcuts", isOn: $config.shortcuts.enabled)
                        .onChange(of: config.shortcuts.enabled) { newValue in
                            ConfigManager.shared.update(\.shortcuts.enabled, to: newValue)
                        }
                        .padding(4)
                } label: {
                    Label("Status", systemImage: "power")
                        .font(.headline)
                }

                // Capture Shortcuts Section
                GroupBox {
                    VStack(spacing: 12) {
                        ShortcutRow(
                            title: "Full Screen",
                            shortcut: $config.shortcuts.fullScreen,
                            keyPath: \.shortcuts.fullScreen
                        )

                        Divider()

                        ShortcutRow(
                            title: "Area Select",
                            shortcut: $config.shortcuts.areaSelect,
                            keyPath: \.shortcuts.areaSelect
                        )

                        Divider()

                        ShortcutRow(
                            title: "Window Capture",
                            shortcut: $config.shortcuts.windowCapture,
                            keyPath: \.shortcuts.windowCapture
                        )

                        Divider()

                        ShortcutRow(
                            title: "Custom Region",
                            shortcut: $config.shortcuts.customRegion,
                            keyPath: \.shortcuts.customRegion
                        )
                    }
                    .padding(4)
                } label: {
                    Label("Capture Shortcuts", systemImage: "keyboard")
                        .font(.headline)
                }

                // Advanced Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Disable native macOS shortcuts", isOn: $config.advanced.disableNativeShortcuts)
                            .onChange(of: config.advanced.disableNativeShortcuts) { newValue in
                                ConfigManager.shared.update(\.advanced.disableNativeShortcuts, to: newValue)
                            }

                        Text("Intercepts Cmd+Shift+3/4/5")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(4)
                } label: {
                    Label("Advanced", systemImage: "gearshape.2")
                        .font(.headline)
                }

                Spacer()
            }
            .padding(20)
        }
    }
}

/// Shortcut row with editable field
struct ShortcutRow: View {
    let title: String
    @Binding var shortcut: String
    let keyPath: WritableKeyPath<AppConfig, String>

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 120, alignment: .leading)

            Spacer()

            TextField("e.g. cmd+shift+1", text: $shortcut)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
                .onChange(of: shortcut) { newValue in
                    ConfigManager.shared.update(keyPath, to: newValue)
                }

            Text(HotkeyManager.formatShortcut(shortcut))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
    }
}

/// Output settings tab
struct OutputTab: View {
    @State private var config = ConfigManager.shared.config

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Save Location Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            TextField("Directory", text: $config.output.directory)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: config.output.directory) { newValue in
                                    ConfigManager.shared.update(\.output.directory, to: newValue)
                                }

                            Button("Browse...") {
                                selectDirectory()
                            }
                        }

                        Divider()

                        HStack {
                            Text("Organize files:")
                            Spacer()
                            Picker("", selection: $config.output.organize) {
                                ForEach(OrganizeMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)
                            .onChange(of: config.output.organize) { newValue in
                                ConfigManager.shared.update(\.output.organize, to: newValue)
                            }
                        }
                    }
                    .padding(4)
                } label: {
                    Label("Save Location", systemImage: "folder")
                        .font(.headline)
                }

                // File Format Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Format:")
                            Spacer()
                            Picker("", selection: $config.output.format) {
                                ForEach(ImageFormat.allCases, id: \.self) { format in
                                    Text(format.rawValue.uppercased()).tag(format)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                            .onChange(of: config.output.format) { newValue in
                                ConfigManager.shared.update(\.output.format, to: newValue)
                            }
                        }

                        if config.output.format == .jpg {
                            HStack {
                                Text("Quality: \(config.output.jpgQuality)%")
                                    .frame(width: 80, alignment: .leading)
                                Slider(value: Binding(
                                    get: { Double(config.output.jpgQuality) },
                                    set: {
                                        config.output.jpgQuality = Int($0)
                                        ConfigManager.shared.update(\.output.jpgQuality, to: Int($0))
                                    }
                                ), in: 1...100, step: 1)
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Filename template:")
                            TextField("macsnap_{datetime}_{mode}", text: $config.output.filenameTemplate)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: config.output.filenameTemplate) { newValue in
                                    ConfigManager.shared.update(\.output.filenameTemplate, to: newValue)
                                }
                            Text("Variables: {datetime}, {date}, {time}, {mode}, {app}")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(4)
                } label: {
                    Label("File Format", systemImage: "doc")
                        .font(.headline)
                }

                // Output Options Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Copy to clipboard", isOn: $config.output.clipboardEnabled)
                            .onChange(of: config.output.clipboardEnabled) { newValue in
                                ConfigManager.shared.update(\.output.clipboardEnabled, to: newValue)
                            }

                        Toggle("Save to file", isOn: $config.output.fileEnabled)
                            .onChange(of: config.output.fileEnabled) { newValue in
                                ConfigManager.shared.update(\.output.fileEnabled, to: newValue)
                            }
                    }
                    .padding(4)
                } label: {
                    Label("Output Options", systemImage: "square.and.arrow.up")
                        .font(.headline)
                }

                Spacer()
            }
            .padding(20)
        }
    }

    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            config.output.directory = url.path
            ConfigManager.shared.update(\.output.directory, to: url.path)
        }
    }
}

/// Permissions tab
struct PermissionsTab: View {
    @State private var hasScreenRecording = false
    @State private var hasAccessibility = false
    @State private var refreshID = UUID()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Screen Recording Permission
                GroupBox {
                    HStack(spacing: 16) {
                        Image(systemName: hasScreenRecording ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(hasScreenRecording ? .green : .red)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Screen Recording")
                                .font(.headline)

                            Text(hasScreenRecording
                                ? "MacSnap can capture your screen"
                                : "Required to capture screenshots")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !hasScreenRecording {
                            Button("Grant Access") {
                                openScreenRecordingSettings()
                            }
                        } else {
                            Text("Granted")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .padding(8)
                } label: {
                    Label("Screen Capture", systemImage: "rectangle.dashed.and.paperclip")
                        .font(.headline)
                }

                // Accessibility Permission
                GroupBox {
                    HStack(spacing: 16) {
                        Image(systemName: hasAccessibility ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(hasAccessibility ? .green : .red)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Accessibility")
                                .font(.headline)

                            Text(hasAccessibility
                                ? "Global hotkeys are enabled"
                                : "Required for global keyboard shortcuts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !hasAccessibility {
                            Button("Grant Access") {
                                openAccessibilitySettings()
                            }
                        } else {
                            Text("Granted")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .padding(8)
                } label: {
                    Label("Keyboard Shortcuts", systemImage: "keyboard")
                        .font(.headline)
                }

                // Information
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why are these permissions needed?")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("• **Screen Recording** allows MacSnap to capture screenshots of your screen, windows, and selected areas.")
                            .font(.caption)

                        Text("• **Accessibility** allows MacSnap to listen for global keyboard shortcuts even when other apps are in focus.")
                            .font(.caption)

                        Divider()
                            .padding(.vertical, 4)

                        Text("After granting permissions, you may need to restart MacSnap for changes to take effect.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                } label: {
                    Label("Information", systemImage: "info.circle")
                        .font(.headline)
                }

                HStack {
                    Spacer()
                    Button(action: refreshPermissions) {
                        Label("Refresh Status", systemImage: "arrow.clockwise")
                    }
                    Spacer()
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding(20)
        }
        .id(refreshID)
        .onAppear {
            refreshPermissions()
        }
    }

    private func refreshPermissions() {
        hasScreenRecording = CaptureEngine.shared.hasScreenCapturePermission()
        hasAccessibility = HotkeyManager.shared.hasAccessibilityPermission()
        refreshID = UUID()
    }

    private func openScreenRecordingSettings() {
        // First trigger the permission request
        CaptureEngine.shared.requestScreenCapturePermission()

        // Then open System Settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAccessibilitySettings() {
        // Just open System Settings - no need to trigger system dialog
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// About tab
struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text("MacSnap")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("A lightweight screenshot tool for macOS")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .frame(width: 200)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 6) {
                FeatureRow(icon: "doc.on.clipboard", text: "Dual output (clipboard + file)")
                FeatureRow(icon: "rectangle.dashed", text: "Full screen, area, window capture")
                FeatureRow(icon: "keyboard", text: "Configurable hotkeys")
                FeatureRow(icon: "textformat", text: "Customizable filenames")
            }
            .font(.caption)

            Spacer()

            Text("2025 MacSnap")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 16)
                .foregroundColor(.accentColor)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    PreferencesView()
}
