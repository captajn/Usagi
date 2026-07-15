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
            Section("Duyệt") {
                NavigationLink {
                    SearchView()
                } label: {
                    Label("Tìm kiếm", systemImage: "magnifyingglass")
                }
                NavigationLink {
                    SuggestionsView()
                } label: {
                    Label("Gợi ý", systemImage: "sparkles")
                }
                Button {
                    dependencies.navigation.showDownloads = true
                } label: {
                    Label("Tải xuống & nhập", systemImage: "arrow.down.circle")
                }
                Button {
                    dependencies.navigation.showBookmarks = true
                } label: {
                    Label("Đánh dấu", systemImage: "bookmark")
                }
            }

            Section("Giao diện") {
                Picker("Giao diện", selection: $dependencies.settings.colorSchemePreference) {
                    ForEach(ColorSchemePreference.allCases) { pref in
                        Text(pref.displayName).tag(pref)
                    }
                }
            }

            Section("Trình đọc") {
                Picker("Chế độ đọc", selection: $dependencies.settings.readerMode) {
                    ForEach(ReaderMode.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                    }
                }
                Toggle("Giữ màn hình sáng", isOn: $dependencies.settings.keepScreenOn)
                Toggle("Chế độ ẩn danh", isOn: $dependencies.settings.incognitoMode)
                Toggle("Tự động cuộn", isOn: $dependencies.settings.autoScrollEnabled)
            }

            Section("Nội dung") {
                NavigationLink {
                    SourceManageView()
                        .environmentObject(dependencies)
                } label: {
                    Label("Quản lý nguồn", systemImage: "gearshape.2")
                }
                NavigationLink {
                    SourcesSettingsView()
                } label: {
                    Label("Nguồn", systemImage: "globe")
                }
                Toggle("Tiết kiệm dữ liệu", isOn: $dependencies.settings.dataSaver)
                Toggle("Hiển thị nguồn NSFW", isOn: $dependencies.settings.showNSFW)
            }

            Section("Dịch vụ") {
                NavigationLink {
                    ScrobblingSettingsView()
                } label: {
                    Label("Scrobbling", systemImage: "link")
                }
                NavigationLink {
                    SyncSettingsView()
                } label: {
                    Label("Đồng bộ", systemImage: "arrow.triangle.2.circlepath")
                }
                NavigationLink {
                    BackupSettingsView()
                } label: {
                    Label("Sao lưu", systemImage: "externaldrive")
                }
                NavigationLink {
                    StatsView()
                } label: {
                    Label("Thống kê", systemImage: "chart.pie")
                }
            }

            Section("Bảo mật") {
                Toggle(
                    "Khóa ứng dụng (\(dependencies.appLock.biometryLabel))",
                    isOn: $dependencies.appLock.isEnabled
                )
            }

            Section("Lưu trữ") {
                Button("Xoá bộ nhớ đệm ảnh") {
                    Task {
                        await ImagePipeline.shared.clearCache()
                        try? await dependencies.database.clearCache()
                        cacheCleared = true
                    }
                }
                Button("Xoá lịch sử đọc", role: .destructive) {
                    Task {
                        await dependencies.historyRepository.clear()
                        historyCleared = true
                    }
                }
            }

            Section("Giới thiệu") {
                LabeledContent("Ứng dụng", value: "Usagi iOS")
                LabeledContent("Phiên bản", value: "0.1.0")
                LabeledContent("Nền tảng", value: "SwiftUI · pure Swift")
                NavigationLink {
                    PrivacyView()
                } label: {
                    Label("Quyền riêng tư", systemImage: "hand.raised")
                }
                Text("Ứng dụng đọc manga miễn phí mã nguồn mở. Nội dung đến từ nguồn bên ngoài / demo — Usagi không lưu trữ manga.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Cài đặt")
        .alert("Đã xoá bộ nhớ đệm", isPresented: $cacheCleared) {
            Button("OK", role: .cancel) {}
        }
        .alert("Đã xoá lịch sử", isPresented: $historyCleared) {
            Button("OK", role: .cancel) {}
        }
    }
}

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quyền riêng tư")
                    .font(.title2.weight(.bold))
                Text("Usagi không chứa nội dung manga có sẵn. Truyện đến từ nguồn người dùng bật, nhập (CBZ), hoặc demo.")
                Text("Lịch sử đọc, yêu thích, đánh dấu và tải xuống đều lưu trên thiết bị của bạn trừ khi bạn bật Đồng bộ hoặc xuất sao lưu.")
                Text("Scrobbling và Đồng bộ chỉ gửi dữ liệu khi bạn liên kết tài khoản. Token OAuth được lưu trên thiết bị.")
                Text("Không có SDK phân tích nào được nhúng trong bản mã nguồn mở này.")
                Text("Truy cập thư viện ảnh chỉ được sử dụng khi bạn lưu trang từ trình đọc.")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Quyền riêng tư")
        .navigationBarTitleDisplayMode(.inline)
    }
}
