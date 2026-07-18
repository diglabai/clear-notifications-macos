import AppKit
import ApplicationServices
import ClearNotificationsCore
import Foundation

private enum ExitCode: Int32 {
    case success = 0
    case accessibilityPermissionRequired = 2
    case notificationCenterUnavailable = 3
    case clearFailed = 4
}

private struct Options {
    let dryRun: Bool
    let doNotOpenNotificationCenter: Bool
    let showVersion: Bool

    init(arguments: [String]) {
        dryRun = arguments.contains("--dry-run")
        doNotOpenNotificationCenter = arguments.contains("--no-open")
        showVersion = arguments.contains("--version")
    }
}

private final class AccessibilityElement {
    let raw: AXUIElement

    init(_ raw: AXUIElement) {
        self.raw = raw
    }

    func string(_ attribute: String) -> String {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(raw, attribute as CFString, &value) == .success else {
            return ""
        }
        return value as? String ?? ""
    }

    func children() -> [AccessibilityElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(raw, kAXChildrenAttribute as CFString, &value) == .success,
              let childElements = value as? [AXUIElement] else {
            return []
        }
        return childElements.map(AccessibilityElement.init)
    }

    func descendants(maxDepth: Int = 14, maxNodes: Int = 10_000) -> [AccessibilityElement] {
        var result: [AccessibilityElement] = []
        var visited = Set<CFHashCode>()

        func walk(_ element: AccessibilityElement, depth: Int) {
            guard depth <= maxDepth, result.count < maxNodes else { return }

            for child in element.children() {
                let identity = CFHash(child.raw)
                guard visited.insert(identity).inserted else { continue }
                result.append(child)
                walk(child, depth: depth + 1)
            }
        }

        visited.insert(CFHash(raw))
        walk(self, depth: 0)
        return result
    }

    func actionNames() -> [String] {
        var value: CFArray?
        guard AXUIElementCopyActionNames(raw, &value) == .success else { return [] }
        return value as? [String] ?? []
    }

    func snapshot() -> AccessibilityNodeSnapshot {
        AccessibilityNodeSnapshot(
            role: string(kAXRoleAttribute),
            subrole: string(kAXSubroleAttribute),
            identifier: string(kAXIdentifierAttribute),
            description: string(kAXDescriptionAttribute),
            actions: actionNames()
        )
    }

    @discardableResult
    func perform(_ action: String) -> Bool {
        AXUIElementPerformAction(raw, action as CFString) == .success
    }
}

private final class NotificationClearer {
    private let notificationCenterBundleID = "com.apple.notificationcenterui"
    private let controlCenterBundleID = "com.apple.controlcenter"
    private let maximumDismissals = 500

