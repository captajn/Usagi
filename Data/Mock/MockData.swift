import Foundation

enum MockData {
    static let sources: [MangaSource] = [
        MangaSource(id: "mock.local", title: "Usagi Demo", locale: "en", isEnabled: true, isNsfw: false),
        MangaSource(id: "mock.vi", title: "Demo Việt", locale: "vi", isEnabled: true, isNsfw: false),
        MangaSource(id: "mock.jp", title: "Demo 日本語", locale: "ja", isEnabled: false, isNsfw: false),
    ]

    /// Gradient placeholder URLs via picsum (stable seeds).
    private static func cover(_ seed: Int) -> String {
        "https://picsum.photos/seed/usagi\(seed)/400/600"
    }

    private static func page(_ seed: Int, index: Int) -> String {
        "https://picsum.photos/seed/usagi\(seed)p\(index)/800/1200"
    }

    static let manga: [Manga] = {
        let titles: [(String, [String], MangaPublicationState, [String], String)] = [
            ("Moonlit Usagi", ["月の兎", "Thỏ Ánh Trăng"], .ongoing, ["Yumemi", "Studio Usagi"], "A traveler follows silver footprints across night markets and forgotten temples."),
            ("Paper Lantern Road", ["紙灯りの道"], .finished, ["Aoi Hana"], "Four friends carry one lantern through a city that rewrites itself every dawn."),
            ("Salt & Circuit", [], .ongoing, ["Nova Rhee"], "Mecha pilots brew tea between sorties on a floating shipyard."),
            ("Harbor of Quiet Bells", ["静鈴の港"], .paused, ["Kenji M."], "A dockworker hears bells no one else can — each chime is a lost memory."),
            ("Violet Ink Protocol", [], .ongoing, ["L. Tran"], "Spy school where the only weapons are fountain pens and perfect alibis."),
            ("Garden Under Glass", ["ガラスの庭"], .finished, ["Mika Sora"], "Botanists trapped in a biosphere learn the plants are writing back."),
            ("Northbound Static", [], .abandoned, ["Relay Co."], "Truckers drive a radio frequency that shouldn't exist."),
            ("Chronicle of Soft Armor", ["柔鎧年代記"], .upcoming, ["Unknown"], "Knights wear silk that hardens only when they tell the truth."),
            ("Café 404", [], .ongoing, ["Bean & Bit"], "Every order at Café 404 arrives from a parallel timeline."),
            ("River That Climbs", ["登る川"], .ongoing, ["Hạ Vũ"], "A cartographer maps a river flowing uphill into the clouds."),
            ("Dust Opera", [], .finished, ["C. Vale"], "Opera singers weaponize resonance against a sand empire."),
            ("Secondhand Constellations", ["中古の星座"], .ongoing, ["Hoshi-ya"], "A thrift shop sells stars carefully removed from other skies."),
        ]

        return titles.enumerated().map { index, item in
            let id = Int64(index + 1)
            let chapters = makeChapters(mangaID: id, seed: index, count: 6 + (index % 5))
            let tags = makeTags(for: index)
            return Manga(
                id: id,
                title: item.0,
                altTitles: item.1,
                url: "/manga/\(id)",
                publicURL: "https://usagi.app/manga/\(id)",
                rating: Float(0.55 + Double(index % 5) * 0.08),
                isNSFW: false,
                contentRating: .safe,
                coverURL: cover(index + 1),
                largeCoverURL: cover(index + 100),
                state: item.2,
                authors: item.3,
                sourceID: index % 2 == 0 ? "mock.local" : "mock.vi",
                description: item.4,
                tags: tags,
                chapters: chapters
            )
        }
    }()

    private static func makeTags(for index: Int) -> [Tag] {
        let pool: [(String, String)] = [
            ("Adventure", "adventure"),
            ("Fantasy", "fantasy"),
            ("Sci-Fi", "sci-fi"),
            ("Slice of Life", "slice"),
            ("Mystery", "mystery"),
            ("Drama", "drama"),
            ("Comedy", "comedy"),
            ("Romance", "romance"),
        ]
        let a = pool[index % pool.count]
        let b = pool[(index + 3) % pool.count]
        return [
            Tag(id: Int64(index * 10 + 1), title: a.0, key: a.1, sourceID: "mock.local"),
            Tag(id: Int64(index * 10 + 2), title: b.0, key: b.1, sourceID: "mock.local"),
        ]
    }

    private static func makeChapters(mangaID: Int64, seed: Int, count: Int) -> [Chapter] {
        (1...count).map { n in
            let chapterID = mangaID * 1000 + Int64(n)
            let pages = (0..<8).map { p in
                Page(
                    id: chapterID * 100 + Int64(p),
                    index: p,
                    url: page(seed, index: n * 10 + p)
                )
            }
            return Chapter(
                id: chapterID,
                mangaID: mangaID,
                name: n == 1 ? "Prologue" : (n == count ? "Cliffhanger" : ""),
                number: Double(n),
                volume: n <= 4 ? 1 : 2,
                branch: nil,
                uploadDate: Calendar.current.date(byAdding: .day, value: -n * 3, to: Date()),
                scanlator: "Usagi Scan",
                url: "/manga/\(mangaID)/ch/\(n)",
                sourceID: "mock.local",
                pages: pages
            )
        }
    }
}
