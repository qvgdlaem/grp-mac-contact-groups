import Foundation

struct DeletePreview: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let account: String
    let historyToken: Data
}

enum ContactFailure: LocalizedError {
    case unavailable, changed, wrongAccount, noHistory, permission, verification
    var errorDescription: String? {
        switch self {
        case .unavailable: return "This exact contact card is no longer available. Refresh and try again."
        case .changed: return "Contacts changed after the deletion preview. Refresh and review the card again before deleting."
        case .wrongAccount: return "The contact and group must belong to the same account."
        case .noHistory: return "Contacts could not provide a change token. Deletion has been stopped."
        case .permission: return "Allow this app to access Contacts in System Settings → Privacy & Security → Contacts."
        case .verification: return "The deletion could not be verified. Check Apple Contacts before retrying."
        }
    }
}

enum DeleteGuard {
    static func validate(_ preview: DeletePreview, exactID: String?, currentToken: Data?) throws {
        guard exactID == preview.id else { throw ContactFailure.unavailable }
        guard currentToken == preview.historyToken else { throw ContactFailure.changed }
    }
}
