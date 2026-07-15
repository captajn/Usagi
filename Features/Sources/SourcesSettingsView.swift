import SwiftUI

struct SourcesSettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var sources: [MangaSource] = []
    @State private var error: String?

    var body: some View {
        List {
            Section {
                Text(String(localized: "Enable sources used for Explore and Search. Real remote parsers will plug into the same repository layer."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section(String(localized: "Catalogue")) {
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
        .navigationTitle(String(localized: "Sources"))
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
