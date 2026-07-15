import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var period: StatsPeriod = .week
    @State private var records: [StatsRecord] = []
    @State private var showClearConfirm = false
    @State private var selectedManga: Manga?

    var body: some View {
        List {
            Section {
                Picker("Khoảng thời gian", selection: $period) {
                    ForEach(StatsPeriod.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            if records.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.pie")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Chưa có dữ liệu đọc")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                Section("Thời gian đọc") {
                    ForEach(records.prefix(8)) { record in
                        HStack {
                            Text(record.manga?.title ?? "Không rõ")
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Text(record.displayTime)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .background(
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(UsagiTheme.accent.opacity(0.15))
                                    .frame(width: geo.size.width * (record.percentage / 100))
                            }
                        )
                    }
                }

                Section("Theo truyện") {
                    ForEach(records) { record in
                        Button {
                            selectedManga = record.manga
                        } label: {
                            HStack {
                                if let manga = record.manga {
                                    MangaCoverView(urlString: manga.coverURL)
                                        .frame(width: 40, height: 40)
                                        .clipped()
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.quaternary)
                                        .frame(width: 40, height: 40)
                                }
                                VStack(alignment: .leading) {
                                    Text(record.manga?.title ?? "Truyện khác")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Text("\(record.pages) trang")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(record.displayTime)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Thống kê")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Xoá thống kê", systemImage: "trash", role: .destructive) {
                        showClearConfirm = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .confirmationDialog("Xoá toàn bộ thống kê đọc?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Xoá", role: .destructive) {
                Task { await dependencies.statsRepository.clear() }
                records = []
            }
        }
        .sheet(item: $selectedManga) { manga in
            NavigationStack {
                MangaStatsDetailView(manga: manga)
                    .environmentObject(dependencies)
            }
        }
        .task(id: period) {
            await loadStats()
        }
    }

    private func loadStats() async {
        records = await dependencies.statsRepository.stats(for: period)
    }
}
