import Foundation

// Standalone checks: this machine has Command Line Tools, without XCTest.
// Compiled together with DeleteGuard.swift; never imports Contacts or opens the UI.
@main
struct DeleteGuardTests {
    private let before = Data([1])
    private let afterMembershipSave = Data([2])

    func testMembershipSaveThenFreshPreviewCanProceed() throws {
        let preview = DeletePreview(id: "account-card", name: "Sample", account: "Test", historyToken: afterMembershipSave)
        try DeleteGuard.validate(preview, exactID: "account-card", currentToken: afterMembershipSave)
    }

    func testPreviewFromBeforeMembershipSaveIsRejected() {
        let preview = DeletePreview(id: "account-card", name: "Sample", account: "Test", historyToken: before)
        expectFailure { try DeleteGuard.validate(preview, exactID: "account-card", currentToken: afterMembershipSave) }
    }

    func testMissingOrDifferentLinkedCardCannotBeDeleted() {
        let preview = DeletePreview(id: "account-card", name: "Sample", account: "Test", historyToken: before)
        expectFailure { try DeleteGuard.validate(preview, exactID: nil, currentToken: before) }
        expectFailure { try DeleteGuard.validate(preview, exactID: "other-linked-card", currentToken: before) }
    }

    func testMissingHistoryTokenIsRejected() {
        let preview = DeletePreview(id: "account-card", name: "Sample", account: "Test", historyToken: before)
        expectFailure { try DeleteGuard.validate(preview, exactID: "account-card", currentToken: nil) }
    }

    private func expectFailure(_ action: () throws -> Void) {
        do { try action() }
        catch { return }
        fatalError("Expected deletion guard to reject the operation")
    }

    static func main() throws {
        let tests = Self()
        try tests.testMembershipSaveThenFreshPreviewCanProceed()
        tests.testPreviewFromBeforeMembershipSaveIsRejected()
        tests.testMissingOrDifferentLinkedCardCannotBeDeleted()
        tests.testMissingHistoryTokenIsRejected()
        print("Passed 4 deletion-guard checks (synthetic data; no Contacts access).")
    }
}
