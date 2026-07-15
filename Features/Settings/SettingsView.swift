import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        SettingsScreen()
            .environmentObject(dependencies)
    }
}

private struct SettingsScreen: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var cacheCleared = false
    @State private var historyCleared = false

    var body: some View {
        List {
            Section(String(localized: "Browse")) {
                NavigationLink {
                    SearchView()
                } label: {
                    Label(String(localized: "Search"), systemImage: "magnifyingglass")
                }
                NavigationLink {
                    SuggestionsView()
                } label: {
                    Label(String(localized: "Suggestions"), systemImage: "sparkles")
                }
                Button {
                    dependencies.navigation.showDownloads = true
                } label: {
                    Label(String(localized: "Downloads & import"), systemImage: "arrow.down.circle")
                }
                Button {
                    dependencies.navigation.showBookmarks = true
                } label: {
                    Label(String(localized: "Bookmarks"), systemImage: "bookmark")
                }
            }

            Section(String(localized: "Appearance")) {
                Picker(String(localized: "Theme"), selection: $dependencies.settings.colorSchemePreference) {
                    ForEach(ColorSchemePreference.allCases) { pref in
                        Text(pref.displayName).tag(pref)
                    }
                }
            }

            Section(String(localized: "Reader")) {
                Picker(String(localized: "Reading mode"), selection: $dependencies.settings.readerMode) {
                    ForEach(ReaderMode.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                    }
                }
                Toggle(String(localized: "Keep screen on"), isOn: $dependencies.settings.keepScreenOn)
                Toggle(String(localized: "Incognito mode"), isOn: $dependencies.settings.incognitoMode)
                Toggle(String(localized: "Auto-scroll"), isOn: $dependencies.settings.autoScrollEnabled)
            }

            Section(String(localized: "Content")) {
                NavigationLink {
                    SourcesSettingsView()
                } label: {
                    Label(String(localized: "Sources"), systemImage: "globe")
                }
                Toggle(String(localized: "Data saver"), isOn: $dependencies.settings.dataSaver)
                Toggle(String(localized: "Show NSFW sources"), isOn: $dependencies.settings.showNSFW)
            }

            Section(String(localized: "Services")) {
                NavigationLink {
                    ScrobblingSettingsView()
                } label: {
                    Label(String(localized: "Scrobbling"), systemImage: "link")
                }
                NavigationLink {
                    SyncSettingsView()
                } label: {
                    Label(String(localized: "Sync"), systemImage: "arrow.triangle.2.circlepath")
                }
                NavigationLink {
                    BackupSettingsView()
                } label: {
                    Label(String(localized: "Backup"), systemImage: "externaldrive")
                }
            }

            Section(String(localized: "Security")) {
                Toggle(
                    String(localized: "App lock (\(dependencies.appLock.biometryLabel))"),
                    isOn: $dependencies.appLock.isEnabled
                )
            }

            Section(String(localized: "Storage")) {
                Button(String(localized: "Clear image cache")) {
                    Task {
                        await ImagePipeline.shared.clearCache()
                        try? await dependencies.database.clearCache()
                        cacheCleared = true
                    }
                }
                Button(String(localized: "Clear reading history"), role: .destructive) {
                    Task {
                        await dependencies.historyRepository.clear()
                        historyCleared = true
                    }
                }
            }

            Section(String(localized: "About")) {
                LabeledContent(String(localized: "App"), value: "Usagi iOS")
                LabeledContent(String(localized: "Version"), value: "0.1.0")
                LabeledContent(String(localized: "Platform"), value: "SwiftUI · pure Swift")
                NavigationLink {
                    PrivacyView()
                } label: {
                    Label(String(localized: "Privacy"), systemImage: "hand.raised")
                }
                Text(String(localized: "Free & open-source manga reader. Content comes from external sources / demos — Usagi does not host manga."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(String(localized: "Settings"))
        .alert(String(localized: "Cache cleared"), isPresented: $cacheCleared) {
            Button("OK", role: .cancel) {}
        }
        .alert(String(localized: "History cleared"), isPresented: $historyCleared) {
            Button("OK", role: .cancel) {}
        }
    }
}

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "Privacy"))
                    .font(.title2.weight(.bold))
                Text(String(localized: "Usagi does not include built-in manga content. Titles come from user-enabled sources, imports (CBZ), or demo fixtures."))
                Text(String(localized: "Reading history, favourites, bookmarks and downloads stay on your device unless you enable Sync or export a backup."))
                Text(String(localized: "Scrobbling and Sync only send data when you link an account. OAuth tokens are stored on-device."))
                Text(String(localized: "No analytics SDK is bundled in this open-source build."))
                Text(String(localized: "Photo library access is used only when you save a page from the reader."))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(String(localized: "Privacy"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
