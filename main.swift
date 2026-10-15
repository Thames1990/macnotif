import AppKit
import Darwin
import Foundation

let home = FileManager.default.homeDirectoryForCurrentUser
let supportURL = home.appendingPathComponent("Library/Application Support/DinkyModeHUD")
let hudLockURL = supportURL.appendingPathComponent("hud.lock")
let permanentURL = supportURL.appendingPathComponent("permanent.json")
let temporaryURL = supportURL.appendingPathComponent("temporary.json")
let configURL = home.appendingPathComponent(".config/dinky/dinky.toml")

struct HUDMessage: Codable {
    let id: String
    let title: String
    let description: String?
    let borderColor: String?
    let createdAt: Date
    let duration: TimeInterval?
}

func color(from hex: String?) -> NSColor? {
    guard let value = hex?.trimmingCharacters(in: CharacterSet(charactersIn: "#")),
          value.count == 6 || value.count == 8,
          let number = UInt64(value, radix: 16) else { return nil }
    let shift: UInt64 = value.count == 8 ? 8 : 0
    let rgb = UInt32(number >> shift)
    let alpha: CGFloat = value.count == 8 ? CGFloat(number & 0xff) / 255 : 1
    return NSColor(
        srgbRed: CGFloat((rgb >> 16) & 0xff) / 255,
        green: CGFloat((rgb >> 8) & 0xff) / 255,
        blue: CGFloat(rgb & 0xff) / 255,
        alpha: alpha
    )
}

func runCommandLine() throws {
    let args = Array(CommandLine.arguments.dropFirst())
    try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
    if args == ["end"] {
        if FileManager.default.fileExists(atPath: permanentURL.path) {
            try FileManager.default.removeItem(at: permanentURL)
        }
        return
    }

    var title: String?
    var messageDescription: String?
    var mode = "temporary"
    var borderColor: String?
    var duration: TimeInterval = 1
    if args.count == 2, args[0] == "mode" {
        if args[1] == "main" {
            if FileManager.default.fileExists(atPath: permanentURL.path) {
                try FileManager.default.removeItem(at: permanentURL)
            }
            return
        }
        title = "MODE: \(args[1])"
        mode = "permanent"
    } else {
        var index = 0
        while index < args.count {
            let option = args[index]
            guard index + 1 < args.count else { throw CLIError.usage }
            let value = args[index + 1]
            switch option {
            case "--title": title = value
            case "--description": messageDescription = value
            case "--mode": mode = value
            case "--border-color":
                guard color(from: value) != nil else { throw CLIError.invalidColor }
                borderColor = value
            case "--duration":
                guard let parsed = TimeInterval(value), parsed.isFinite, parsed > 0 else {
                    throw CLIError.invalidDuration
                }
                duration = parsed
            default: throw CLIError.usage
            }
            index += 2
        }
    }
    guard let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw CLIError.missingTitle
    }
    guard mode == "permanent" || mode == "temporary" else { throw CLIError.invalidMode }
    let message = HUDMessage(
        id: UUID().uuidString,
        title: title,
        description: messageDescription,
        borderColor: borderColor,
        createdAt: Date(),
        duration: mode == "temporary" ? duration : nil
    )
    let destination = mode == "permanent" ? permanentURL : temporaryURL
    let data = try JSONEncoder().encode(message)
    try data.write(to: destination, options: .atomic)
    guard let executableURL = Bundle.main.executableURL else {
        throw CLIError.executableUnavailable
    }
    let process = Process()
    process.executableURL = executableURL
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
}

enum CLIError: Error, CustomStringConvertible {
    case usage, missingTitle, invalidMode, invalidDuration, invalidColor, executableUnavailable
    var description: String {
        switch self {
        case .usage: return "Usage: dinky-notify --title TEXT [--description TEXT] [--mode temporary|permanent] [--duration SECONDS] [--border-color HEX] | dinky-notify mode NAME | dinky-notify end"
        case .missingTitle: return "dinky-notify: --title is required and must not be empty"
        case .invalidMode: return "dinky-notify: mode must be temporary or permanent"
        case .invalidDuration: return "dinky-notify: duration must be a positive number of seconds"
        case .invalidColor: return "dinky-notify: border color must be a 6- or 8-digit hex color"
        case .executableUnavailable: return "dinky-notify: cannot locate the HUD executable"
        }
    }
}

