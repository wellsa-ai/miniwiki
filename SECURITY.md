# Security Policy

## 🔐 Security is Our Priority

miniwiki is a privacy-first application. We take security seriously and appreciate the community's help in keeping our users safe.

## 📋 Supported Versions

| Version | Status | Security Updates |
|---------|--------|-----------------|
| 0.2.x | Current | ✅ Active |
| 0.1.x | Deprecated | ⚠️ Limited |

## 🚨 Reporting Security Vulnerabilities

**Do NOT open public GitHub issues for security vulnerabilities.** This helps protect users before fixes are available.

### How to Report

Please email security concerns to: **security@wellsa.ai** (or contact through GitHub Security Advisory if available)

Include:
- **Type of vulnerability** (e.g., encryption bypass, data leakage, authentication bypass)
- **Location** (e.g., `lib/src/core/providers/app_providers.dart` line 125)
- **Steps to reproduce** (exact code or steps)
- **Impact** (what could an attacker do?)
- **Proof of concept** (optional, but helpful)

### Example Report

```
Subject: Security: Potential encryption key leakage in logs

Type: Information Disclosure
Severity: High

Location: lib/src/core/logger/app_logger.dart line 40

Issue:
Database encryption key is logged in cleartext during setPassword():
  AppLogger.info('DB key: $dbKey', context: 'Auth');

Steps to Reproduce:
1. Call AppController.setPassword()
2. Check debug logs
3. Key is visible in plaintext

Impact:
- Attackers with log access could decrypt the database
- Sensitive key material is exposed

Fix:
- Remove key logging or use key fingerprint instead:
  AppLogger.info('DB key set (fingerprint: ${dbKey.substring(0, 8)}...)', context: 'Auth');
```

## 🔒 Security Features

### Current Implementation (v0.2)

#### Password Security
- **HMAC-SHA256** with 100,000 iterations
- 32-byte salt generated via `Random.secure()`
- Auto-migration from legacy SHA256 to HMAC-SHA256
- Timeout handling (10 seconds max)
- UI non-blocking via `compute()` isolates

#### Database Encryption
- **ChaCha20-Poly1305** cipher (SQLite3MultipleCiphers)
- PRAGMA rekey with verification
- Encrypted database file
- Secure key storage (FlutterSecureStorage)

#### No Telemetry
- Zero analytics
- Zero tracking
- Zero data transmission

#### Code Security
- XSS prevention (HTML sanitization)
- FTS5 query sanitization
- Secure random generation for salts/keys

### Roadmap

- **v0.3**: Encrypted backups with password protection
- **v0.4**: Secure peer-to-peer sync (CRDT)
- **Future**: Hardware security key support (FIDO2)

## 🛡️ Known Limitations

### Design Limitations
1. **No cloud sync** — Data stays on device (by design)
2. **Local backups only** — No automatic cloud backups
3. **Single password** — App-level encryption only
4. **No biometric fallback** — Password required for encryption
5. **No remote lock** — Device theft means potential local access

### Not Recommended For
- Highly sensitive financial data (use a dedicated password manager)
- Multi-user shared vaults (single-user design)
- Real-time collaboration (offline-first design)

### Development/Testing
- **No code signing verification** — APK/IPA from source is identical
- **Debug logs in development** — Don't log sensitive data in release builds
- **Source code published** — Full transparency, auditable by community

## ✅ Security Checklist

We follow these practices:

- [x] No hardcoded secrets
- [x] No logging of sensitive data (keys, passwords)
- [x] Input validation on all forms
- [x] Secure random generation (`Random.secure()`)
- [x] Constant-time comparison for passwords (via hash equality)
- [x] No eval/code injection points
- [x] Dependencies kept up-to-date
- [x] Automated tests for security features

## 🔄 Vulnerability Disclosure Process

1. **Report received** → We acknowledge within 48 hours
2. **Assessment** → We evaluate severity and impact
3. **Fix development** → We create a patch (timeline depends on severity)
4. **Testing** → We verify the fix works
5. **Release** → We push a patch release
6. **Disclosure** → We credit the reporter and publish the advisory

**Timeline**:
- **Critical**: Fix within 7 days
- **High**: Fix within 14 days
- **Medium**: Fix within 30 days
- **Low**: Fix in next release

## 📚 Security Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Dart Security Best Practices](https://dart.dev/guides/security)
- [Flutter Security Guidelines](https://flutter.dev/docs/testing/security-testing)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)

## 🙏 Thanks

We appreciate responsible security research. Researchers who responsibly disclose security vulnerabilities will be credited in our security advisories (unless they prefer anonymity).

---

**Last Updated**: March 2026
**Policy Version**: 1.0

For questions, email **security@wellsa.ai**
