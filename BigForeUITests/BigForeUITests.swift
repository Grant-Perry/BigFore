//
//  BigForeUITests.swift
//  BigForeUITests
//
//  Created by Gp. on 5/12/26.
//

import XCTest

final class BigForeUITests: XCTestCase {

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
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    /// Launches the app, selects the **Rounds** tab, and asserts the rounds list root is on-screen.
    /// Uses `-BigForeUITestInMemory` so the run does not depend on the simulator’s persisted SwiftData store
    /// (isolates migration / large-library issues from tab switching).
    @MainActor
    func testSelectRoundsTabShowsRoundsScreen() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-BigForeUITestInMemory"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "Tab bar should appear after launch")

        let roundsTab = app.descendants(matching: .any).matching(identifier: "bigfore.tab.rounds").firstMatch
        if roundsTab.waitForExistence(timeout: 5) {
            roundsTab.tap()
        } else {
            let fallback = tabBar.buttons["Rounds"]
            XCTAssertTrue(fallback.waitForExistence(timeout: 5), "Rounds tab should be tappable by label or identifier")
            fallback.tap()
        }

        let roundsList = app.descendants(matching: .any).matching(identifier: "bigfore.rounds.list").firstMatch
        XCTAssertTrue(roundsList.waitForExistence(timeout: 25), "Rounds list root should appear (no main-thread wedging during tab switch)")

        let roundsNav = app.navigationBars["Rounds"]
        XCTAssertTrue(roundsNav.waitForExistence(timeout: 5), "Rounds navigation title should be visible")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
