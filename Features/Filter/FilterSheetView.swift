import SwiftUI

struct FilterSheetView: View {
    @Binding var filter: MangaListFilter
    @Environment(\.dismiss) private var dismiss
    @State private var availableTags: [Tag] = []
    @State private var searchText = ""
    @State private var savedFilters: [SavedFilter] = []
    @State private var showSaveDialog = false
    @State private var filterName = ""

    private var filteredTags: [Tag] {
        if searchText.isEmpty { return availableTags }
        return availableTags.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tìm kiếm") {
                    TextField("Truyện...", text: $filter.query)
                    TextField("Tác giả...", text: $filter.author)
                }

                Section("Sắp xếp") {
                    ForEach(SortOrder.allCases) { order in
                        Button { filter.sortOrder = order } label: {
                            HStack {
                                Text(order.displayName)
                                Spacer()
                                if filter.sortOrder == order {
                                    Image(systemName: "checkmark").foregroundStyle(UsagiTheme.accent)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                Section("Thể loại") {
                    if !availableTags.isEmpty {
                        TextField("Tìm thể loại...", text: $searchText)
                        ForEach(filteredTags) { tag in
                            Button { toggleTag(tag) } label: {
                                HStack {
                                    Text(tag.title)
                                    Spacer()
                                    if filter.tags.contains(where: { $0.id == tag.id }) {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(UsagiTheme.accent)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    } else {
                        Text("Chưa có thể loại").foregroundStyle(.secondary)
                    }
                }

                Section("Nội dung") {
                    ratingToggle(rating: .safe)
                    ratingToggle(rating: .suggestive)
                    ratingToggle(rating: .adult)
                }

                Section("Trạng thái") {
                    stateToggle(state: .ongoing)
                    stateToggle(state: .finished)
                    stateToggle(state: .abandoned)
                    stateToggle(state: .paused)
                    stateToggle(state: .upcoming)
                }

                Section("Năm") {
                    Picker("Năm", selection: $filter.year) {
                        Text("Tất cả").tag(Int?.none)
                        ForEach((2000...2026).reversed(), id: \.self) { y in
                            Text(String(y)).tag(Int?.some(y))
                        }
                    }
                }

                if !savedFilters.isEmpty {
                    Section("Bộ lọc đã lưu") {
                        ForEach(savedFilters) { saved in
                            Button { filter = saved.filter } label: {
                                HStack { Text(saved.name); Spacer() }
                            }
                            .foregroundStyle(.primary)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Xoá", role: .destructive) {
                                    savedFilters.removeAll { $0.id == saved.id }
                                    savePresets()
                                }
                            }
                        }
                    }
                }

                Section {
                    Button("Lưu bộ lọc hiện tại") { showSaveDialog = true }
                    Button("Đặt lại bộ lọc", role: .destructive) { filter = .empty }
                }
            }
            .navigationTitle("Bộ lọc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Đặt lại") { filter = .empty } }
                ToolbarItem(placement: .confirmationAction) { Button("Xong") { dismiss() } }
            }
            .alert("Lưu bộ lọc", isPresented: $showSaveDialog) {
                TextField("Tên bộ lọc", text: $filterName)
                Button("Lưu") {
                    guard !filterName.isEmpty else { return }
                    savedFilters.append(SavedFilter(name: filterName, filter: filter))
                    savePresets()
                    filterName = ""
                }
                Button("Huỷ", role: .cancel) {}
            } message: {
                Text("Nhập tên cho bộ lọc này")
            }
        }
        .onAppear { loadPresets() }
    }

    private func toggleTag(_ tag: Tag) {
        if let i = filter.tags.firstIndex(where: { $0.id == tag.id }) {
            filter.tags.remove(at: i)
        } else {
            filter.tags.append(tag)
        }
    }

    @ViewBuilder
    private func ratingToggle(rating: ContentRating) -> some View {
        let isOn = filter.contentRating.contains(rating)
        Toggle(rating.displayName, isOn: Binding(
            get: { isOn },
            set: { newValue in
                if newValue { filter.contentRating.append(rating) }
                else { filter.contentRating.removeAll { $0 == rating } }
            }
        ))
    }

    @ViewBuilder
    private func stateToggle(state: MangaPublicationState) -> some View {
        let isOn = filter.states.contains(state)
        Toggle(state.displayName, isOn: Binding(
            get: { isOn },
            set: { newValue in
                if newValue { filter.states.append(state) }
                else { filter.states.removeAll { $0 == state } }
            }
        ))
    }

    private func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: "saved_filters"),
           let decoded = try? JSONDecoder().decode([SavedFilter].self, from: data) {
            savedFilters = decoded
        }
    }

    private func savePresets() {
        if let data = try? JSONEncoder().encode(savedFilters) {
            UserDefaults.standard.set(data, forKey: "saved_filters")
        }
    }
}
