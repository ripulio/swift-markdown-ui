import XCTest

final class MarkdownRegressionUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testSpacesSurviveStyledInlinesAfterLineBreaks() {
        let app = launch("spacing")
        let text = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Beginning text")).firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 10))
        let label = text.label
        for expected in ["Link without", "Emphasis Text should", "Strong emphasis should", "Deleted text should", "inline code should"] {
            XCTAssertTrue(label.contains(expected), "Missing \(expected) in \(label)")
        }
    }

    func testDeeplyNestedListRemainsResponsive() {
        let app = launch("nestedLists")
        XCTAssertTrue(app.staticTexts["Level seven"].waitForExistence(timeout: 10))
        app.navigationBars.buttons["lab.update"].tap()
        XCTAssertTrue(app.staticTexts["Update 1"].waitForExistence(timeout: 3))
    }

    func testLongStyledParagraphDoesNotCrashAndCanUpdate() {
        let app = launch("longText")
        let text = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Line 1:")).firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 10))
        let last = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Line 1200: bold and link.")).firstMatch
        XCTAssertTrue(last.exists)
        app.navigationBars.buttons["lab.update"].tap()
        XCTAssertTrue(app.staticTexts["Update 1"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testLinkedImagesInsideTextRenderFitAndOpenTheirLink() {
        let app = launch("images")
        let image = app.buttons["Linked image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(image.frame.width, 321)
        XCTAssertGreaterThan(image.frame.height, 100)
        image.tap()
        XCTAssertTrue(app.staticTexts["Opened example.com"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.images["nested image"].exists)
    }

    func testDynamicTypeTracksNativeBodyText() {
        let app = launch("dynamicType")
        let markdown = app.staticTexts["Text size"]
        let reference = app.staticTexts["lab.referenceText"]
        XCTAssertTrue(markdown.waitForExistence(timeout: 5))
        let markdownHeight = markdown.frame.height
        let referenceHeight = reference.frame.height
        app.navigationBars.buttons["lab.largerText"].tap()
        let grew = NSPredicate { _, _ in markdown.frame.height > markdownHeight * 1.5 }
        expectation(for: grew, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(markdown.frame.height / markdownHeight,
                       reference.frame.height / referenceHeight, accuracy: 0.25)
    }

    func testStyledImagesInHeadingsAndTableCellsFitAndKeepLinks() {
        let app = launch("cellImages")
        XCTAssertTrue(app.images["heading icon"].waitForExistence(timeout: 5))
        let picture = app.buttons["cell picture"]
        XCTAssertTrue(picture.exists)
        XCTAssertLessThanOrEqual(picture.frame.width, 321)
        XCTAssertGreaterThan(picture.frame.height, 50)
        picture.tap()
        XCTAssertTrue(app.staticTexts["Opened example.com"].waitForExistence(timeout: 3))
    }

    private func launch(_ fixture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--fixture", fixture]
        app.launch()
        return app
    }
}
