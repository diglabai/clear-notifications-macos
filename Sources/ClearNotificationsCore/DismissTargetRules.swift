import Foundation

public struct AccessibilityNodeSnapshot: Equatable, Sendable {
    public let role: String
    public let subrole: String
    public let identifier: String
    public let description: String
    public let actions: [String]

    public init(
        role: String = "",
        subrole: String = "",
        identifier: String = "",
        description: String = "",
        actions: [String] = []
    ) {
        self.role = role
        self.subrole = subrole
        self.identifier = identifier
        self.description = description
        self.actions = actions
    }
}

public enum DismissTargetRules {
    public static func preferredAction(for node: AccessibilityNodeSnapshot) -> String? {
        if node.subrole == "AXNotificationCenterAlert",
           let closeAction = node.actions.first(where: { $0.hasPrefix("Name:Close") }) {
            return closeAction
        }

        if node.role == "AXButton",
           node.identifier == "xmark",
           node.description.localizedCaseInsensitiveContains("close") {
            return "AXPress"
        }

        return nil
    }

    public static func looksLikeClockControl(_ node: AccessibilityNodeSnapshot) -> Bool {
        guard node.role == "AXMenuBarItem" else { return false }

        let normalizedIdentifier = node.identifier.lowercased()
        if normalizedIdentifier.contains("clock") || normalizedIdentifier.contains("date") {
            return true
        }

        return node.description.localizedCaseInsensitiveCompare("Clock") == .orderedSame
    }
}
