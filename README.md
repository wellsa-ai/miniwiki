[English](README.md) | [한국어](README.ko.md)

# miniwiki

**Privacy-first personal wiki** — 100% offline, end-to-end encrypted

[![GitHub Release](https://img.shields.io/badge/release-v0.2-green)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](#license)
[![Flutter](https://img.shields.io/badge/Flutter-3.41-blue?logo=flutter)](#)
[![Tests](https://img.shields.io/badge/Tests-54%2F54-brightgreen)](#test-coverage)

> Your notes, your device, your rules. No cloud. No tracking. No compromises.

---

## Core Features

- **100% Offline**: Works without internet. Zero cloud transmission. Complete data sovereignty.
- **E2E Encryption**: SQLite3MultipleCiphers (ChaCha20-Poly1305) by default. Password-protected.
- **Wikilinks**: `[[link]]` syntax for note connections, auto-generated backlinks
- **Cross-Platform**: iOS, Android, macOS via Flutter
- **Perfect Korean Support**: Native IME via WKWebView for flawless input
- **Rich Editor**: WYSIWYG toolbar, keyboard shortcuts, auto-save
- **Full-Text Search**: FTS5 with Korean tokenization + query sanitization

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| **UI** | Flutter 3.41 + Material 3 |
| **Editor** | WKWebView + contenteditable (flutter_inappwebview) |
| **State** | Riverpod 2.x |
| **Routing** | GoRouter (state-based redirects) |
| **Database** | drift ORM + SQLite3MultipleCiphers |
| **Search** | FTS5 (unicode61 tokenizer) + query sanitization |
| **Security** | HMAC-SHA256 (100K iterations) + SecureStorage + PRAGMA rekey verification |

---

## Quick Start

### Requirements
```
Flutter 3.41+
Dart 3.11+
Xcode 15+ (for macOS/iOS)
```

### Build & Run

```bash
git clone https://github.com/wellsa-ai/miniwiki.git
cd miniwiki
flutter pub get
dart run build_runner build --delete-conflicting-outputs

flutter test              # Run tests
flutter run -d macos      # macOS
flutter run -d ios        # iOS
```

---

## Project Structure

```
lib/
├── main.dart                        # App entry point
└── src/
    ├── app/
    │   ├── router.dart             # GoRouter + state-based redirects
    │   └── theme.dart              # Material 3 theme (#2E7353)
    ├── core/
    │   ├── providers/app_providers.dart  # Auth, DB keys, initialization
    │   ├── database/
    │   │   ├── database.dart       # drift schema + migrations
    │   │   ├── connection.dart     # Encrypted DB connection
    │   │   └── daos/notes_dao.dart # CRUD + FTS5 + tags/links
    │   └── logger/app_logger.dart  # Structured logging
    └── features/
        ├── editor/                 # Rich text editor
        ├── notes/                  # List, CRUD
        ├── search/                 # FTS5 full-text search
        └── settings/               # App config, password

assets/editor/editor.html           # Editor HTML (contenteditable + toolbar)
landing/index.html                  # Landing page (KO/EN/JA)
```

---

## Security

### Password Protection
- **HMAC-SHA256** with 100,000 iterations
- Auto-migration from legacy SHA256 on first unlock
- Timeout handling (10s limit)
- Automatic rollback on encryption failure

### Database Encryption
- **ChaCha20-Poly1305** cipher
- PRAGMA rekey with verification
- Secure key storage (FlutterSecureStorage)
- Background processing to prevent UI blocking

### No Telemetry
- No analytics, no tracking, no data sent anywhere

For security vulnerabilities, please read [SECURITY.md](SECURITY.md).

---

## Test Coverage

```
54 tests, 0 failures

├── database_test.dart (27)
│   ├── Notes CRUD (6)
│   ├── FTS5 Search (6)
│   ├── Tags (6)
│   ├── Links (4)
│   ├── Streams (1)
│   └── Data Integrity (3)
├── wikilink_parser_test.dart (13)
├── content_converter_test.dart (13)
└── widget_test.dart (1)
```

---

## Editor Shortcuts

| Action | Shortcut |
|--------|----------|
| Bold | `Cmd+B` |
| Italic | `Cmd+I` |
| Underline | `Cmd+U` |
| Heading 1/2/3 | `# / ## / ###` + Space |
| Horizontal Rule | `---` |
| Help | `Cmd+/` |

---

## Roadmap

### v0.2 (Current)
- E2E encryption (HMAC-SHA256 + ChaCha20-Poly1305)
- Wikilinks + backlinks
- Full-text search (FTS5)
- Tag system
- Password protection

### v0.3 (Planned)
- On-device AI auto-tagging (Qwen2.5-1.5B)
- Encrypted backups
- Markdown export/import

### v0.4+
- Peer-to-peer sync (CRDT + Bonjour)
- Multi-vault support

---

## Contributing

We welcome contributions! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

```bash
git clone https://github.com/YOUR_USERNAME/miniwiki.git
cd miniwiki
git checkout -b feature/your-feature
flutter test
git push origin feature/your-feature
```

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Support

- **Discussions**: [GitHub Discussions](../../discussions)
- **Bug Reports**: [GitHub Issues](../../issues)
- **Security**: [SECURITY.md](SECURITY.md)

<div align="center">

Made with care by [wellsa.ai](https://github.com/wellsa-ai)

---

**If MiniWiki is useful to you, please ⭐ star this repo — it helps others find it!**

[![Star History Chart](https://api.star-history.com/svg?repos=wellsa-ai/miniwiki&type=Date)](https://star-history.com/#wellsa-ai/miniwiki&Date)

</div>
