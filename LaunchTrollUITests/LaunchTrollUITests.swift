//
//  LaunchTrollUITests.swift
//  LaunchTrollUITests
//
//  Created by Leon Adomaitis on 26.05.26.
//

import XCTest

final class LaunchTrollUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testFakeDataLaunchDisplaysNativeShell() throws {
        let app = XCUIApplication()
        app.launchEnvironment["LAUNCHTROLL_FAKE_DATA"] = "1"
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["All Jobs"].exists)
        XCTAssertTrue(app.staticTexts["com.example.user-agent"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Refresh"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchEnvironment["LAUNCHTROLL_FAKE_DATA"] = "1"
            app.launch()
        }
    }
}
