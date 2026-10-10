import Foundation
import UserNotifications

let args = CommandLine.arguments
let content = UNMutableNotificationContent()
content.title = args.count > 1 ? args[1] : "dinky"
content.body = args.count > 2 ? args[2] : ""

let request = UNNotificationRequest(identifier: "dinky-mode", content: content, trigger: nil)
let center = UNUserNotificationCenter.current()
center.removeDeliveredNotifications(withIdentifiers: ["dinky-mode"])
center.add(request) { error in
    if let error {
        FileHandle.standardError.write(Data("DinkyNotify: \(error.localizedDescription)\n".utf8))
        exit(1)
    }
    exit(0)
}

DispatchQueue.main.asyncAfter(deadline: .now() + 3) { exit(2) }
dispatchMain()
