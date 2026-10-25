import AppKit
import Darwin
import Foundation
import OSLog

let home = FileManager.default.homeDirectoryForCurrentUser
let supportURL = home.appendingPathComponent("Library/Application Support/MacNotif")
let hudLockURL = supportURL.appendingPathComponent("hud.lock")
let permanentURL = supportURL.appendingPathComponent("permanent.json")
let temporaryURL = supportURL.appendingPathComponent("temporary.json")

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

func runCommandLine(configuration: NoticeConfiguration) throws {
    let args = Array(CommandLine.arguments.dropFirst())
    try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
    if args == ["--clear"] {
        if FileManager.default.fileExists(atPath: permanentURL.path) {
            try FileManager.default.removeItem(at: permanentURL)
        }
        return
    }

    var title: String?
    var messageDescription: String?
    var mode = configuration.mode
    var duration = configuration.duration
    var index = 0
    while index < args.count {
        let option = args[index]
        guard ["--title", "--description", "--mode", "--duration"].contains(option) else {
            throw CLIError.unsupportedOption(option)
        }
        guard index + 1 < args.count else { throw CLIError.usage }
        let value = args[index + 1]
        switch option {
        case "--title": title = value
        case "--description": messageDescription = value
        case "--mode": mode = value
        case "--duration":
            guard let parsed = TimeInterval(value), parsed.isFinite, parsed > 0 else {
                throw CLIError.invalidDuration
            }
            duration = parsed
        default: throw CLIError.usage
        }
        index += 2
    }
    guard let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw CLIError.missingTitle
    }
    guard mode == "permanent" || mode == "temporary" else { throw CLIError.invalidMode }
    let message = HUDMessage(
        id: UUID().uuidString,
        title: title,
        description: messageDescription,
        borderColor: nil,
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
    case usage, missingTitle, invalidMode, invalidDuration, executableUnavailable
    case unsupportedOption(String)
    var description: String {
        switch self {
        case .usage: return "Usage: macnotif --title TEXT [--description TEXT] [--mode temporary|permanent] [--duration SECONDS] | macnotif --clear"
        case .unsupportedOption(let option): return "macnotif: unsupported option \(option)"
        case .missingTitle: return "macnotif: --title is required and must not be empty"
        case .invalidMode: return "macnotif: mode must be temporary or permanent"
        case .invalidDuration: return "macnotif: duration must be a positive number of seconds"
        case .executableUnavailable: return "macnotif: cannot locate the HUD executable"
        }
    }
}

let configuration: NoticeConfiguration
do {
    configuration = try NoticeConfiguration.load()
} catch {
    fputs("\(error)\n", stderr)
    exit(EXIT_FAILURE)
}

if CommandLine.arguments.count > 1 {
    do { try runCommandLine(configuration: configuration) }
    catch {
        fputs("\(error)\n", stderr)
        exit(EXIT_FAILURE)
    }
    exit(EXIT_SUCCESS)
}

final class HUDApplication: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.mohrworks.macnotif", category: "HUD")
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
    private var warnedUnavailableDisplayID: UInt32?
    private static let collectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces, .stationary, .ignoresCycle
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard acquireHUDLock() else {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        ProcessInfo.processInfo.disableAutomaticTermination("MacNotif is displaying notices")
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
            fputs("macnotif: cannot create HUD state directory: \(error)\n", stderr)
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
            fputs("macnotif: cannot lock HUD process: \(String(cString: strerror(lockError)))\n", stderr)
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

    private func targetScreen() -> NSScreen? {
        let screens = NSScreen.screens
        let mainScreen = screens.first
        guard let displayID = configuration.displayID else {
            warnedUnavailableDisplayID = nil
            return mainScreen
        }
        if let screen = screens.first(where: { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            else { return false }
            return number.uint32Value == displayID
        }) {
            warnedUnavailableDisplayID = nil
            return screen
        }
        if warnedUnavailableDisplayID != displayID {
            logger.warning("Configured display \(displayID, privacy: .public) is unavailable; using the main display")
            warnedUnavailableDisplayID = displayID
        }
        return mainScreen
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
        return .controlAccentColor
    }

    private func readMessage(at url: URL) -> HUDMessage? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do { return try JSONDecoder().decode(HUDMessage.self, from: Data(contentsOf: url)) }
        catch {
            fputs("macnotif: cannot read \(url.lastPathComponent): \(error)\n", stderr)
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
        guard let screen = targetScreen() else { return }
        if needsWindowRecovery || !panel.isVisible {
            panel.collectionBehavior = Self.collectionBehavior
            panel.level = .statusBar
        }
        if needsWindowRecovery {
            needsWindowRecovery = false
            panel.orderOut(nil)
        }
        let visible = screen.visibleFrame
        let horizontalInset = CGFloat(configuration.layout.horizontalInset)
        let verticalInset = CGFloat(configuration.layout.verticalInset)
        let origin: NSPoint
        switch configuration.layout.anchor {
        case "top-left":
            origin = NSPoint(x: visible.minX + horizontalInset,
                             y: visible.maxY - panel.frame.height - verticalInset)
        case "bottom-left":
            origin = NSPoint(x: visible.minX + horizontalInset,
                             y: visible.minY + verticalInset)
        case "bottom-right":
            origin = NSPoint(x: visible.maxX - panel.frame.width - horizontalInset,
                             y: visible.minY + verticalInset)
        default:
            origin = NSPoint(x: visible.maxX - panel.frame.width - horizontalInset,
                             y: visible.maxY - panel.frame.height - verticalInset)
        }
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }
}

let application = NSApplication.shared
let delegate = HUDApplication()
application.delegate = delegate
application.run()
