import Foundation
import TOMLKit

struct ConfigurationError: Error, CustomStringConvertible {
    let description: String
}

struct NoticeConfiguration {
    var mode = "temporary"
    var duration: TimeInterval = 1

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
            for key in table.keys.sorted() where key != "notice" {
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
            return configuration
        } catch let error as TOMLParseError {
            throw ConfigurationError(
                description: "macnotif: \(url.path):\(error.source.begin.line):\(error.source.begin.column): \(error.description)"
            )
        }
    }
}
