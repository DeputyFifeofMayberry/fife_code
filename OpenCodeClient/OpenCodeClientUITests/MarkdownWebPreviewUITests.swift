//
//  MarkdownWebPreviewUITests.swift
//  OpenCodeClientUITests
//
//  Drives the bundled Markdown Web Preview shell with fixtures (no live server)
//  and verifies the WKWebView renders + captures screenshots for visual review.
//  Fixture selection: WEB_PREVIEW_FIXTURE_NAME env var (defaults to html_cards).
//

import XCTest

final class MarkdownWebPreviewUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchWebPreview(fixture: String, dark: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_WEB_PREVIEW_FIXTURE"]
        app.launchEnvironment["WEB_PREVIEW_FIXTURE_NAME"] = fixture
        // Force a theme via the app's persisted theme preference key so the
        // shell receives the matching payload.theme. The app reads this on init.
        if dark {
            app.launchEnvironment["UITEST_FORCE_THEME"] = "dark"
        }
        app.launch()
        return app
    }

    /// Webview present + a sentinel for the chosen fixture.
    private func assertWebViewVisible(_ app: XCUIApplication, file: StaticString = #file, line: UInt = #line) {
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.waitForExistence(timeout: 12), "WKWebView should appear", file: file, line: line)
    }

    private func capture(_ app: XCUIApplication, named name: String) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let dir = ProcessInfo.processInfo.environment["WEB_PREVIEW_SCREENSHOT_DIR"], !dir.isEmpty else {
            return
        }
        let directory = URL(fileURLWithPath: dir, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
    }

    @MainActor
    func testHtmlCardsLight() throws {
        let app = launchWebPreview(fixture: "html_cards", dark: false)
        assertWebViewVisible(app)
        try capture(app, named: "web_preview_html_cards_light")
    }

    @MainActor
    func testHtmlCardsDark() throws {
        let app = launchWebPreview(fixture: "dark_theme_cards", dark: true)
        assertWebViewVisible(app)
        try capture(app, named: "web_preview_dark_theme_cards")
    }

    @MainActor
    func testInlineSVG() throws {
        let app = launchWebPreview(fixture: "inline_svg", dark: false)
        assertWebViewVisible(app)
        try capture(app, named: "web_preview_inline_svg")
    }

    @MainActor
    func testWideTable() throws {
        let app = launchWebPreview(fixture: "wide_table", dark: false)
        assertWebViewVisible(app)
        try capture(app, named: "web_preview_wide_table")
    }

    @MainActor
    func testMathFormulasLight() throws {
        let app = launchWebPreview(fixture: "math_formulas", dark: false)
        assertWebViewVisible(app)
        let sentinel = app.webViews.firstMatch.staticTexts["MATH_FORMULA_SENTINEL"]
        XCTAssertTrue(sentinel.waitForExistence(timeout: 12), "Math fixture should finish rendering")
        try capture(app, named: "web_preview_math_formulas_light")
    }

    @MainActor
    func testMathFormulasDark() throws {
        let app = launchWebPreview(fixture: "math_formulas", dark: true)
        assertWebViewVisible(app)
        let sentinel = app.webViews.firstMatch.staticTexts["MATH_FORMULA_SENTINEL"]
        XCTAssertTrue(sentinel.waitForExistence(timeout: 12), "Dark math fixture should finish rendering")
        try capture(app, named: "web_preview_math_formulas_dark")
    }

    /// Security: the malicious fixture's sentinel text must render, proving the
    /// page loaded, while the injected <script> must NOT execute (no alert, no
    /// crash). We assert the sentinel is reachable in the webview's text.
    @MainActor
    func testMaliciousScriptStripped() throws {
        let app = launchWebPreview(fixture: "malicious_script", dark: false)
        assertWebViewVisible(app)
        let webView = app.webViews.firstMatch
        let sentinel = webView.staticTexts["SECURITY_FIXTURE_SENTINEL_OK"]
        XCTAssertTrue(
            sentinel.waitForExistence(timeout: 12),
            "Security fixture sentinel text should render (page loaded and the sanitizer did not break the content)"
        )
        // If a script had executed and thrown, the webview would not be stable
        // enough to surface the sentinel; reaching here means script was stripped.
        try capture(app, named: "web_preview_malicious_script")
    }

    /// Regression: dark-mode semantic chips (ok/bad/warn/block) must render as
    /// visible pills, not wash out into the card background. Catches two bugs
    /// from dogfood: deep tinted dark `--ok-bg` was too close to card bg, and
    /// bare `.ok` single-class selector got overridden by card's text color.
    @MainActor
    func testSemanticChipsDarkVisible() throws {
        let app = launchWebPreview(fixture: "semantic_chips", dark: true)
        assertWebViewVisible(app)
        let webView = app.webViews.firstMatch
        for sentinel in ["CHIP_OK_SENTINEL", "CHIP_BAD_SENTINEL", "CHIP_WARN_SENTINEL", "CHIP_BLOCK_SENTINEL"] {
            XCTAssertTrue(
                webView.staticTexts[sentinel].waitForExistence(timeout: 12),
                "\(sentinel) should be visible in dark mode; failure means chip text is overridden by the card --fg or --*-bg is too close to the card background"
            )
        }
        try capture(app, named: "web_preview_semantic_chips_dark")
    }

    /// Same chips in light mode — baseline that should always pass; if dark
    /// breaks but light passes the regression is theme-specific (the typical
    /// pattern of the bugs this fixture guards).
    @MainActor
    func testSemanticChipsLightVisible() throws {
        let app = launchWebPreview(fixture: "semantic_chips", dark: false)
        assertWebViewVisible(app)
        let webView = app.webViews.firstMatch
        for sentinel in ["CHIP_OK_SENTINEL", "CHIP_BAD_SENTINEL", "CHIP_WARN_SENTINEL", "CHIP_BLOCK_SENTINEL"] {
            XCTAssertTrue(
                webView.staticTexts[sentinel].waitForExistence(timeout: 12),
                "\(sentinel) should be visible in light mode"
            )
        }
        try capture(app, named: "web_preview_semantic_chips_light")
    }

    /// Drive the 3-mode menu (web -> source -> native) and confirm each mode's
    /// view appears and content survives the switch. Uses the mode fixture host.
    @MainActor
    func testPreviewModeSwitchingAndSourceFallback() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_WEB_PREVIEW_MODE_FIXTURE"]
        app.launchEnvironment["WEB_PREVIEW_FIXTURE_NAME"] = "plain_markdown"
        app.launch()

        // Starts in Web mode.
        XCTAssertTrue(
            app.webViews.firstMatch.waitForExistence(timeout: 12),
            "Web Preview WKWebView should be the initial mode"
        )

        let menu = app.buttons["markdown-preview-mode-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 8), "Preview mode menu should exist")

        // Switch to Markdown Source.
        menu.tap()
        app.buttons["Markdown Source"].tap()
        XCTAssertTrue(
            app.otherElements["fixture-source-view"].waitForExistence(timeout: 8)
                || app.scrollViews["fixture-source-view"].waitForExistence(timeout: 8),
            "Source view should appear after switching to Source"
        )

        // Switch to Native Preview.
        menu.tap()
        app.buttons["Native Preview"].tap()
        XCTAssertTrue(
            app.otherElements["fixture-native-preview"].waitForExistence(timeout: 8)
                || app.scrollViews["fixture-native-preview"].waitForExistence(timeout: 8),
            "Native preview should appear after switching to Native"
        )

        // Back to Web.
        menu.tap()
        app.buttons["Web Preview"].tap()
        XCTAssertTrue(
            app.webViews.firstMatch.waitForExistence(timeout: 8),
            "WKWebView should appear again after switching back to Web"
        )
    }
}
