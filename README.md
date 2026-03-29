[English](README.md) | [한국어](README.ko.md)

# miniwiki

**Privacy-first personal wiki** — 100% offline, end-to-end encrypted

[![GitHub Release](https://img.shields.io/badge/release-v0.2-green)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](#license)
[![Flutter](https://img.shields.io/badge/Flutter-3.41-blue?logo=flutter)](#)
[![Tests](https://img.shields.io/badge/Tests-54%2F54-brightgreen)](#test-coverage)

> Your notes, your device, your rules. No cloud. No tracking. No compromises.

---

## ✨ Core Features

- **100% Offline**: Works without internet. Zero cloud transmission. Complete data sovereignty.
- **E2E Encryption**: SQLite3MultipleCiphers (ChaCha20-Poly1305) by default. Password-protected.
- **Wikilinks**: `[[link]]` syntax for note connections, auto-generated backlinks
- **Cross-Platform**: iOS, Android, macOS via Flutter
- **Perfect Korean Support**: Native IME via WKWebView for flawless input
- **Rich Editor**: Markdown, WYSIWYG toolbar, live preview
- **Full-Text Search**: FTS5 with Korean tokenization + query sanitization

---

## 🏗️ Tech Stack

| Layer | Technology |
|-------|------------|
| **UI** | Flutter 3.41 + Material 3 |
| **Editor** | WKWebView + contenteditable (flutter_inappwebview) |
| **State** | Riverpod 2.x |
| **Routing** | GoRouter (state-based redirects) |
| **Database** | drift ORM + SQLite3MultipleCiphers |
| **Search** | FTS5 (unicode61 tokenizer) + query sanitization |
| **Security** | HMAC-SHA256 (100K iterations) + SecureStorage + PRAGMA rekey verification |
| **AI** | Qwen2.5-1.5B via llama.cpp FFI (forthcoming) |
| **Sync** | CRDT + Bonjour/mDNS (roadmap) |

---

## 🚀 Quick Start

### Requirements
```
Flutter 3.41+
Dart 3.11+
Xcode 15+ (for macOS/iOS)
```

### Installation

```bash
# Clone and setup
git clone https://github.com/wellsa-ai/miniwiki.git
cd miniwiki
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Run tests
flutter test

# Build & run
flutter run -d macos      # macOS
flutter run -d ios        # iOS (requires simulator/device)
```

---

## 📁 Project Structure

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
        ├── settings/               # App config, password
        └── ai/                     # Auto-tagging (forthcoming)

assets/editor/editor.html           # Editor HTML (contenteditable + toolbar)
landing/index.html                  # Landing page (KO/EN/JA multilingual)
```

---

## 🔐 Security

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
- No analytics
- No tracking
- No user data sent anywhere

---

## 📊 Test Coverage

```
51 tests, 0 failures ✓

├── database_test.dart (24)
│   ├── Notes CRUD (6)
│   ├── FTS5 Search (6)
│   ├── Tags (6)
│   ├── Links (4)
│   └── Streams (1)
├── wikilink_parser_test.dart (13)
├── content_converter_test.dart (13)
└── widget_test.dart (1)
```

Run tests:
```bash
flutter test --coverage
```

---

## ⌨️ Editor Shortcuts

| Action | Shortcut |
|--------|----------|
| Bold | `Cmd+B` |
| Italic | `Cmd+I` |
| Underline | `Cmd+U` |
| Strikethrough | `Cmd+S` |
| Heading 1/2/3 | `# / ## / ###` + Space |
| Horizontal Rule | `---` |
| Help | `Cmd+/` |
| Paste (auto-convert) | `Cmd+V` |

---

## 📖 Documentation

- **[Product Requirements](docs/01_요구사항/PRD.md)** (Korean)
- **[System Architecture](docs/04_아키텍처/01_시스템_아키텍처.md)** (Korean)
- **[Research Summary](docs/02_리서치/00_종합리포트.md)** (Korean)
- **[Landing Page](landing/index.html)** (KO/EN/JA)

---

## 🤝 Contributing

We welcome contributions! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

### Setup for Contributors

```bash
# Fork and clone
git clone https://github.com/YOUR_USERNAME/miniwiki.git
cd miniwiki

# Create feature branch
git checkout -b feature/your-feature

# Make changes and test
flutter test

# Push and create PR
git push origin feature/your-feature
```

### Code Style
- Follow [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter analyze` before committing
- Write tests for new features

---

## 🔒 Security Policy

**For security vulnerabilities**, please read [SECURITY.md](SECURITY.md) instead of opening a public issue.

---

## 📱 Installation

### iOS (App Store - Coming Soon)
```
Available on TestFlight for beta testing.
See [CONTRIBUTING.md](CONTRIBUTING.md) for beta signup.
```

### Android (Google Play - Coming Soon)
```
Available on Google Play beta channel.
See [CONTRIBUTING.md](CONTRIBUTING.md) for beta signup.
```

### Build from Source
```bash
# iOS
flutter build ios

# Android
flutter build apk
flutter build appbundle  # For Play Store
```

---

## 📋 Roadmap

### v0.2 (Current - March 2026)
- ✅ E2E encryption (HMAC-SHA256 + ChaCha20-Poly1305)
- ✅ Wikilinks + backlinks
- ✅ Full-text search (FTS5)
- ✅ Tag system
- ✅ Password protection
- ✅ Production security hardening

### v0.3 (Planned)
- On-device AI auto-tagging (Qwen2.5-1.5B)
- Note backups with ZIP compression
- Markdown export/import
- Dark mode refinement

### v0.4+ (Roadmap)
- Peer-to-peer sync (CRDT + Bonjour)
- Cloud-optional sync (Nextcloud/Syncthing)
- Multi-vault support
- Plugin system

---

## 🙋 FAQ

**Q: Why offline-first?**
A: Your privacy is paramount. When your data never leaves your device, no one can intercept or sell it.

**Q: How is it different from Obsidian?**
A: miniwiki focuses on simplicity (no plugins) and perfect Korean support. Obsidian is more extensible. Both are offline-first.

**Q: Can I sync between devices?**
A: Not yet, but it's on the roadmap (v0.4+). For now, manual export/import or cloud storage backup.

**Q: Is it open source?**
A: Yes! MIT license. You can modify and redistribute freely.

**Q: Can I use it commercially?**
A: Yes, MIT allows commercial use. Just include the license notice.

---

## 📄 License

This project is licensed under the **MIT License** — see [LICENSE](LICENSE) file for details.

You are free to:
- ✅ Use commercially
- ✅ Modify and distribute
- ✅ Use privately

Just include the license notice.

---

## 🎯 Credits

- **Inspired by**: Obsidian, Notion, Standard Notes
- **Built with**: Flutter, Riverpod, SQLite3MultipleCiphers
- **Tested with**: 51 automated tests

---

## 📞 Support

- 💬 **Discussions**: [GitHub Discussions](../../discussions)
- 🐛 **Bug Reports**: [GitHub Issues](../../issues)
- 📧 **Security**: See [SECURITY.md](SECURITY.md)

---

**[View Documentation in Korean](README.ko.md)** | **[View Landing Page](landing/index.html)**

<div align="center">

Made with ❤️ by [wellsa.ai](https://github.com/wellsa-ai)

*Your data, your device, your rules.*

</div>
