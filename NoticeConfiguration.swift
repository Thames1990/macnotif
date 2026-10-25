import Foundation
import TOMLKit

struct ConfigurationError: Error, CustomStringConvertible {
    let description: String
}

struct LayoutConfiguration {
    var anchor = "top-right"
    var horizontalInset: Double = 18
    var verticalInset: Double = 18
}

struct NoticeConfiguration {
    var mode = "temporary"
    var duration: TimeInterval = 1
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
                where key != "notice" && key != "display" && key != "layout" {
                throw ConfigurationError(description: "macnotif: \(url.path): unknown setting \(key)")
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