if CommandLine.arguments.count > 1 {
    do { try runCommandLine() }
    catch {
        fputs("\(error)\n", stderr)
        exit(EXIT_FAILURE)
    }
    exit(EXIT_SUCCESS)
}

final class HUDApplication: NSObject, NSApplicationDelegate {
    private var panel: NSPanel!
    private var permanentBar: NSVisualEffectView!
    private var temporaryBar: NSVisualEffectView!
    private var permanentTitle: NSTextField!
    private var temporaryTitle: NSTextField!
    private var permanentDescription: NSTextField!
    private var temporaryDescription: NSTextField!
    private var permanentIcon: NSImageView!
    private var temporaryIcon: NSImageView!
    private var hudLockDescriptor: Int32?
    private var needsWindowRecovery = false
    private static let collectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces, .stationary, .ignoresCycle
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard acquireHUDLock() else {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        ProcessInfo.processInfo.disableAutomaticTermination("Dinky notification HUD is displaying notifications")
        createPanel()
        observeSystemChanges()
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hudLockDescriptor {
            Darwin.close(hudLockDescriptor)
            self.hudLockDescriptor = nil
        }
    }

    private func acquireHUDLock() -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: supportURL,
                withIntermediateDirectories: true
            )
        } catch {
            fputs("dinky-notify: cannot create HUD state directory: \(error)\n", stderr)
            return false
        }

        let descriptor = Darwin.open(
            hudLockURL.path,
            O_CREAT | O_RDWR | O_EXLOCK | O_NONBLOCK,
            mode_t(S_IRUSR | S_IWUSR)
        )
        guard descriptor >= 0 else {
            let lockError = errno
            if lockError == EWOULDBLOCK || lockError == EAGAIN {
                return false
            }
            fputs("dinky-notify: cannot lock HUD process: \(String(cString: strerror(lockError)))\n", stderr)
            return false
        }

        hudLockDescriptor = descriptor
        return true
    }

    private func createPanel() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = Self.collectionBehavior

        (permanentBar, permanentTitle, permanentDescription, permanentIcon) = makeBar(
            symbol: "circle.fill", titleSize: 15
        )
        (temporaryBar, temporaryTitle, temporaryDescription, temporaryIcon) = makeBar(
            symbol: "arrow.triangle.2.circlepath", titleSize: 14
        )
        panel.contentView?.addSubview(permanentBar)
        panel.contentView?.addSubview(temporaryBar)
    }

    // Sleep, display reconfiguration, and Space switches can leave the panel
    // pinned to a single Space or a stale screen; re-home it when they occur.
    private func observeSystemChanges() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification,
                     NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification,
                     NSWorkspace.activeSpaceDidChangeNotification] {
            workspaceCenter.addObserver(self, selector: #selector(systemDidChange(_:)),
                                        name: name, object: nil)
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(systemDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    @objc private func systemDidChange(_ notification: Notification) {
        scheduleWindowRecovery()
        guard notification.name != NSWorkspace.activeSpaceDidChangeNotification else { return }
        // Displays often reconnect in stages after wake, so recover again once they settle.
        for delay in [1.0, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.scheduleWindowRecovery()
            }
        }
    }

    private func scheduleWindowRecovery() {
        needsWindowRecovery = true
        refresh()
    }

    private func makeBar(symbol: String, titleSize: CGFloat)
        -> (NSVisualEffectView, NSTextField, NSTextField, NSImageView) {
        let bar = NSVisualEffectView()
        bar.material = .hudWindow
        bar.blendingMode = .behindWindow
        bar.state = .active
        bar.wantsLayer = true
        bar.layer?.cornerRadius = 15
        bar.layer?.masksToBounds = true

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .semibold))
        icon.translatesAutoresizingMaskIntoConstraints = false
        let title = NSTextField(labelWithString: "")
        title.font = .systemFont(ofSize: titleSize, weight: .semibold)
        title.lineBreakMode = .byTruncatingTail
        let detail = NSTextField(labelWithString: "")
        detail.font = .systemFont(ofSize: 12, weight: .regular)
        detail.lineBreakMode = .byTruncatingTail
        let labels = NSStackView(views: [title, detail])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2
        labels.detachesHiddenViews = true
        labels.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(icon)
        bar.addSubview(labels)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 18),
            icon.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            labels.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            labels.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            labels.trailingAnchor.constraint(lessThanOrEqualTo: bar.trailingAnchor, constant: -18)
        ])
        return (bar, title, detail, icon)
    }

    private func configuredBorderColor(_ override: String?) -> NSColor {
        if let override, let color = color(from: override) { return color }
        return color(from: dinkyBorderHex()) ?? .controlAccentColor
    }

    private func dinkyBorderHex() -> String? {
        guard let contents = try? String(contentsOf: configURL, encoding: .utf8) else { return nil }
        var inBorders = false
        for line in contents.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") {
                inBorders = trimmed == "[borders]"
                continue
            }
            guard inBorders, let separator = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[..<separator].trimmingCharacters(in: .whitespaces)
            if key == "active-color" {
                return trimmed[trimmed.index(after: separator)...]
                    .trimmingCharacters(in: CharacterSet(charactersIn: " '\""))
            }
        }
        return nil
    }

    private func readMessage(at url: URL) -> HUDMessage? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do { return try JSONDecoder().decode(HUDMessage.self, from: Data(contentsOf: url)) }
        catch {
            fputs("dinky-notify: cannot read \(url.lastPathComponent): \(error)\n", stderr)
            return nil
        }
    }

    private func style(_ bar: NSVisualEffectView, title: NSTextField,
                       detail: NSTextField, icon: NSImageView, message: HUDMessage?) {
        guard let message else { return }
        let tint = configuredBorderColor(message.borderColor)
        title.stringValue = message.title
        detail.stringValue = message.description ?? ""
        detail.isHidden = message.description?.isEmpty != false
        title.textColor = .labelColor
        detail.textColor = .secondaryLabelColor
        icon.contentTintColor = .secondaryLabelColor
        bar.layer?.borderColor = tint.cgColor
        bar.layer?.borderWidth = 1
    }

    private func refresh() {
        let permanent = readMessage(at: permanentURL)
        let storedTemporary = readMessage(at: temporaryURL)
        let temporary = storedTemporary.flatMap { message -> HUDMessage? in
            guard let duration = message.duration,
                  Date().timeIntervalSince(message.createdAt) < duration else { return nil }
            return message
        }
        style(permanentBar, title: permanentTitle, detail: permanentDescription,
              icon: permanentIcon, message: permanent)
        style(temporaryBar, title: temporaryTitle, detail: temporaryDescription,
              icon: temporaryIcon, message: temporary)
        permanentBar.isHidden = permanent == nil
        temporaryBar.isHidden = temporary == nil
        guard permanent != nil || temporary != nil else {
            panel.orderOut(nil)
            needsWindowRecovery = false
            return
        }
        let permanentHeight: CGFloat = permanent?.description?.isEmpty == false ? 68 : 54
        let temporaryHeight: CGFloat = temporary?.description?.isEmpty == false ? 62 : 50
        let bothVisible = permanent != nil && temporary != nil
        let height = bothVisible ? permanentHeight + 8 + temporaryHeight
            : permanent != nil ? permanentHeight : temporaryHeight
        panel.setContentSize(NSSize(width: 420, height: height))
        permanentBar.frame = NSRect(x: 0, y: bothVisible ? temporaryHeight + 8 : 0,
                                    width: 420, height: permanentHeight)
        temporaryBar.frame = NSRect(x: 0, y: 0, width: 420, height: temporaryHeight)
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        if needsWindowRecovery || !panel.isVisible {
            panel.collectionBehavior = Self.collectionBehavior
            panel.level = .statusBar
        }
        if needsWindowRecovery {
            needsWindowRecovery = false
            panel.orderOut(nil)
        }
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: visible.midX - panel.frame.width / 2,
                                     y: visible.maxY - panel.frame.height - 18))
        panel.orderFrontRegardless()
    }
}

let application = NSApplication.shared
let delegate = HUDApplication()
application.delegate = delegate
application.run()
