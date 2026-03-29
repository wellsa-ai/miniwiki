# Contributing to miniwiki

Thanks for your interest in contributing to miniwiki! We welcome all kinds of contributions — bug reports, feature requests, code improvements, documentation, and more.

## 📋 Code of Conduct

We are committed to providing a welcoming and harassment-free environment for all contributors. Please be respectful and constructive in all interactions.

## 🐛 Reporting Bugs

Found a bug? Please create an issue with:

1. **Clear title**: e.g., "Editor crashes on Korean input with special characters"
2. **Description**: What did you do? What happened?
3. **Steps to reproduce**: Exact steps to trigger the bug
4. **Expected vs actual**: What should happen vs what actually happened
5. **Environment**:
   - Device (iPhone 14, Samsung S23, etc.)
   - OS version (iOS 17.2, Android 13, etc.)
   - miniwiki version
   - Flutter version (`flutter --version`)

### Example Bug Report

```
Title: Password dialog freezes when entering long passwords

Environment:
- Device: iPhone 14 Pro
- iOS: 17.2.1
- miniwiki: v0.2
- Flutter: 3.41

Steps to reproduce:
1. Go to Settings > Set Password
2. Enter a 100+ character password
3. Tap "Set"
4. App freezes for 5+ seconds

Expected: No freezing, password is set
Actual: UI is unresponsive for 5+ seconds during hashing
```

## 💡 Feature Requests

Have an idea? We'd love to hear it!

1. **Check existing issues first** — your feature might already be discussed
2. **Create an issue** with:
   - Clear title: "Feature: Auto-tagging for notes"
   - Why you need it: What problem does it solve?
   - Example use case: How would you use it?
   - Alternatives: Any workarounds?

## 🔧 Development Setup

### Prerequisites
```bash
Flutter 3.41+
Dart 3.11+
Xcode 15+ (for macOS/iOS development)
```

### Clone & Setup

```bash
# Fork the repository on GitHub, then:
git clone https://github.com/YOUR_USERNAME/miniwiki.git
cd miniwiki

# Install dependencies
flutter pub get

# Generate code (drift ORM, etc.)
dart run build_runner build --delete-conflicting-outputs

# Run tests
flutter test

# Start developing
flutter run -d macos
```

### Workflow

1. **Create a feature branch** (not on `main`):
   ```bash
   git checkout -b feature/wikilink-autocomplete
   # or
   git checkout -b fix/editor-korean-ime
   ```

2. **Make your changes**:
   - Write code following [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
   - Add tests for new features
   - Update documentation if needed

3. **Run tests & analysis**:
   ```bash
   flutter test          # Run all tests
   flutter analyze       # Check for issues
   ```

4. **Commit with meaningful messages**:
   ```bash
   git commit -m "feat: Add wikilink autocomplete in editor"
   git commit -m "fix: Prevent Korean IME composing on paste"
   git commit -m "docs: Update contributing guide"
   ```

5. **Push and create a Pull Request**:
   ```bash
   git push origin feature/wikilink-autocomplete
   ```
   Then go to GitHub and open a PR.

## 📝 PR Guidelines

### What We're Looking For
- ✅ Clear description of changes
- ✅ All tests passing (`flutter test`)
- ✅ No new warnings (`flutter analyze`)
- ✅ Follows Dart code style
- ✅ Documentation updates (if applicable)

### PR Template

```markdown
## Description
What does this PR do?

## Related Issue
Fixes #123 (if applicable)

## Changes
- Change 1
- Change 2
- Change 3

## Testing
How did you test this?
- [ ] Ran `flutter test`
- [ ] Tested manually on device/simulator
- [ ] Added new tests

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
```

## 🧪 Testing Guidelines

We maintain high test coverage. Please:

1. **Write tests for new features**:
   ```dart
   test('extractWikilinks should handle Korean characters', () {
     final links = extractWikilinks('[[한글링크]] and [[english]]');
     expect(links, ['한글링크', 'english']);
   });
   ```

2. **Run full test suite before committing**:
   ```bash
   flutter test --coverage
   ```

3. **Aim for >80% coverage** on modified files.

## 📖 Documentation

If you're adding a feature, please update:

1. **README.md** — Add to overview if major feature
2. **Inline comments** — Explain complex logic
3. **docs/** folder — Detailed design docs (optional)

### Documentation Style

```dart
/// Parses wikilinks from note content.
///
/// Supports both [[link]] and [[link|label]] syntax.
/// Returns empty list if no links found.
///
/// Example:
///   final links = extractWikilinks('See [[related-note]] and [[API]]');
///   // → ['related-note', 'API']
String extractWikilinks(String content) { ... }
```

## 🔐 Security Issues

**Do NOT open public issues for security vulnerabilities.**

Instead, please read [SECURITY.md](SECURITY.md) for responsible disclosure.

## 🎯 Areas We Need Help With

- **Documentation** — Improving guides and examples
- **Translations** — Help localize beyond KO/EN/JA
- **Testing** — Adding more edge case tests
- **Performance** — Optimizing search, encryption
- **UI/UX** — Design improvements and accessibility
- **Bug fixes** — See [open issues](../../issues)

## 💬 Questions?

- Check [Discussions](../../discussions) for Q&A
- Review [existing issues](../../issues) for context
- Read [documentation](docs/) first

## 🏆 Recognition

Contributors are added to [CONTRIBUTORS.md](CONTRIBUTORS.md) (when we create it!)

---

Thanks for contributing to miniwiki! 🎉
