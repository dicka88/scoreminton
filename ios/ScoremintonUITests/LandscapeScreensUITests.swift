import XCTest

/// Walks every screen in landscape and dumps screenshots (SCREENSHOT_DIR) for visual review.
final class LandscapeScreensUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        // long-ish real names to stress the layout
        app.launchEnvironment["UITEST_LAST_CONFIG"] = """
        {"format":"double","scoring":"rally","bestOf":3,"target":21,"deuce":true,"cap":30,"firstServer":"A",
         "teams":{"A":{"name":"","players":["Budi Santoso","Andi"]},"B":{"name":"","players":["Cici Wulandari","Dodi"]}}}
        """
        app.launch()
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("L-\(name).png"))
        }
    }

    private func tapTimes(_ el: XCUIElement, _ n: Int) {
        for _ in 0..<n { el.tap(); usleep(320_000) }
    }

    func testLandscapeWalkthrough() {
        sleep(1)
        snap("1-home")

        app.buttons["Atur sendiri & isi nama pemain"].tap()
        XCTAssertTrue(app.buttons["Mulai pertandingan"].waitForExistence(timeout: 3))
        sleep(1)
        snap("2-setup")
        app.buttons["Mulai pertandingan"].tap()

        let a = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Budi Santoso / Andi, skor'")).firstMatch
        let b = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Cici Wulandari / Dodi, skor'")).firstMatch
        XCTAssertTrue(a.waitForExistence(timeout: 3))
        sleep(1)
        snap("3-board-fresh")

        tapTimes(a, 5)
        tapTimes(b, 2)
        sleep(1) // let the "+1" badge fade
        snap("4-board-5-2")

        tapTimes(a, 4) // 9-2 → interval at 11
        tapTimes(a, 2)
        XCTAssertTrue(app.buttons["Lanjut main"].waitForExistence(timeout: 2))
        snap("5-interval")
        app.buttons["Lanjut main"].tap()

        tapTimes(a, 9) // 20-2
        sleep(3)
        snap("6-gamepoint")
        tapTimes(a, 1)
        XCTAssertTrue(app.buttons["Mulai game 2"].waitForExistence(timeout: 2))
        snap("7-gameover")
        app.buttons["Mulai game 2"].tap()

        sleep(1) // let the game-over card fade out
        app.buttons["Log"].tap()
        if !app.buttons["Tutup"].waitForExistence(timeout: 2) { app.buttons["Log"].tap() }
        XCTAssertTrue(app.buttons["Tutup"].waitForExistence(timeout: 3))
        sleep(1)
        snap("8-log")
        app.buttons["Tutup"].tap()
        XCTAssertTrue(app.buttons["Menu"].waitForExistence(timeout: 3))
        sleep(1)
        app.buttons["Menu"].tap()
        XCTAssertTrue(app.buttons["Tutup"].waitForExistence(timeout: 3))
        snap("9-menu")
        app.buttons["Tutup"].tap()
        sleep(1)

        tapTimes(a, 11)
        XCTAssertTrue(app.buttons["Lanjut main"].waitForExistence(timeout: 2))
        app.buttons["Lanjut main"].tap()
        tapTimes(a, 10)
        XCTAssertTrue(app.buttons["Simpan hasil"].waitForExistence(timeout: 2))
        sleep(2)
        snap("10-matchover")
        app.buttons["Simpan hasil"].tap()
        sleep(1)
        snap("11-history")
    }
}
