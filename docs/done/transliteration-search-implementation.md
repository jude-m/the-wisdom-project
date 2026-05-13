# Transliteration Search Implementation

## Overview

This document describes the implementation of Singlish (romanized Sinhala) transliteration search, allowing users to search for Sinhala content using English letters.

**Example:** Searching for `sathi` (romanized) finds content containing `සති` (Sinhala script).

---

## Current Implementation

### Approach: Case-Sensitive Single Result

Based on [sinhala-unicode-converter](https://github.com/Open-SL/sinhala-unicode-converter), we use a **case-sensitive, deterministic** transliteration system.

| Feature | Description |
|---------|-------------|
| **Case-sensitive** | Uppercase letters = aspirated/special consonants |
| **Single result** | One input → one Sinhala output (no ambiguity) |
| **User control** | Users can precisely specify sounds using case |

---

## Case-Sensitive Mappings

### Consonant Disambiguation

| Singlish | Sinhala | Description |
|----------|---------|-------------|
| `t` | ට | Retroflex (hard t) |
| `T` | ඨ | Retroflex aspirated |
| `th` | ත | Dental (soft t) |
| `Th` | ථ | Dental aspirated |
| `d` | ඩ | Retroflex (hard d) |
| `D` | ඪ | Retroflex aspirated |
| `dh` | ද | Dental (soft d) |
| `Dh` | ධ | Dental aspirated |
| `sh` | ශ | Dental sibilant |
| `Sh` | ෂ | Retroflex sibilant |
| `n` | න | Dental nasal |
| `N` | ණ | Retroflex nasal |
| `l` | ල | Dental lateral |
| `L` | ළ | Retroflex lateral |

### Multi-Character Consonants

| Singlish | Sinhala | Description |
|----------|---------|-------------|
| `ch` | ච | Unaspirated |
| `Ch` | ඡ | Aspirated |
| `gh` | ඝ | Aspirated g |
| `kh` | ඛ | Aspirated k |
| `ph` | ඵ | Aspirated p |
| `bh` | භ | Aspirated b |
| `nnd` | ඬ | Combined |
| `nndh` | ඳ | Combined aspirated |
| `nng` | ඟ | Combined |

### Special Pali Characters

Uses `~` as escape prefix for special Pali sounds:

| Singlish | Sinhala | Name | Example Usage |
|----------|---------|------|---------------|
| `~n` | ං | Anusvara | sa~nga → සංග |
| `~h` | ඃ | Visarga | du~hkha → දුඃඛ |
| `~N` | ඞ | Retroflex nasal | (rare) |
| `~R` | ඍ | Vocalic R | (Pali/Sanskrit) |

### Vowels

| Singlish | Independent | Modifier (after consonant) |
|----------|-------------|---------------------------|
| `a` | අ | (inherent - no mark) |
| `aa` | ආ | ා |
| `A` | ඇ | ැ |
| `Aa` | ඈ | ෑ |
| `i` | ඉ | ි |
| `ii` / `ee` | ඊ | ී |
| `u` | උ | ු |
| `uu` / `oo` | ඌ | ූ |
| `e` | එ | ෙ |
| `o` | ඔ | ො |
| `au` | ඖ | ෞ |

---

## Key Examples

| Singlish | Sinhala | Notes |
|----------|---------|-------|
| `sathi` | සති | th = ත (dental) |
| `saThi` | සථි | Th = ථ (aspirated) - **different!** |
| `dharma` | දර්ම | dh = ද (dental) |
| `Dharma` | ධර්ම | Dh = ධ (aspirated) - **different!** |
| `buddha` | බුඩ්ද | |
| `nibbana` | නිබ්බන | |
| `rupa` | රූප | |

---

## Architecture

### Files

| File | Purpose |
|------|---------|
| `lib/core/utils/singlish_transliterator.dart` | Core transliteration logic |
| `lib/data/repositories/text_search_repository_impl.dart` | Search integration |
| `lib/presentation/widgets/search_overlay.dart` | Highlighting integration |

### API

```dart
final transliterator = SinglishTransliterator.instance;

// Convert Singlish to Sinhala (single result)
String sinhala = transliterator.convert('sathi'); // → 'සති'

// Check if query needs transliteration
bool needsConversion = transliterator.isSinglishQuery('sathi'); // → true
bool alreadySinhala = transliterator.isSinglishQuery('සති');    // → false
```

---

## Search Integration

### Title Search (`_searchTitles`)

Both Pali and Sinhala names are stored in Sinhala script, so we try BOTH the original query AND the converted query against BOTH names:

```dart
final originalQuery = normalizeText(queryText, toLowerCase: true);
final convertedQuery = transliterator.isSinglishQuery(queryText)
    ? normalizeText(transliterator.convert(queryText), toLowerCase: true)
    : null;

// Try original against both (for direct matches like Sinhala input)
final paliMatchedOriginal = paliName.contains(originalQuery);
final sinhalaMatchedOriginal = sinhalaName.contains(originalQuery);

// Try converted against both (for Singlish → Sinhala matches)
final paliMatchedConverted = convertedQuery != null && paliName.contains(convertedQuery);
final sinhalaMatchedConverted = convertedQuery != null && sinhalaName.contains(convertedQuery);
```

### Content Search (`_searchContent`)

Single FTS call with converted query:

```dart
final effectiveQuery = transliterator.isSinglishQuery(queryText)
    ? transliterator.convert(queryText)
    : queryText;

final ftsMatches = await _ftsDataSource.searchContent(effectiveQuery, ...);
```

### Highlighting (`_getEffectiveHighlightQuery`)

Finds which query form (original or converted) matches the displayed text:

```dart
// Try original first
if (normalizedText.contains(normalizedQuery)) {
  return query;
}

// Try converted Sinhala
if (transliterator.isSinglishQuery(query)) {
  final converted = transliterator.convert(query);
  if (normalizedText.contains(converted)) {
    return converted;
  }
}
```

---

## Algorithm: How It Works

### Step 1: Build Mapping Tables

```dart
static const _consonants = [
  ['nndh', 'ඳ'],  // Longest first
  ['nnd', 'ඬ'],
  ['Th', 'ථ'],
  ['th', 'ත'],
  ['t', 'ට'],     // Shortest last
  // ...
];
```

### Step 2: Replace in Order

1. Consonant + special modifiers (`kru` → `කෘ`)
2. Consonant + rakaransha + vowel (`kra` → `ක්‍ර`)
3. Consonant + vowel (`ka` → `ක`)
4. Standalone consonant + hal (`k` → `ක්`)
5. Standalone vowels (`a` → `අ`)

### Step 3: Return Single Result

```dart
String convert(String input) {
  var text = input;
  // ... apply replacements in order
  return text;  // Single deterministic result
}
```

---

## Test Coverage

### Unit Tests (`singlish_transliterator_test.dart`)

| Category | Examples |
|----------|----------|
| Basic vowels | `a → අ`, `aa → ආ` |
| Consonant + vowel | `ka → ක`, `ki → කි` |
| Case-sensitive | `t → ට`, `T → ඨ`, `th → ත`, `Th → ථ` |
| Critical words | `sathi → සති`, `dharma → දර්ම` |
| Legacy API | `getPossibleMatches()` returns single-element list |

### Integration Tests (`text_search_repository_impl_test.dart`)

- Title search with Singlish queries
- Content search with FTS
- Combined search results

---

## References

- **sinhala-unicode-converter**: https://github.com/Open-SL/sinhala-unicode-converter
- **UCSC Original**: https://ucsc.cmb.ac.lk/ltrl/services/feconverter/
