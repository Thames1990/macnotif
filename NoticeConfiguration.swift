import AppKit
import Foundation
import TOMLKit

struct ConfigurationError: Error, CustomStringConvertible {
    let description: String
}

struct AppearanceColors {
    var background: String?
    var title: String?
    var detail: String?
    var symbol: String?
    var border: String?
}

struct AppearanceConfiguration {
    var width: CGFloat = 360
    var minHeight: CGFloat = 54
    var padding: CGFloat = 14
    var iconSpacing: CGFloat = 12
    var textSpacing: CGFloat = 2
    var stackSpacing: CGFloat = 8
    var titleSize: CGFloat = 14
    var detailSize: CGFloat = 13
    var symbolSize: CGFloat = 16
    var cornerRadius: CGFloat = 14
    var shadow = true
    var permanentSymbol = "pin.fill"
    var temporarySymbol = "bell.fill"
    var animationDuration: TimeInterval = 0.15
    var borderWidth: CGFloat = 0
    var light = AppearanceColors()
    var dark = AppearanceColors()

    init() {}

    init(table: TOMLTable) throws {
        self.init()
        let numeric: [String: (WritableKeyPath<AppearanceConfiguration, CGFloat>, ClosedRange<Double>)] = [
            "width": (\.width, 160...1200),
            "min_height": (\.minHeight, 32...400),
            "padding": (\.padding, 0...80),
            "icon_spacing": (\.iconSpacing, 0...80),
            "text_spacing": (\.textSpacing, 0...40),
            "stack_spacing": (\.stackSpacing, 0...80),
            "title_size": (\.titleSize, 8...96),
            "detail_size": (\.detailSize, 8...96),
            "symbol_size": (\.symbolSize, 8...96),
            "corner_radius": (\.cornerRadius, 0...100),
            "border_width": (\.borderWidth, 0...10)
        ]
        let otherKeys = ["shadow", "permanent_symbol", "temporary_symbol", "animation_duration", "light", "dark"]
        for key in table.keys.sorted() {
            if let (path, range) = numeric[key] {
                let number = table[key]?.double ?? table[key]?.int.map(Double.init)
                guard let number, number.isFinite, range.contains(number) else {
                    throw ConfigurationError(description: "appearance.\(key) must be a finite number in \(range)")
                }
                self[keyPath: path] = CGFloat(number)
            } else if !otherKeys.contains(key) {
                throw ConfigurationError(description: "unknown setting appearance.\(key)")
            }
        }
        if let value = table["shadow"] {
            guard let shadow = value.bool else {
                throw ConfigurationError(description: "appearance.shadow must be a boolean")
            }
            self.shadow = shadow
        }
        for (key, path) in [
            ("permanent_symbol", \AppearanceConfiguration.permanentSymbol),
            ("temporary_symbol", \AppearanceConfiguration.temporarySymbol)
        ] {
            if let value = table[key] {
                guard let symbol = value.string, !symbol.isEmpty,
                      NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil else {
                    throw ConfigurationError(description: "appearance.\(key) must be a valid SF Symbol name")
                }
                self[keyPath: path] = symbol
            }
        }
        if let value = table["animation_duration"] {
            let number = value.double ?? value.int.map(Double.init)
            guard let number, number.isFinite, (0...2).contains(number) else {
                throw ConfigurationError(description: "appearance.animation_duration must be a finite number in 0...2 seconds")
            }
            animationDuration = number
        }
        for (key, path) in [
            ("light", \AppearanceConfiguration.light),
            ("dark", \AppearanceConfiguration.dark)
        ] {
            guard let value = table[key] else { continue }
            guard let colors = value.table else {
                throw ConfigurationError(description: "appearance.\(key) must be a table")
            }
            let colorPaths: [String: WritableKeyPath<AppearanceColors, String?>] = [
                "background": \.background, "title": \.title, "detail": \.detail,
                "symbol": \.symbol, "border": \.border
            ]
            for colorKey in colors.keys.sorted() {
                guard let colorPath = colorPaths[colorKey] else {
                    throw ConfigurationError(description: "unknown setting appearance.\(key).\(colorKey)")
                }
                guard let hex = colors[colorKey]?.string,
                      hex.first == "#", hex.count == 7 || hex.count == 9,
                      hex.dropFirst().allSatisfy({ $0.isASCII && $0.isHexDigit }) else {
                    throw ConfigurationError(description: "appearance.\(key).\(colorKey) must be \"#RRGGBB\" or \"#RRGGBBAA\"")
                }
                self[keyPath: path][keyPath: colorPath] = hex
            }
        }
    }
}

