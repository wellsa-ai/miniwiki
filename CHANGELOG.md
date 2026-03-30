# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-03-30

### Added
- E2E database encryption (ChaCha20-Poly1305 via SQLite3MultipleCiphers)
- HMAC-SHA256 password hashing (100,000 iterations)
- Auto-migration from legacy SHA256 to HMAC-SHA256
- PRAGMA rekey verification with automatic rollback on failure
- Background password hashing via `compute()` to prevent UI blocking
- 10-second timeout on hash operations
- Wikilinks (`[[link]]`) with auto-generated backlinks
- FTS5 full-text search with unicode61 tokenizer
- WKWebView-based rich text editor with native CJK IME support
- WYSIWYG formatting toolbar (Bold, Italic, Underline, Headings, Lists, etc.)
- Editor keyboard shortcuts (Cmd+B, Cmd+I, Cmd+U, etc.)
- Auto-save (3-second debounce)
- Tag system with many-to-many relationships
- Note categories and filtering
- Sort options (updated, created, title)
- Backup/export functionality
- Landing page (KO/EN/JA multilingual)
- XSS prevention (HTML sanitization)
- FTS5 query sanitization
- MIT license, SECURITY.md, CONTRIBUTING.md, issue templates

### Fixed
- DB hex key encoding: `connection.dart` used `codeUnits` (ASCII of base64 string) instead of `base64Url.decode()` (actual bytes), causing key mismatch after app restart
- Note list performance: changed from full-list rebuild to per-tile subscription via `noteByIdProvider`, so editing one note only rebuilds that one tile
- Hash timeout fallback security: `setPassword()` no longer falls back to weak legacy hash on timeout (only `unlock()` allows fallback for backward compatibility)
- Editor concurrent save prevention
- New note creation save bug

## [0.1.0] - 2026-03-27

### Added
- Initial project setup
- Basic note CRUD with drift ORM
- SQLite database with encryption support
- Flutter project scaffolding (iOS, Android, macOS)
- Basic search functionality
- Dark mode support
