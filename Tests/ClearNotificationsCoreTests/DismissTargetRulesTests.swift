import Testing
@testable import ClearNotificationsCore

@Test func usesNotificationCardCloseAction() {
    let node = AccessibilityNodeSnapshot(
        subrole: "AXNotificationCenterAlert",
        actions: ["AXShowMenu", "Name:Close"]
    )
    #expect(DismissTargetRules.preferredAction(for: node) == "Name:Close")
}

@Test func preservesSpecificCloseActionName() {
    let node = AccessibilityNodeSnapshot(
        subrole: "AXNotificationCenterAlert",
        actions: ["Name:Close Notification"]
    )
    #expect(DismissTargetRules.preferredAction(for: node) == "Name:Close Notification")
}

@Test func usesLegacyXmarkFallback() {
    let node = AccessibilityNodeSnapshot(
        role: "AXButton",
        identifier: "xmark",
        description: "Close",
        actions: ["AXPress"]
    )
    #expect(DismissTargetRules.preferredAction(for: node) == "AXPress")
}

@Test func rejectsUnrelatedButton() {
    let node = AccessibilityNodeSnapshot(
        role: "AXButton",
        identifier: "xmark",
        description: "Open",
        actions: ["AXPress"]
    )
    #expect(DismissTargetRules.preferredAction(for: node) == nil)
}

@Test func recognizesLocalizedClockIdentifier() {
    let node = AccessibilityNodeSnapshot(
        role: "AXMenuBarItem",
        identifier: "com.apple.controlcenter.clock"
    )
    #expect(DismissTargetRules.looksLikeClockControl(node))
}

@Test func rejectsNonMenuClockText() {
    let node = AccessibilityNodeSnapshot(
        role: "AXButton",
        description: "Clock"
    )
    #expect(!DismissTargetRules.looksLikeClockControl(node))
}
