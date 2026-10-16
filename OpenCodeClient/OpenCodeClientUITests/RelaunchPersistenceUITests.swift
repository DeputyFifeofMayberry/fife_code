//
//  RelaunchPersistenceUITests.swift
//  OpenCodeClientUITests
//
//  Relaunch-survival journey (documented coverage gap in docs/TESTING.md):
//  key user state must survive a full terminate + relaunch on the simulator.
//  The journey covers the selected server (host) profile and the saved host
//  list, which the app persists to UserDefaults (hostProfiles.v1 /
//  currentHostProfileID.v1).
//
//  The app is launched plainly (no fixture launch argument) so it uses its
//  real persistence path; fixture suites intentionally isolate defaults per
//  launch, which would erase the state this test needs across relaunches.
//  The sentinel host points at the unreachable offline URL convention
//  (http://127.0.0.1:9), so the journey runs fully offline. Anchors are the
//  existing accessibility identifiers per AGENTS.md (settings-current-host,
//  hosts-add-host, host-name, host-server-url, host-save, hosts-current-card).
//

import XCTest

final class RelaunchPersistenceUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testSelectedServerProfileSurvivesRelaunch() throws {
        // Unique per run so repeated CI sweeps cannot collide with state left
        // by an earlier run on the same simulator.
        let sentinel = "Relaunch Sentinel \(UUID().uuidString.prefix(8))"
        let unreachableURL = "http://127.0.0.1:9"

        let app = XCUIApplication()
        app.launch()

        addSentinelHost(in: app, name: sentinel, serverURL: unreachableURL)

        // Pre-relaunch control: saving dismissed the editor back onto the
        // hosts list, where the sentinel must already be the current host.
        XCTAssertTrue(
            app.descendants(matching: .any)["hosts-current-card"].waitForExistence(timeout: 8),
            "current host card should be present before the relaunch"
        )
        XCTAssertTrue(
            app.staticTexts[sentinel].waitForExistence(timeout: 8),
            "sentinel profile should be current (headline in the current host card) before the relaunch"
        )

        app.terminate()
        app.launch()

        // The selected server profile must survive the relaunch: Settings shows
        // the sentinel host as current again.
        Tier4DriverSupport.openSettings(in: app)
        XCTAssertTrue(
            app.staticTexts[sentinel].waitForExistence(timeout: 12),
            "selected server profile should still be current after terminate + relaunch"
        )

        // The saved hosts list itself must also survive the relaunch.
        openHostsList(in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["hosts-current-card"].waitForExistence(timeout: 8),
            "current host card should be present after the relaunch"
        )
        XCTAssertTrue(
            app.staticTexts[sentinel].waitForExistence(timeout: 8),
            "saved host profile row should still exist after terminate + relaunch"
        )
        attachScreenshot(named: "oc_relaunch_persistence")
    }

    // MARK: - Helpers

    /// Adds a host profile through the host editor UI. Saving a new profile
    /// makes it the current host (makeCurrent), which is what persists the
    /// selection across relaunches.
    @MainActor
    private func addSentinelHost(in app: XCUIApplication, name: String, serverURL: String) {
        Tier4DriverSupport.openSettings(in: app)

        let currentHost = app.descendants(matching: .any)["settings-current-host"]
        XCTAssertTrue(currentHost.waitForExistence(timeout: 15), "settings-current-host should exist")
        currentHost.tap()

        let addHost = app.descendants(matching: .any)["hosts-add-host"]
        XCTAssertTrue(addHost.waitForExistence(timeout: 15), "hosts-add-host should exist")
        addHost.tap()

        let nameField = app.descendants(matching: .any)["host-name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10), "host-name should exist")
        Tier4DriverSupport.replaceText(in: nameField, with: name)

        let urlField = app.descendants(matching: .any)["host-server-url"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 10), "host-server-url should exist")
        Tier4DriverSupport.replaceText(in: urlField, with: serverURL)

        let save = app.buttons["host-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "host-save Button should exist")
        XCTAssertTrue(save.isEnabled, "host-save should be enabled after required fields")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10), "host editor should dismiss after saving")
    }

    /// Navigates Settings → the saved hosts list (the settings-current-host
    /// NavigationLink leads there).
    @MainActor
    private func openHostsList(in app: XCUIApplication) {
        let currentHost = app.descendants(matching: .any)["settings-current-host"]
        XCTAssertTrue(currentHost.waitForExistence(timeout: 15), "settings-current-host should exist")
        currentHost.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["hosts-add-host"].waitForExistence(timeout: 15),
            "hosts list should open from settings-current-host"
        )
    }

    private func attachScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
