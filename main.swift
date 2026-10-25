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

let startupConfiguration: NoticeConfiguration
do {
    startupConfiguration = try NoticeConfiguration.load()
} catch {
    fputs("\(error)\n", stderr)
    exit(EXIT_FAILURE)
}

if CommandLine.arguments.count > 1 {
    do { try runCommandLine(configuration: startupConfiguration) }
    catch {
        fputs("\(error)\n", stderr)
        exit(EXIT_FAILURE)
    }
    exit(EXIT_SUCCESS)
}

final class NoticeBar: NSVisualEffectView {
    private let background = NSView()
    private let title = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")
    private let icon = NSImageView()
    private let labels = NSStackView()
    private var leading: NSLayoutConstraint!
    private var trailing: NSLayoutConstraint!
    private var iconGap: NSLayoutConstraint!
    private var iconWidth: NSLayoutConstraint!
    private var iconHeight: NSLayoutConstraint!
    private var previousID: String?
    private var currentSymbol: String?
    private var tokens = AppearanceConfiguration()

    init() {
        super.init(frame: .zero)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.masksToBounds = true
        title.lineBreakMode = .byTruncatingTail
        detail.lineBreakMode = .byTruncatingTail
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        labels.addArrangedSubview(title)
        labels.addArrangedSubview(detail)
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.detachesHiddenViews = true
        background.wantsLayer = true
        background.translatesAutoresizingMaskIntoConstraints = false
        icon.translatesAutoresizingMaskIntoConstraints = false
        labels.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)
        addSubview(icon)
        addSubview(labels)
        leading = icon.leadingAnchor.constraint(equalTo: leadingAnchor)
        trailing = labels.trailingAnchor.constraint(equalTo: trailingAnchor)
        iconGap = labels.leadingAnchor.constraint(equalTo: icon.trailingAnchor)
        iconWidth = icon.widthAnchor.constraint(equalToConstant: 16)
        iconHeight = icon.heightAnchor.constraint(equalToConstant: 16)
        NSLayoutConstraint.activate([
            leading, trailing, iconGap, iconWidth, iconHeight,
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            labels.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColors()
    }

    func update(message: HUDMessage?, permanent: Bool, appearance: AppearanceConfiguration) -> CGFloat {
        tokens = appearance
        title.stringValue = message?.title ?? ""
        detail.stringValue = message?.description ?? ""
        detail.isHidden = message?.description?.isEmpty != false
        let preferredTitle = NSFont.preferredFont(forTextStyle: .headline, options: [:])
        let preferredDetail = NSFont.preferredFont(forTextStyle: .body, options: [:])
        // A design token can enlarge text, never shrink the system's preferred size.
        title.font = NSFontManager.shared.convert(
            preferredTitle, toSize: max(appearance.titleSize, preferredTitle.pointSize)
        )
        detail.font = NSFontManager.shared.convert(
            preferredDetail, toSize: max(appearance.detailSize, preferredDetail.pointSize)
        )
        let symbol = permanent ? appearance.permanentSymbol : appearance.temporarySymbol
        if currentSymbol != symbol {
            icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            currentSymbol = symbol
        }
        icon.symbolConfiguration = .init(pointSize: appearance.symbolSize, weight: .medium)
        leading.constant = appearance.padding
        trailing.constant = -appearance.padding
        iconGap.constant = appearance.iconSpacing
        iconWidth.constant = appearance.symbolSize
        iconHeight.constant = appearance.symbolSize
        labels.spacing = appearance.textSpacing
        layer?.cornerRadius = appearance.cornerRadius
        applyColors()

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            || appearance.animationDuration == 0 || message == nil {
            layer?.removeAnimation(forKey: "noticeReveal")
        } else if previousID != message?.id, appearance.animationDuration > 0 {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = appearance.animationDuration
            fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer?.add(fade, forKey: "noticeReveal")
        }
        previousID = message?.id
        let textHeight = title.fittingSize.height
            + (detail.isHidden ? 0 : detail.fittingSize.height + appearance.textSpacing)
        return max(appearance.minHeight, max(appearance.symbolSize, textHeight) + 2 * appearance.padding)
    }

    private func applyColors() {
        guard let layer else { return }
        let contrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        let opaque = contrast || NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let colors = dark ? tokens.dark : tokens.light
        effectiveAppearance.performAsCurrentDrawingAppearance {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            title.textColor = contrast ? .labelColor : color(from: colors.title) ?? .labelColor
            detail.textColor = contrast ? .labelColor : color(from: colors.detail) ?? .secondaryLabelColor
            icon.contentTintColor = contrast ? .labelColor : color(from: colors.symbol) ?? .secondaryLabelColor
            background.layer?.backgroundColor = opaque
                ? NSColor.windowBackgroundColor.cgColor : color(from: colors.background)?.cgColor
            layer.borderColor = contrast ? NSColor.labelColor.cgColor
                : (color(from: colors.border) ?? .separatorColor).cgColor
            layer.borderWidth = contrast ? max(1, tokens.borderWidth) : tokens.borderWidth
            CATransaction.commit()
        }
    }
}

final class HUDApplication: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.mohrworks.macnotif", category: "HUD")
    private var configuration = startupConfiguration
    private var lastConfigurationError: String?
    private var panel: NSPanel!
    private var permanentBar: NoticeBar!
    private var temporaryBar: NoticeBar!
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
            contentRect: NSRect(x: 0, y: 0, width: configuration.appearance.width,
                                height: configuration.appearance.minHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = configuration.appearance.shadow
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = Self.collectionBehavior

        permanentBar = NoticeBar()
        temporaryBar = NoticeBar()
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
        workspaceCenter.addObserver(
            self, selector: #selector(accessibilityDidChange(_:)),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil
        )
    }

