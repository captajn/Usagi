import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadSplitShell()
            } else {
                phoneTabShell
            }
        }
        .tint(UsagiTheme.accent)
        .sheet(isPresented: Binding(
            get: { dependencies.navigation.showDownloads },
            set: { dependencies.navigation.showDownloads = $0 }
        )) {
            NavigationStack { DownloadsView() }
                .environmentObject(dependencies)
        }
        .sheet(isPresented: Binding(
            get: { dependencies.navigation.showBookmarks },
            set: { dependencies.navigation.showBookmarks = $0 }
        )) {
            NavigationStack { BookmarksView() }
                .environmentObject(dependencies)
        }
    }

    private var phoneTabShell: some View {
        TabView(selection: Binding(
            get: { dependencies.navigation.selectedTab },
            set: { dependencies.navigation.selectedTab = $0 }
        )) {
            NavigationStack {
                ExploreView()
            }
            .tabItem { Label("Khám phá", systemImage: "safari") }
            .tag(AppTab.explore)

            NavigationStack {
                LibraryView()
            }
            .tabItem { Label("Thư viện", systemImage: "books.vertical") }
            .tag(AppTab.library)

            NavigationStack {
                HistoryView()
            }
            .tabItem { Label("Lịch sử", systemImage: "clock.arrow.circlepath") }
            .tag(AppTab.history)

            NavigationStack {
                TrackerView()
            }
            .tabItem { Label("Cập nhật", systemImage: "bell") }
            .tag(AppTab.tracker)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Cài đặt", systemImage: "gearshape") }
            .tag(AppTab.settings)
        }
    }
}

struct iPadSplitShell: View {
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { dependencies.navigation.selectedTab },
                set: { if let v = $0 { dependencies.navigation.selectedTab = v } }
            )) {
                Label("Khám phá", systemImage: "safari").tag(AppTab.explore)
                Label("Thư viện", systemImage: "books.vertical").tag(AppTab.library)
                Label("Lịch sử", systemImage: "clock.arrow.circlepath").tag(AppTab.history)
                Label("Cập nhật", systemImage: "bell").tag(AppTab.tracker)
                Label("Tìm kiếm", systemImage: "magnifyingglass").tag(AppTab.search)
                Label("Cài đặt", systemImage: "gearshape").tag(AppTab.settings)
            }
            .navigationTitle("Usagi")
            .accessibilityLabel("Điều hướng chính")
        } detail: {
            NavigationStack {
                switch dependencies.navigation.selectedTab {
                case .explore: ExploreView()
                case .library: LibraryView()
                case .history: HistoryView()
                case .tracker: TrackerView()
                case .search: SearchView()
                case .settings: SettingsView()
                }
            }
        }
    }
}

enum AppTab: String, Hashable, CaseIterable, Identifiable {
    case explore, library, history, tracker, search, settings
    var id: String { rawValue }
}

#Preview {
    RootTabView()
        .environmentObject(AppDependencies(preview: true))
}
