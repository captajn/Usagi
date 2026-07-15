# Usagi iOS — SwiftUI thuần

Implement đầy đủ roadmap trong [`../plan.md`](../plan.md) (P0–P7), source **nằm thẳng trong `ios/`**.

```
ios/
├── UsagiApp.swift
├── App/                 # DI, shell, tabs / iPad split
├── Core/                # logging, deep links
├── Domain/              # models + repository protocols
├── Data/
│   ├── Database/        # AppDatabase (file JSON persistence)
│   ├── Network/         # HTTPClient, CookieJar, ImagePipeline
│   ├── Parser/          # CachingMangaRepository
│   ├── LocalStorage/    # downloads, CBZ import
│   ├── BackupSync/      # backup + sync stubs
│   ├── Auth/            # Face ID / Touch ID lock
│   ├── Local/           # persistent repos
│   └── Mock/            # demo catalogue
├── DesignSystem/
├── Features/            # Explore…Settings, Reader, Downloads, Tracker…
├── Resources/
├── Tests/
├── project.yml
└── README.md
```

## Yêu cầu

- macOS + **Xcode 15+**
- iOS deployment **17.0+**
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (khuyến nghị)

## Build

```bash
cd ios
brew install xcodegen   # lần đầu
xcodegen generate
open Usagi.xcodeproj
```

Chọn Simulator → **Run** (⌘R).

| | |
|--|--|
| Bundle ID | `org.draken.usagi` |
| Version | `0.1.0` |
| Deep link | `usagi://manga/1`, `usagi://search?q=...` |

## CI

Workflow: [`.github/workflows/ios.yml`](../.github/workflows/ios.yml) — `xcodegen` + `xcodebuild` trên `macos-14`.

## Phạm vi đã ship (theo plan)

| Phase | Nội dung |
|-------|----------|
| **0** | Shell, theme, tabs, logger, deep links, CI |
| **1** | Domain models, AppDatabase, settings, image cache |
| **2** | HTTPClient, cookies, caching repo, sources UI, CF WKWebView |
| **3** | Reader multi-mode, zoom, tap zones, filter, timer, bookmark, Photos |
| **4** | Download queue, offline packages, CBZ/ZIP import |
| **5** | Library categories, history, bookmarks, related, reading time, suggestions |
| **6** | Tracker, scrobbling stubs, sync stub, backup JSON, app lock |
| **7** | iPad split, a11y labels, `String(localized:)`, privacy screen |

## Chưa “production-complete” (cố ý stub / mock)

- **Parser sources thật** — hiện `MockMangaRepository` + architecture sẵn cho remote parsers
- **OAuth scrobbler / sync server** — UI + persistence; token flow stub
- **Plugin APK** — out of scope (plan anti-goal)
- **App icon asset 1024** — placeholder slot trong asset catalog

## License

GPL-3.0 — cùng project Usagi Android.
