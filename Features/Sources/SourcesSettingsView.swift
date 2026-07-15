import SwiftUI

struct SourcesSettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var sources: [MangaSource] = []
    @State private var error: String?

    var body: some View {
        List {
            Section {
                Text("Bật các nguồn dùng cho Khám phá và Tìm kiếm. Trình phân tích thực sẽ plug vào cùng lớp repository.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Danh mục") {
                ForEach(sources) { source in
                    Toggle(isOn: Binding(
                        get: { source.isEnabled },
                        set: { enabled in
                            Task {
                                try? await dependencies.database.setSourceEnabled(source.id, enabled: enabled)
                                await reload()
                            }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.title)
                            Text("\(source.displayLocale) · \(source.id)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if let error {
                Section {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
            }
        }
        .navigationTitle("Nguồn")
        .task { await reload() }
    }

    private func reload() async {
        do {
            sources = try await dependencies.mangaRepository.sources()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
