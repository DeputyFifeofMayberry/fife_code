//
//  TaskNotificationUITests.swift
//  OpenCodeClientUITests
//

import XCTest

final class TaskNotificationUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTaskNotificationCardExpandsAndOpensSubagentSession() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_TASK_NOTIFICATION_FIXTURE"]
        app.launch()

        let card = app.descendants(matching: .any)["task-notification-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 12), "task-notification-card should render")

        let marker = NSPredicate(format: "label CONTAINS 'failing tests remain'")
        let markerBefore = app.staticTexts.containing(marker).count
        let openButton = app.descendants(matching: .any)["task-notification-open-session"]
        XCTAssertFalse(openButton.exists, "The open-session button should not be exposed while collapsed")

        card.tap()

        let revealed = app.staticTexts.containing(marker).firstMatch.waitForExistence(timeout: 6)
            || app.staticTexts.containing(marker).count > markerBefore
        XCTAssertTrue(revealed, "Result markdown should be shown after expanding")
        if !openButton.waitForExistence(timeout: 2) {
            for _ in 0..<4 where !openButton.exists {
                app.swipeUp()
            }
        }
        XCTAssertTrue(openButton.waitForExistence(timeout: 4), "The open-session button should appear after expanding")

        openButton.tap()

        let childTitle = app.descendants(matching: .any).containing(
            NSPredicate(format: "label CONTAINS '(@general subagent)'")
        ).firstMatch
        XCTAssertTrue(childTitle.waitForExistence(timeout: 8), "Should switch to the subagent session after tapping open")
    }
}
