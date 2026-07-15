import Foundation

actor BackupService {
    private let db: AppDatabase
    private let settings: @Sendable () async -> BackupSettingsSnapshot

    init(db: AppDatabase = .shared, settings: @escaping @Sendable () async -> BackupSettingsSnapshot) {
        self.db = db
        self.settings = settings
    }

    func exportData(appVersion: String = "0.1.0") async throws -> URL {
        let snapshot = await settings()
        let payload = await db.exportPayload(settings: snapshot, appVersion: appVersion)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)

        let dir = FileManager.default.temporaryDirectory
        let name = "usagi-backup-\(Int(Date().timeIntervalSince1970)).json"
        let url = dir.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    func importData(from url: URL) async throws {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(AppBackupPayload.self, from: data)
        try await db.importPayload(payload)
    }
}

actor SyncService {
    private let db: AppDatabase
    private let client: HTTPClient

    init(db: AppDatabase = .shared, client: HTTPClient = HTTPClient()) {
        self.db = db
        self.client = client
    }

    func account() async -> SyncAccount {
        await db.currentSyncAccount()
    }

    func login(email: String, password: String, serverURL: String) async throws -> SyncAccount {
        // Stub: real server handshake would go here.
        _ = password
        guard let url = URL(string: serverURL), url.scheme != nil else {
            throw SyncError.invalidServer
        }
        var account = await db.currentSyncAccount()
        account.email = email
        account.serverURL = serverURL
        account.isLoggedIn = true
        account.lastSyncAt = Date()
        account.deviceName = "iOS"
        try await db.saveSyncAccount(account)
        AppLog.info("Sync login stub for \(email)")
        return account
    }

    func logout() async throws {
        var account = await db.currentSyncAccount()
        account.isLoggedIn = false
        account.email = nil
        account.lastSyncAt = nil
        try await db.saveSyncAccount(account)
    }

    func syncNow() async throws -> SyncAccount {
        var account = await db.currentSyncAccount()
        guard account.isLoggedIn else { throw SyncError.notLoggedIn }
        // Stub push/pull
        try await Task.sleep(nanoseconds: 400_000_000)
        account.lastSyncAt = Date()
        try await db.saveSyncAccount(account)
        return account
    }
}

enum SyncError: LocalizedError {
    case invalidServer
    case notLoggedIn
    case network

    var errorDescription: String? {
        switch self {
        case .invalidServer: return String(localized: "Invalid sync server URL")
        case .notLoggedIn: return String(localized: "Not logged in")
        case .network: return String(localized: "Sync network error")
        }
    }
}