struct LayoutConfiguration {
    var anchor = "top-right"
    var horizontalInset: Double = 18
    var verticalInset: Double = 18
}

struct NoticeConfiguration {
    var mode = "temporary"
    var duration: TimeInterval = 1
    var appearance = AppearanceConfiguration()
    var displayID: UInt32?
    var layout = LayoutConfiguration()

    static func load() throws -> NoticeConfiguration {
        let directory = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config")
        let url = directory.appendingPathComponent("macnotif.toml")
        let source: String
        do {
            source = try String(contentsOf: url, encoding: .utf8)
        } catch CocoaError.fileReadNoSuchFile {
            return NoticeConfiguration()
        } catch {
            throw ConfigurationError(description: "macnotif: \(url.path): \(error.localizedDescription)")
        }

        do {
            let table = try TOMLTable(string: source)
            var configuration = NoticeConfiguration()
            for key in table.keys.sorted()
                where key != "notice" && key != "appearance" && key != "display" && key != "layout" {
                throw ConfigurationError(description: "macnotif: \(url.path): unknown setting \(key)")
            }
            if let value = table["appearance"] {
                guard let appearance = value.table else {
                    throw ConfigurationError(description: "macnotif: \(url.path): appearance must be a table")
                }
                do {
                    configuration.appearance = try AppearanceConfiguration(table: appearance)
                } catch let error as ConfigurationError {
                    throw ConfigurationError(description: "macnotif: \(url.path): \(error)")
                }
            }
            if let value = table["notice"] {
                guard let notice = value.table else {
                    throw ConfigurationError(description: "macnotif: \(url.path): notice must be a table")
                }
                for key in notice.keys.sorted() where key != "mode" && key != "duration" {
                    throw ConfigurationError(description: "macnotif: \(url.path): unknown setting notice.\(key)")
                }
                if let value = notice["mode"] {
                    guard let mode = value.string, mode == "temporary" || mode == "permanent" else {
                        throw ConfigurationError(
                            description: "macnotif: \(url.path): notice.mode must be \"temporary\" or \"permanent\""
                        )
                    }
                    configuration.mode = mode
                }
                if let value = notice["duration"] {
                    let duration = value.double ?? value.int.map(TimeInterval.init)
                    guard let duration, duration.isFinite, duration > 0 else {
                        throw ConfigurationError(
                            description: "macnotif: \(url.path): notice.duration must be a finite positive number of seconds"
                        )
                    }
                    configuration.duration = duration
                }
            }
            if let value = table["display"] {
                guard let display = value.table else {
                    throw ConfigurationError(description: "macnotif: \(url.path): display must be a table")
                }
                for key in display.keys.sorted() where key != "id" {
                    throw ConfigurationError(description: "macnotif: \(url.path): unknown setting display.\(key)")
                }
                if let value = display["id"] {
                    guard let id = value.int, id > 0, id <= Int64(UInt32.max) else {
                        throw ConfigurationError(
                            description: "macnotif: \(url.path): display.id must be a positive 32-bit display ID"
                        )
                    }
                    configuration.displayID = UInt32(id)
                }
            }
            if let value = table["layout"] {
                guard let layout = value.table else {
                    throw ConfigurationError(description: "macnotif: \(url.path): layout must be a table")
                }
                for key in layout.keys.sorted()
                    where key != "anchor" && key != "horizontal_inset" && key != "vertical_inset" {
                    throw ConfigurationError(description: "macnotif: \(url.path): unknown setting layout.\(key)")
                }
                if let value = layout["anchor"] {
                    let allowedAnchors = ["top-left", "top-right", "bottom-left", "bottom-right"]
                    guard let anchor = value.string, allowedAnchors.contains(anchor) else {
                        throw ConfigurationError(
                            description: "macnotif: \(url.path): layout.anchor must be \"top-left\", \"top-right\", \"bottom-left\", or \"bottom-right\""
                        )
                    }
                    configuration.layout.anchor = anchor
                }
                for key in ["horizontal_inset", "vertical_inset"] {
                    if let value = layout[key] {
                        let inset = value.double ?? value.int.map(Double.init)
                        guard let inset, inset.isFinite, inset >= 0 else {
                            throw ConfigurationError(
                                description: "macnotif: \(url.path): layout.\(key) must be a finite non-negative number of points"
                            )
                        }
                        if key == "horizontal_inset" {
                            configuration.layout.horizontalInset = inset
                        } else {
                            configuration.layout.verticalInset = inset
                        }
                    }
                }
            }
            return configuration
        } catch let error as TOMLParseError {
            throw ConfigurationError(
                description: "macnotif: \(url.path):\(error.source.begin.line):\(error.source.begin.column): \(error.description)"
            )
        }
    }
}