    private func applicationElement(bundleID: String) -> AccessibilityElement? {
        guard let application = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            return nil
        }
        return AccessibilityElement(AXUIElementCreateApplication(application.processIdentifier))
    }

    private func notificationCenterElement() -> AccessibilityElement? {
        if let current = applicationElement(bundleID: notificationCenterBundleID) {
            return current
        }

        let candidates = NSWorkspace.shared.runningApplications.filter {
            ($0.localizedName ?? "") == "Notification Center"
        }
        guard let application = candidates.first else { return nil }
        return AccessibilityElement(AXUIElementCreateApplication(application.processIdentifier))
    }

    private struct DismissTarget {
        let element: AccessibilityElement
        let action: String
    }

    private func dismissTargets() -> [DismissTarget] {
        guard let notificationCenter = notificationCenterElement() else { return [] }
        let elements = notificationCenter.descendants()

        let notificationCards = elements.compactMap { element -> DismissTarget? in
            guard let action = DismissTargetRules.preferredAction(for: element.snapshot()),
                  action.hasPrefix("Name:Close") else {
                return nil
            }
            return DismissTarget(element: element, action: action)
        }

        if !notificationCards.isEmpty {
            return notificationCards
        }

        return elements.compactMap { element -> DismissTarget? in
            guard let action = DismissTargetRules.preferredAction(for: element.snapshot()) else {
                return nil
            }
            return DismissTarget(element: element, action: action)
        }
    }

    private func toggleNotificationCenter() -> Bool {
        guard let controlCenter = applicationElement(bundleID: controlCenterBundleID) else { return false }
        guard let clock = controlCenter.descendants(maxDepth: 8).first(where: {
            DismissTargetRules.looksLikeClockControl($0.snapshot())
        }) else {
            return false
        }
        return clock.perform(kAXPressAction)
    }

    private func waitForDismissTarget(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if !dismissTargets().isEmpty { return true }
            Thread.sleep(forTimeInterval: 0.08)
        } while Date() < deadline
        return false
    }

    func visibleDismissalCount() -> Int {
        dismissTargets().count
    }

    func clearAll(openIfNeeded: Bool) -> (dismissed: Int, openedByHelper: Bool, failed: Bool) {
        var openedByHelper = false

        if dismissTargets().isEmpty, openIfNeeded {
            openedByHelper = toggleNotificationCenter()
            if openedByHelper {
                _ = waitForDismissTarget(timeout: 3.0)
            }
        }

        var dismissed = 0
        var consecutiveFailures = 0

        while dismissed < maximumDismissals {
            guard let target = dismissTargets().first else { break }
            if target.element.perform(target.action) {
                dismissed += 1
                consecutiveFailures = 0
                Thread.sleep(forTimeInterval: 0.18)
            } else {
                consecutiveFailures += 1
                if consecutiveFailures >= 3 { break }
                Thread.sleep(forTimeInterval: 0.1)
            }
        }

        let failed = !dismissTargets().isEmpty

        if openedByHelper {
            _ = toggleNotificationCenter()
        }

        return (dismissed, openedByHelper, failed)
    }
}

@MainActor
private func requestAccessibilityPermission() -> Bool {
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = "Allow Clear Notifications to control Notification Center"
    alert.informativeText = "Enable Clear Notifications under Privacy & Security > Accessibility. The app waits for approval, then clears notifications automatically."
    alert.addButton(withTitle: "Open Accessibility Settings")
    alert.addButton(withTitle: "Cancel")

    NSApp.activate(ignoringOtherApps: true)
    guard alert.runModal() == .alertFirstButtonReturn,
          let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
        return false
    }

    NSWorkspace.shared.open(url)
    let deadline = Date().addingTimeInterval(180)
    while Date() < deadline {
        if AXIsProcessTrusted() { return true }
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    }
    return false
}

@MainActor
private func showErrorAlert(_ message: String) {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "Could not clear notifications"
    alert.informativeText = message
    alert.addButton(withTitle: "OK")
    NSApp.activate(ignoringOtherApps: true)
    alert.runModal()
}

@main
private enum ClearNotificationsApp {
    @MainActor
    static func main() {
        let options = Options(arguments: CommandLine.arguments)

        if options.showVersion {
            print("Clear Notifications 0.1.1")
            exit(ExitCode.success.rawValue)
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        if options.dryRun {
            guard AXIsProcessTrusted() else {
                fputs("accessibility_permission=false\n", stderr)
                exit(ExitCode.accessibilityPermissionRequired.rawValue)
            }
            let count = NotificationClearer().visibleDismissalCount()
            print("accessibility_permission=true")
            print("visible_dismiss_targets=\(count)")
            exit(ExitCode.success.rawValue)
        }

        // This is the stable Accessibility API key. Using the literal avoids
        // importing a mutable Objective-C global into Swift 6 checking.
        let promptOptions = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(promptOptions) {
            guard requestAccessibilityPermission(), AXIsProcessTrusted() else {
                exit(ExitCode.accessibilityPermissionRequired.rawValue)
            }
        }

        let result = NotificationClearer().clearAll(openIfNeeded: !options.doNotOpenNotificationCenter)

        if result.failed {
            showErrorAlert("macOS still reports dismissible controls. Try again; if the problem continues, remove and re-enable Accessibility permission for this app.")
            exit(ExitCode.clearFailed.rawValue)
        }

        exit(ExitCode.success.rawValue)
    }
}
