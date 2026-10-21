import Foundation

actor RetryLoader {
    private var attempts = 0
    func load() throws -> Snapshot {
        attempts += 1
        if attempts == 1 { throw ContactFailure.permission }
        return .demo
    }
}

@main
@MainActor
struct ConnectionChecks {
    static func require(_ value: @autoclosure () -> Bool, _ message: String) {
        if !value() { fatalError(message) }
    }
    static func main() async {
        let loader = RetryLoader()
        let model = Model(connectionLoader: { try await loader.load() })
        await model.establishConnection()
        require(!model.live, "A failed connection must not report live access")
        require(!model.busy && !model.connecting, "Connection failure must re-enable Connect")
        require(model.connectionError != nil, "Connection failure must remain visible beside Retry")
        require(model.error == nil, "Connection failures must not show save/delete error messages")
        require(model.snapshot.people == Snapshot.demo.people, "Failed connection must preserve sample data")
        await model.establishConnection()
        require(model.live, "Connecting again after enabling permission must succeed")
        require(model.connectionError == nil, "Successful retry must clear the old connection error")
        require(!model.busy && !model.connecting, "Successful connection must release the busy state")
        let failedLoad = Model(connectionLoader: {
            throw NSError(domain: "SyntheticContactStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not load accounts"])
        })
        await failedLoad.establishConnection()
        require(failedLoad.connectionError == "Could not load accounts", "Keep the actual fetch error available for diagnosis")
        require(!failedLoad.live && !failedLoad.busy, "Loading failure must remain retryable")
        print("Passed connection denial, visible error, retry recovery and loading failure checks (fake loader; no personal Contacts access).")
    }
}
