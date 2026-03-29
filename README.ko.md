[English](README.md) | [한국어](README.ko.md)

# miniwiki

데이터 주권형 개인 위키 플랫폼 — 온디바이스 AI, E2E 암호화, 완전 오프라인

## 핵심 특징

- **완전 오프라인**: 인터넷 없이 100% 동작, 클라우드 미전송
- **E2E 암호화**: SQLite3MultipleCiphers (ChaCha20-Poly1305) 기본 탑재
- **온디바이스 AI**: Qwen2.5-1.5B 기반 자동 태깅/분류 (향후)
- **위키링크**: `[[link]]` 문법으로 노트 간 연결, 자동 백링크
- **크로스플랫폼**: Flutter 기반 iOS/Android/macOS
- **한글 완벽 지원**: WKWebView 네이티브 IME 기반 에디터

## 기술 스택

| 레이어 | 기술 |
|--------|------|
| UI | Flutter 3.41 + Material 3 (#2E7353) |
| 에디터 | WKWebView + contenteditable (flutter_inappwebview) |
| 상태관리 | Riverpod 2.x |
| 라우팅 | GoRouter (상태 기반 리다이렉트) |
| DB | drift ORM + SQLite3MultipleCiphers |
| 검색 | FTS5 (unicode61 토크나이저) + 쿼리 sanitization |
| 보안 | SHA-256 비밀번호 검증 + SecureStorage + PRAGMA rekey |
| AI | Qwen2.5-1.5B-Instruct via llama.cpp FFI (향후) |
| 동기화 | CRDT + Bonjour/mDNS (향후) |

## 프로젝트 구조

```
lib/
├── main.dart                              # 앱 진입점
└── src/
    ├── app/
    │   ├── router.dart                    # GoRouter + 상태 기반 리다이렉트
    │   └── theme.dart                     # Material 3 테마 (#2E7353)
    ├── core/
    │   ├── providers/app_providers.dart   # 앱 초기화, 인증, DB 키 관리
    │   ├── ai/                           # llama.cpp FFI, AI 프롬프트
    │   └── database/
    │       ├── database.dart             # drift 스키마 + 마이그레이션
    │       ├── connection.dart           # 암호화 DB 연결
    │       └── daos/notes_dao.dart       # CRUD + FTS5 검색 + 태그/링크
    └── features/
        ├── editor/
        │   ├── views/editor_page.dart    # WebView 에디터, 자동저장 (3s)
        │   ├── widgets/webview_editor.dart  # WKWebView 래퍼
        │   ├── widgets/tag_bar.dart      # 태그 Chip UI
        │   ├── widgets/backlinks_panel.dart # 백링크 패널
        │   └── utils/
        │       ├── wikilink_parser.dart  # [[wikilink]] + #hashtag 파서
        │       └── content_converter.dart # AppFlowy JSON/HTML/PlainText 변환
        ├── notes/                        # 노트 목록, CRUD
        ├── search/                       # FTS5 전문검색
        ├── settings/                     # 앱 설정, 비밀번호 관리
        └── ai/                           # AI 자동 태깅

assets/editor/editor.html                 # 에디터 (contenteditable + 툴바 + 단축키)
landing/index.html                        # 랜딩페이지 (KO/EN/JA 다국어)
```

## 개발 환경

```bash
# 요구사항
Flutter 3.41+
Dart 3.11+
Xcode 15+ (macOS/iOS 빌드)

# 설치
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 테스트 (51 tests)
flutter test

# 실행
flutter run -d macos
```

## 테스트 현황

```
51 tests, 0 failures

├── database_test.dart (24)
│   ├── Notes CRUD (6): insert, retrieve, soft delete, permanent delete, update, partial update
│   ├── FTS5 Search (6): title/content 검색, 삭제 노트 제외, 업데이트 후 검색
│   ├── Tags (6): CRUD, 다대다 관계, 중복 방지, confidence/isManual
│   ├── Links (4): wikilink, backlinks, upsert, 다중 링크 타입
│   └── Streams (1): watchAllNotes 반응성
├── wikilink_parser_test.dart (13)
│   ├── extractWikilinks (5): 단일/복수, 한국어, 공백 트림
│   ├── extractHashtags (6): 단일/복수, 한국어, 하이픈/언더스코어
│   └── wikilinkToMarkdown (2): 기존 노트 링크, 새 노트 링크
├── content_converter_test.dart (13)
│   ├── appflowyJsonToHtml (6): JSON 변환, 다중 문단, 빈 delta, XSS, 한글
│   ├── plainTextToHtml (3): 단일/복수 줄, 빈 줄 처리
│   ├── htmlToPlainText (2): 태그 제거, entity 디코딩
│   └── escapeHtml (2): 특수문자, 일반 텍스트
└── widget_test.dart (1)
```

## 에디터 기능

| 기능 | 단축키 |
|------|--------|
| Bold | `Cmd+B` |
| Italic | `Cmd+I` |
| Underline | `Cmd+U` |
| Heading 1/2/3 | `# / ## / ###` + Space |
| 수평선 | `---` |
| 단축키 도움말 | `Cmd+/` |
| 붙여넣기 | plain text 자동 변환 |
| 툴바 | B, I, U, S, H1-H3, 리스트, 인용, 코드, 수평선 |

## 문서

| 문서 | 경로 |
|------|------|
| PRD | `docs/01_요구사항/PRD.md` |
| 리서치 종합 | `docs/02_리서치/00_종합리포트.md` |
| 제품 전략 | `docs/03_전략/01_제품전략.md` |
| 시스템 아키텍처 | `docs/04_아키텍처/01_시스템_아키텍처.md` |
| 야간 AI 개선회의 | `docs/05_회의록/2026-03-28_야간_AI_개선회의.md` |
| 랜딩페이지 | `landing/index.html` (한/영/일 다국어) |

## Known Issues (v0.2에서 해결 예정)

- **DB hex 키 인코딩**: base64 문자열의 codeUnits를 hex로 변환 (실제 바이트와 다름). 기존 DB 호환성 때문에 마이그레이션과 함께 수정.
- **노트 리스트 성능**: 전체 리스트 리빌드 → 개별 타일 리빌드 최적화 (Provider 구조 변경)

## 라이선스

MIT License — [자세히 보기](LICENSE)

---

**프로젝트**: miniwiki | **시작일**: 2026-03-27 | **팀**: 마마 + 미니 | **목표**: 3개월 MVP
