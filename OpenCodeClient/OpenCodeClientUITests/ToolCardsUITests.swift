//
//  ToolCardsUITests.swift
//  OpenCodeClientUITests
//
//  UX test for the "tool card render redo": launches with a deterministic injected
//  assistant turn (UITEST_TOOL_CARDS_FIXTURE) and asserts the new rendering:
//  assistant fixture text, file-operation cards (2-column grid), and the merged
//  "N tool calls" disclosure row (expandable). Captures a screenshot for
//  visual QA. Anchored on accessibility identifiers per AGENTS.md (no TextField queries).
//

import XCTest

final class ToolCardsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        // A previous suite (Tier4Driver) may leave the simulator in landscape;
        // the layout assertions below assume the portrait 2-up grid.
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testToolCardsFixtureRendersFileCardsAndMergedToolCalls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_TOOL_CARDS_FIXTURE"]
        app.launch()

        // Assistant fixture content.
        let assistantText = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'Here are the changes I made'")
        ).firstMatch
        XCTAssertTrue(assistantText.waitForExistence(timeout: 12), "Fixture assistant text should be visible")

        let readCardPredicate = NSPredicate(format: "identifier BEGINSWITH 'toolcard.read.'")
        let writeCardPredicate = NSPredicate(format: "identifier BEGINSWITH 'toolcard.write.'")
        let readCards = app.descendants(matching: .any).matching(readCardPredicate)
        let writeCards = app.descendants(matching: .any).matching(writeCardPredicate)

        // The chat scroll view auto-scrolls to the bottom on launch, so the
        // file-card grid (top of the assistant turn) is un-materialized while
        // the merged disclosure row (bottom) is visible. Lazy cells only
        // materialize inside the viewport — assert each region while it is
        // on screen.

        // The merged "N tool calls" disclosure row.
        let toolCalls = app.descendants(matching: .any)["toolcard.toolcalls"]
        XCTAssertTrue(toolCalls.waitForExistence(timeout: 8), "The toolcard.toolcalls merged row should exist")

        // Capture the collapsed state before expanding.
        attachScreenshot(named: "oc_toolcards_collapsed")

        // Scroll up (swipe down) until the file-card grid enters the viewport.
        var scrolled = 0
        while !(readCards.firstMatch.exists || writeCards.firstMatch.exists) && scrolled < 5 {
            app.swipeDown()
            Thread.sleep(forTimeInterval: 1.0)
            scrolled += 1
        }
        XCTAssertTrue(readCards.firstMatch.waitForExistence(timeout: 4), "At least one toolcard.read.* file-read card should render")
        XCTAssertTrue(writeCards.firstMatch.waitForExistence(timeout: 4), "At least one toolcard.write.* file-write card should render")

        // Scroll back down to the merged row and expand it.
        while !toolCalls.firstMatch.exists && scrolled > 0 {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 1.0)
            scrolled -= 1
        }
        toolCalls.firstMatch.tap()

        let revealed = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'npm test'")
        ).firstMatch
        XCTAssertTrue(revealed.waitForExistence(timeout: 6), "Merged tool content (such as 'npm test') should appear after expanding toolcard.toolcalls")

        // Capture the expanded state — primary visual QA artifact.
        attachScreenshot(named: "oc_toolcards")
    }

    @MainActor
    func testExpandedToolDetailsShowErrorBodies() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_TOOL_CARDS_FIXTURE"]
        app.launch()

        let toolCalls = app.descendants(matching: .any)["toolcard.toolcalls"]
        XCTAssertTrue(toolCalls.waitForExistence(timeout: 8))
        if !toolCalls.isHittable {
            app.swipeUp()
        }
        toolCalls.tap()

        // The success card is the LAST detail row: tapping the error cards
        // first inserts their error bodies above it and pushes it further
        // below the fold while the chat transcript stays pinned to its bottom
        // anchor (defaultScrollAnchor(.bottom)), where scrolling cannot
        // recover it (runs 38985554002/38993355286/38995923388). Tap the
        // success card first, while it is still on screen; every later body
        // insert then pushes only already-tapped cards out of view, so the
        // remaining targets stay reachable.
        tapUniqueToolDetail("toolcard.detail.ap-todo-success", in: app)
        XCTAssertFalse(app.staticTexts["W02_TODO_SUCCESS_OUTPUT"].waitForExistence(timeout: 1))

        tapUniqueToolDetail("toolcard.detail.ap-image-error", in: app)
        let imageError = app.descendants(matching: .any)["toolcard.error.ap-image-error"]
        XCTAssertTrue(imageError.waitForExistence(timeout: 6))
        XCTAssertTrue(imageError.label.contains("W02_IMAGE_READ_ERROR"))

        tapUniqueToolDetail("toolcard.detail.ap-todo-error", in: app)
        let todoError = app.descendants(matching: .any)["toolcard.error.ap-todo-error"]
        XCTAssertTrue(todoError.waitForExistence(timeout: 6))
        XCTAssertTrue(todoError.label.contains("W02_TODOWRITE_ERROR"))
    }

    @MainActor
    private func tapUniqueToolDetail(_ identifier: String, in app: XCUIApplication) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 6))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier == %@", identifier)).count, 1)
        // Expanding a detail row grows the transcript above the later cards,
        // so the next card can land below the fold on short simulators (CI
        // runs a 402x874pt iPhone 16 Pro; runs 38985554002/38993355286 failed
        // here with the card at y=922). isHittable alone can miss that case,
        // so also require the card's center point to be inside the window,
        // and swipe up, bounded, until both hold.
        let window = app.frame
        func onScreen() -> Bool {
            button.isHittable && window.contains(CGPoint(x: button.frame.midX, y: button.frame.midY))
        }
        var swipes = 0
        while !onScreen() && swipes < 4 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(onScreen(), "\(identifier) should be on screen after scrolling (frame: \(button.frame), window: \(window), swipes: \(swipes))")
        button.tap()
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
