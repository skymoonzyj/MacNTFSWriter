@testable import MacNTFSWriterCore
import XCTest

final class ShellEscapingTests: XCTestCase {
    func testShellQuotingEscapesSingleQuotes() {
        XCTAssertEqual("Bob's Drive".shellQuoted, "'Bob'\"'\"'s Drive'")
    }

    func testAppleScriptStringEscapingEscapesQuotesAndBackslashes() {
        XCTAssertEqual("say \"hi\" \\ done".appleScriptStringEscaped, "say \\\"hi\\\" \\\\ done")
    }
}
