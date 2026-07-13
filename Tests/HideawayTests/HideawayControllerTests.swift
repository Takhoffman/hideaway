import XCTest
@testable import Hideaway

final class HideawayControllerTests: XCTestCase {
    @MainActor
    func testProtectionsAreEnabledByDefault() {
        let defaults = makeDefaults()
        let controller = HideawayController(preferences: defaults)

        XCTAssertFalse(controller.isActive)
        XCTAssertTrue(controller.protectDesktop)
        XCTAssertTrue(controller.protectWidgets)
        XCTAssertTrue(controller.protectDock)
        XCTAssertTrue(controller.protectMenuBar)
        XCTAssertEqual(controller.enabledProtectionCount, 4)
    }

    @MainActor
    func testProtectionSelectionsPersist() {
        let defaults = makeDefaults()
        let controller = HideawayController(preferences: defaults)

        controller.protectDesktop = false
        controller.protectWidgets = false

        let restoredController = HideawayController(preferences: defaults)
        XCTAssertFalse(restoredController.protectDesktop)
        XCTAssertFalse(restoredController.protectWidgets)
        XCTAssertTrue(restoredController.protectDock)
        XCTAssertTrue(restoredController.protectMenuBar)
        XCTAssertEqual(restoredController.enabledProtectionCount, 2)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "HideawayTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
