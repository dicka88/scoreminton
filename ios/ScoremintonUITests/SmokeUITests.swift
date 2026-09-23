import XCTest

/// Drives a short doubles match end to end. Set SCREENSHOT_DIR to also dump PNGs.
final class SmokeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    func testQuickDoubleMatchScoresAndUndoes() {
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Double'")).firstMatch.tap()

        let teamA = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Pemain A1 / Pemain A2, skor'")).firstMatch
        let teamB = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Pemain B1 / Pemain B2, skor'")).firstMatch
        XCTAssertTrue(teamA.waitForExistence(timeout: 3))
        snap("board-portrait-start")

        for _ in 0..<3 { teamA.tap(); usleep(350_000) }
        teamB.tap(); usleep(350_000)
        XCTAssertEqual(teamA.label, "Pemain A1 / Pemain A2, skor 3")
        XCTAssertEqual(teamB.label, "Pemain B1 / Pemain B2, skor 1")
        snap("board-portrait-3-1")

        app.buttons["Undo"].tap()
        XCTAssertEqual(teamB.label, "Pemain B1 / Pemain B2, skor 0")

        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(1)
        snap("board-landscape")

        app.buttons["Log"].tap()
        XCTAssertTrue(app.navigationBars["Log rally · Game 1"].waitForExistence(timeout: 2))
        snap("log")
        app.buttons["Tutup"].tap()
        XCUIDevice.shared.orientation = .portrait
    }

    func testIntervalModalAppearsAt11() {
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Single'")).firstMatch.tap()
        let teamA = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tim A, skor'")).firstMatch
        XCTAssertTrue(teamA.waitForExistence(timeout: 3))
        for _ in 0..<11 { teamA.tap(); usleep(320_000) }
        XCTAssertTrue(app.buttons["Lanjut main"].waitForExistence(timeout: 2))
        snap("interval")
        app.buttons["Lanjut main"].tap()
        XCTAssertEqual(teamA.label, "Tim A, skor 11")
    }
}
