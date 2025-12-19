# 🏛️ The Wisdom Project - Review Board

> A coordinated team of AI agents ensuring code quality, security, accessibility, and documentation accuracy. Built for a solo developer making Dhamma accessible to the world.

**📋 Project Context**: Read [`.agent/project-context.md`](file://.agent/project-context.md) for architecture, patterns, and conventions.

---

## Agent Roster

| Agent | Role | Color | Model | Token Cost |
|-------|------|-------|-------|------------|
| 🟠 **flutter-code-reviewer** | Comprehensive code review (10+ files) | Orange | Opus | High |
| 🟢 **flutter-code-reviewer-light** | Quick review (<10 files) | Green | Sonnet | Low |
| 🔵 **test-quality-reviewer** | Validates test effectiveness | Blue | Sonnet | Medium |
| 🟣 **doc-accuracy-reviewer** | Ensures docs match code | Purple | Sonnet | Medium |
| 🩵 **a11y-ui-auditor** | Accessibility + UI design | Teal | Sonnet | Medium |
| 🔴 **security-auditor** | Database, auth, injection prevention | Red | Sonnet | Medium |
| 🟤 **qa-test-generator** | Generates tests for new code | Brown | Sonnet | Medium |

---

## Coverage Matrix

| Concern | Light | Heavy | Tests | Docs | A11y | Security |
|---------|:-----:|:-----:|:-----:|:----:|:----:|:--------:|
| Architecture | ✓ | ✓✓✓ | | | | |
| Code quality | ✓✓ | ✓✓✓ | | | | |
| Test existence | ✓ | ✓✓ | | | | |
| Test quality | | ✓ | ✓✓✓ | | | |
| Doc existence | | ✓ | | | | |
| Doc accuracy | | | | ✓✓✓ | | |
| Accessibility | | ✓ | | | ✓✓✓ | |
| UI design | | | | | ✓✓✓ | |
| Performance | ✓ | ✓✓ | | | | |
| SQL injection | | ✓ | | | | ✓✓✓ |
| Data protection | | | | | | ✓✓✓ |
| Input validation | ✓ | ✓ | | | | ✓✓✓ |

Legend: ✓ = Basic check, ✓✓ = Thorough check, ✓✓✓ = Deep specialist review

---

## When to Use Each Agent

### Decision Tree

```
Start: What kind of change?
│
├── "Quick bug fix, <5 files"
│   └── 🟢 flutter-code-reviewer-light
│
├── "New feature, 5-10 files"
│   ├── 🟢 flutter-code-reviewer-light (code)
│   ├── 🟤 qa-test-generator (create tests)
│   └── 🔵 test-quality-reviewer (validate tests)
│
├── "Major feature, 10+ files"
│   ├── 🟠 flutter-code-reviewer (code)
│   ├── 🟤 qa-test-generator (create tests)
│   ├── 🔵 test-quality-reviewer (validate tests)
│   └── 🟣 doc-accuracy-reviewer (update docs)
│
├── "UI changes"
│   ├── 🟢 or 🟠 (based on size)
│   └── 🩵 a11y-ui-auditor (always for UI!)
│
├── "Database/storage changes"
│   ├── 🟢 or 🟠 (based on size)
│   └── 🔴 security-auditor (always for data!)
│
├── "Documentation update"
│   └── 🟣 doc-accuracy-reviewer (only)
│
└── "Pre-release audit"
    ├── 🟠 flutter-code-reviewer
    ├── 🔵 test-quality-reviewer
    ├── 🟣 doc-accuracy-reviewer
    ├── 🩵 a11y-ui-auditor
    └── 🔴 security-auditor
```

---

## Recommended Pipelines

### Pipeline 1: Bug Fix (Fast)

```
┌─────────────────────────────────────────────────────┐
│  🟢 flutter-code-reviewer-light                     │
│  • Quick code review                                │
│  • ~5 min                                           │
└─────────────────────────────────────────────────────┘
                        ↓
                   ✅ Merge
```

### Pipeline 2: New Feature (Standard)

```
┌─────────────────────────────────────────────────────┐
│  1️⃣ 🟤 qa-test-generator                            │
│  • Generate unit + widget tests                     │
│  • Propose E2E scenarios                            │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│  2️⃣ 🔵 test-quality-reviewer                        │
│  • Validate generated tests                         │
│  • Ensure tests are meaningful                      │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│  3️⃣ 🟢 flutter-code-reviewer-light                  │
│  • Review feature code                              │
│  • Check architecture, quality                      │
└─────────────────────────────────────────────────────┘
                        ↓
                   ✅ Merge
```

### Pipeline 3: UI Feature

```
┌─────────────────────────────────────────────────────┐
│  1️⃣ 🟢 flutter-code-reviewer-light                  │
│  • Widget structure, state management               │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│  2️⃣ 🩵 a11y-ui-auditor                              │
│  • Accessibility compliance                         │
│  • Color harmony, typography                        │
│  • Design appropriate for dhamma                    │
└─────────────────────────────────────────────────────┘
                        ↓
                   ✅ Merge
```

### Pipeline 4: Database/Storage Change

```
┌─────────────────────────────────────────────────────┐
│  1️⃣ 🟢 flutter-code-reviewer-light                  │
│  • Code quality, patterns                           │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│  2️⃣ 🔴 security-auditor                             │
│  • SQL injection check                              │
│  • Data integrity verification                      │
│  • Secure storage practices                         │
└─────────────────────────────────────────────────────┘
                        ↓
                   ✅ Merge
```

### Pipeline 5: Major Release (Comprehensive)

```
┌─────────────────────────────────────────────────────┐
│  1️⃣ 🟠 flutter-code-reviewer (heavy)                │
│  • Full architecture review                         │
│  • All 8 categories                                 │
└─────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────┬──────────────────────────────┐
│ 2️⃣ 🔵 test-quality   │ 3️⃣ 🟣 doc-accuracy           │
│ • Test coverage      │ • Docs match code            │
│ • Test effectiveness │ • Examples work              │
└──────────────────────┴──────────────────────────────┘
                        ↓
┌──────────────────────┬──────────────────────────────┐
│ 4️⃣ 🩵 a11y-ui        │ 5️⃣ 🔴 security               │
│ • WCAG compliance    │ • Injection prevention       │
│ • Design review      │ • Data protection            │
└──────────────────────┴──────────────────────────────┘
                        ↓
                   ✅ Release
```

---

## Non-Overlapping Responsibilities

Each agent has **exclusive jurisdiction** over certain concerns:

| Agent | Exclusive Concerns (no other agent checks) |
|-------|-------------------------------------------|
| 🟠🟢 Code Reviewers | Architecture, SOLID, Riverpod patterns, code structure |
| 🔵 Test Quality | Test assertions quality, mock appropriateness, QA guideline compliance |
| 🟣 Doc Accuracy | Dartdoc-code match, example compilation, README currency |
| 🩵 A11y/UI | WCAG compliance, color harmony, typography hierarchy |
| 🔴 Security | SQL injection, FTS sanitization, secure storage, data integrity |
| 🟤 QA Generator | Test creation (not review), E2E scenario proposals |

---

## Escalation Paths

```
🟢 Light Reviewer
    │
    ├─ "10+ files" ──────────→ 🟠 Heavy Reviewer
    │
    ├─ "Security concern" ───→ 🔴 Security Auditor
    │
    └─ "Test quality issue" ─→ 🔵 Test Quality Reviewer


🟤 QA Test Generator
    │
    └─ Tests created ────────→ 🔵 Test Quality Reviewer


🔵 Test Quality Reviewer
    │
    └─ "Fundamental test architecture issues" ──→ 🟠 Heavy Reviewer


🩵 A11y/UI Auditor
    │
    └─ "Widget code issues" ──→ 🟢 Light Reviewer
```

---

## Quick Reference Commands

```bash
# Run specific agent (example slash commands)
/flutter-code-reviewer        # Heavy review
/flutter-code-reviewer-light  # Quick review
/test-quality-reviewer        # Validate tests
/doc-accuracy-reviewer        # Check docs
/a11y-ui-auditor              # Accessibility + design
/security-auditor             # Security check
/qa-test-generator            # Generate tests

# Common workflows
/qa-test-generator && /test-quality-reviewer  # Generate + validate tests
/flutter-code-reviewer-light && /a11y-ui-auditor  # UI change review
/flutter-code-reviewer-light && /security-auditor  # Data change review
```

---

## Review Board Philosophy

### 🙏 For The Wisdom Project

This review board exists to ensure that:

1. **The Dhamma is accessible** — Accessibility audits ensure everyone can use the app
2. **The Dhamma is preserved** — Security audits protect text integrity
3. **Development is sustainable** — Good tests and docs help solo developer maintain quality
4. **Code serves its purpose** — Reviews focus on what matters, not nitpicking

### 🎯 Quality Over Bureaucracy

- Not every change needs every agent
- Quick bug fix? Light reviewer only
- The board exists to **help**, not to **block**
- When in doubt, ask: "Does this help make Dhamma more accessible?"

---

## Agent Summary Card

```
┌────────────────────────────────────────────────────────────┐
│  📋 THE WISDOM PROJECT - REVIEW BOARD                      │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  🟠 Heavy Reviewer ─── Major changes, architecture         │
│  🟢 Light Reviewer ─── Bug fixes, small features           │
│  🟤 QA Generator ───── Create tests automatically          │
│  🔵 Test Quality ───── Validate test effectiveness         │
│  🟣 Doc Accuracy ───── Ensure docs match code              │
│  🩵 A11y/UI ─────────── Accessibility + design             │
│  🔴 Security ────────── Database + data protection         │
│                                                            │
├────────────────────────────────────────────────────────────┤
│  Quick Pick:                                               │
│  • Small change → 🟢                                       │
│  • New feature → 🟤 → 🔵 → 🟢                               │
│  • UI work → 🟢 + 🩵                                        │
│  • Data work → 🟢 + 🔴                                      │
│  • Release → All of them! 🟠🔵🟣🩵🔴                         │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

*May this review board help bring the Dhamma to all beings, with code that is secure, accessible, well-tested, and well-documented.* 🙏
