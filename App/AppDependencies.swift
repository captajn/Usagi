import Foundation
import SwiftUI
import Combine

/// Composition root — mirrors Hilt modules on Android.
@MainActor
final class AppDependencies: ObservableObject {
    let mangaRepository: MangaRepository
    let libraryRepository: LibraryRepository
    let historyRepository: HistoryRepository
    let bookmarkRepository: BookmarkRepository
    let downloadRepository: DownloadRepository
    let trackerRepository: TrackerRepository
    let scrobblingService: ScrobblingService
    let backupService: BackupService
    let syncService: SyncService
    let cbzImporter: CBZImporter
    let statsRepository: StatsRepository
    var settings: UserDefaultsSettingsStore
    var appLock: AppLockService
    let navigation: NavigationStore
    let database: AppDatabase

    @Published private(set) var isReady = false

    private var cancellables = Set<AnyCancellable>()

    init(preview: Bool = false) {
        let db = AppDatabase.shared
        self.database = db
        let settingsStore = UserDefaultsSettingsStore()
        self.settings = settingsStore
        self.appLock = AppLockService()
        self.navigation = NavigationStore()

        let remote = MockMangaRepository()
        self.mangaRepository = CachingMangaRepository(remote: remote, db: db)
        self.libraryRepository = PersistentLibraryRepository(db: db)
        self.historyRepository = PersistentHistoryRepository(db: db)
        self.bookmarkRepository = PersistentBookmarkRepository(db: db)
        self.downloadRepository = DownloadManager(db: db)
        self.trackerRepository = PersistentTrackerRepository(db: db)
        self.scrobblingService = ScrobblingService(db: db)
        self.cbzImporter = CBZImporter(db: db)
        self.statsRepository = StatsRepository(db: db)
        self.syncService = SyncService(db: db)

        let settingsBox = settingsStore
        self.backupService = BackupService(db: db) {
            await MainActor.run { settingsBox.snapshot() }
        }

        settingsStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        appLock.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        navigation.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        if preview {
            isReady = true
        }
    }

    func bootstrap() async {
        do {
            try await database.prepare()
            isReady = true
            AppLog.info("App bootstrap complete")
        } catch {
            AppLog.error("Bootstrap failed", error: error)
            isReady = true
        }
    }
}
