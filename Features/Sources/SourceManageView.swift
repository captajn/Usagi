import SwiftUI

struct SourceManageView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var sourceRepo = SourceRepository()
    @State private var showAddSheet = false

    var body: some View {
        List {
            Section {
                Text("Quản lý nguồn manga. Bật/tắt nguồn có sẵn hoặc thêm nguồn tùy chỉnh từ URL API.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Nguồn có sẵn") {
                ForEach(sourceRepo.sources.filter(\.isBuiltIn)) { source in
                    SourceRow(source: source) { enabled in
                        sourceRepo.toggleSource(source.id, enabled: enabled)
                    }
                }
            }

            if !sourceRepo.sources.filter({ !$0.isBuiltIn }).isEmpty {
                Section("Nguồn tùy chỉnh") {
                    ForEach(sourceRepo.sources.filter({ !$0.isBuiltIn })) { source in
                        SourceRow(source: source) { enabled in
                            sourceRepo.toggleSource(source.id, enabled: enabled)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Xoá", role: .destructive) {
                                sourceRepo.removeCustomSource(source.id)
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Thêm nguồn tùy chỉnh", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Quản lý nguồn")
        .sheet(isPresented: $showAddSheet) {
            AddSourceSheet(sourceRepo: sourceRepo)
        }
    }
}

private struct SourceRow: View {
    let source: SourceRepository.ManagedSource
    let onToggle: (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(
            get: { source.isEnabled },
            set: { onToggle($0) }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(source.name)
                    if source.isBuiltIn {
                        Text("có sẵn")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                }
                Text("\(source.displayLocale) · \(source.id)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if !source.isBuiltIn {
                    Text(source.apiBaseURL)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }
}

struct AddSourceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var sourceRepo: SourceRepository
    @State private var name = ""
    @State private var locale = "EN"
    @State private var apiURL = ""
    @State private var errorMessage: String?
    @State private var isValidating = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin nguồn") {
                    TextField("Tên nguồn", text: $name)
                    Picker("Ngôn ngữ", selection: $locale) {
                        Text("EN").tag("EN")
                        Text("VI").tag("VI")
                        Text("JA").tag("JA")
                        Text("ZH").tag("ZH")
                        Text("KO").tag("KO")
                    }
                }

                Section("API Endpoint") {
                    TextField("https://api.example.com", text: $apiURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    Text("URL cơ sở của API nguồn manga. Phải trả về JSON theo định dạng chuẩn.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        validateAndAdd()
                    } label: {
                        if isValidating {
                            ProgressView()
                        } else {
                            Text("Thêm nguồn")
                        }
                    }
                    .disabled(name.isEmpty || apiURL.isEmpty || isValidating)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Thêm nguồn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
            }
        }
    }

    private func validateAndAdd() {
        guard let url = URL(string: apiURL), url.scheme == "https" else {
            errorMessage = "URL phải bắt đầu bằng https://"
            return
        }
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Nhập tên nguồn"
            return
        }

        isValidating = true
        errorMessage = nil

        Task {
            // Try to reach the API
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.setValue("Usagi/0.1.0", forHTTPHeaderField: "User-Agent")

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, (200...499).contains(http.statusCode) {
                    // Accept any response (including 4xx — means server is reachable)
                    let success = sourceRepo.addCustomSource(
                        name: name.trimmingCharacters(in: .whitespaces),
                        locale: locale,
                        apiBaseURL: apiURL.trimmingCharacters(in: .whitespaces)
                    )
                    if success {
                        await MainActor.run { dismiss() }
                    } else {
                        await MainActor.run {
                            errorMessage = "Nguồn với tên này đã tồn tại"
                            isValidating = false
                        }
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "Không thể kết nối đến server"
                        isValidating = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Lỗi: \(error.localizedDescription)"
                    isValidating = false
                }
            }
        }
    }
}
