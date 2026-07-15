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
                Text(String(localized: "Export favourites, history, bookmarks, tracker and settings as a versioned JSON backup. Designed to map toward Android Usagi backup schema over time."))
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
                        Label(String(localized: "Export backup"), systemImage: "square.and.arrow.up")
                    }
                }
                Button {
                    showImporter = true
                } label: {
                    Label(String(localized: "Import backup"), systemImage: "square.and.arrow.down")
                }
            }
            if let message {
                Section { Text(message).font(.footnote) }
            }
        }
        .navigationTitle(String(localized: "Backup"))
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
                    message = String(localized: "Backup imported.")
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
            message = String(localized: "Backup ready to share.")
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