    @objc private func accessibilityDidChange(_ notification: Notification) {
        refresh()
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

    private func readMessage(at url: URL) -> HUDMessage? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do { return try JSONDecoder().decode(HUDMessage.self, from: Data(contentsOf: url)) }
        catch {
            fputs("macnotif: cannot read \(url.lastPathComponent): \(error)\n", stderr)
            return nil
        }
    }

    private func refresh() {
        do {
            configuration = try NoticeConfiguration.load()
            lastConfigurationError = nil
        } catch {
            let diagnostic = String(describing: error)
            if diagnostic != lastConfigurationError {
                logger.error("Cannot reload configuration; keeping last known-good settings: \(diagnostic, privacy: .public)")
                lastConfigurationError = diagnostic
            }
        }
        let permanent = readMessage(at: permanentURL)
        let storedTemporary = readMessage(at: temporaryURL)
        let temporary = storedTemporary.flatMap { message -> HUDMessage? in
            guard let duration = message.duration,
                  Date().timeIntervalSince(message.createdAt) < duration else { return nil }
            return message
        }
        let appearance = configuration.appearance
        let permanentHeight = permanentBar.update(message: permanent, permanent: true, appearance: appearance)
        let temporaryHeight = temporaryBar.update(message: temporary, permanent: false, appearance: appearance)
        panel.hasShadow = appearance.shadow
        permanentBar.isHidden = permanent == nil
        temporaryBar.isHidden = temporary == nil
        guard permanent != nil || temporary != nil else {
            panel.orderOut(nil)
            needsWindowRecovery = false
            return
        }
        let bothVisible = permanent != nil && temporary != nil
        let height = bothVisible ? permanentHeight + appearance.stackSpacing + temporaryHeight
            : permanent != nil ? permanentHeight : temporaryHeight
        let width = max(appearance.width, 2 * appearance.padding + appearance.symbolSize + appearance.iconSpacing + 96)
        panel.setContentSize(NSSize(width: width, height: height))
        permanentBar.frame = NSRect(x: 0, y: bothVisible ? temporaryHeight + appearance.stackSpacing : 0,
                                    width: width, height: permanentHeight)
        temporaryBar.frame = NSRect(x: 0, y: 0, width: width, height: temporaryHeight)
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
