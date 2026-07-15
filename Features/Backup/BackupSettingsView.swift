import SwiftUI
import UniformTypeIdentifiers

struct BackupSettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var message: String?
    @State private var busy = false

    var body: some View {
        List {
            Section {
                Text("Xuất yêu thích, lịch sử, đánh dấu, theo dõi và cài đặt dưới dạng file JSON sao lưu. Thiết kế để tương thích với schema sao lưu Android Usagi.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button {
                    Task { await exportBackup() }
                } label: {
                    if busy {
                        ProgressView()
                    } else {
                        Label("Xuất sao lưu", systemImage: "square.and.arrow.up")
                    }
                }
                Button {
                    showImporter = true
                } label: {
                    Label("Nhập sao lưu", systemImage: "square.and.arrow.down")
                }
            }
            if let message {
                Section { Text(message).font(.footnote) }
            }
        }
        .navigationTitle("Sao lưu")
        .sheet(item: Binding(
            get: { exportURL.map(IdentifiableURL.init) },
            set: { exportURL = $0?.url }
        )) { item in
            ShareSheet(items: [item.url])
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            Task {
                do {
                    guard let url = try result.get().first else { return }
                    try await dependencies.backupService.importData(from: url)
                    message = "Đã nhập sao lưu."
                } catch {
                    message = error.localizedDescription
                }
            }
        }
    }

    private func exportBackup() async {
        busy = true
        defer { busy = false }
        do {
            exportURL = try await dependencies.backupService.exportData()
            message = "Sao lưu sẵn sàng để chia sẻ."
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
