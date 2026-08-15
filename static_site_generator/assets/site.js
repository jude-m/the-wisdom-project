/* The only JavaScript on the site.
 *
 * Two jobs, one file, because two files would be two requests for ~4 KB:
 *   1. the reading layout carried in `?layout=` and remembered afterwards;
 *   2. the search dialog.
 *
 * A committed source the build copies, like the fonts and the emblem — there is
 * no bundler and no transpiler in this pipeline (D9). So: no modules, no
 * optional chaining, nothing that needs a build step to reach an old phone.
 *
 * Nothing here is required for a page to work. With JS off the layout falls
 * back to the one baked `checked` in the HTML and the search button never
 * appears. That is the zero-JS baseline (C8), and it is why this file may fail
 * silently but must never throw before the layout code has run.
 *
 * ## It spells no string and no URL of its own
 *
 * Every label and every path arrives on a `data-` attribute the generator
 * wrote. This file therefore holds no Sinhala, no `/tipitaka/`, and no layout
 * token — because a copy of any of those here is a copy that drifts from the
 * Dart the day someone edits one and not the other, and nothing would fail to
 * say so. The one contract it does rely on is the *field order* of an index
 * row, named in the KEY/PALI/SINHALA/PARENT/CHAPTER/MARKED constants below —
 * get that wrong and search returns plausible results pointing at the wrong
 * sutta.
 *
 * Nothing needs bumping when it changes. The build stamps `?v=` on this file
 * and on the index with one hash of *both*, so no cache can hold an old one of
 * the two beside a new other — and editing either one is what busts it. See
 * `lib/render/site_assets.dart`.
 */
(function () {
  'use strict';

  /* ===================================================================== *
   * 1 · Reading layout                                                    *
   * ===================================================================== */

  /* The radios ARE the state. `?layout=` and localStorage both resolve by
   * checking one of them, so there is no second copy of "which layout is on"
   * to drift from what the CSS is actually matching.
   *
   * Matching is on the radio's `value`, which the generator writes from
   * `ReadingLayout.token` — the app's `ReaderLayout` enum name, and the locked
   * grammar for `?layout=` in shareable links. Reading it off the DOM is what
   * keeps this file from carrying a second table of layout names.
   */
  var STORAGE_KEY = 'wisdom.layout';
  var radios = document.querySelectorAll('input[name="layout"]');

  function applyLayout(token) {
    if (!token) return false;
    for (var i = 0; i < radios.length; i++) {
      if (radios[i].value === token) {
        radios[i].checked = true;
        return true;
      }
    }
    return false; /* Lenient by contract: an unknown token leaves the page on
                   * its baked default rather than blanking the text. A link
                   * from a future build must never render an empty page. */
  }

  /* localStorage throws in Safari private mode and wherever a reader has
   * turned site data off. A remembered layout is a convenience; losing the
   * whole script — search included — over it is not a trade worth making.
   */
  function remembered() {
    try {
      return window.localStorage.getItem(STORAGE_KEY);
    } catch (e) {
      return null;
    }
  }

  function remember(token) {
    try {
      window.localStorage.setItem(STORAGE_KEY, token);
    } catch (e) {
      /* ignored */
    }
  }

  if (radios.length) {
    /* The URL wins over the remembered choice: a shared link is someone saying
     * "read it like this", and honouring a local preference instead would make
     * one link show two different pages to two people.
     */
    var fromUrl = null;
    try {
      fromUrl = new URLSearchParams(window.location.search).get('layout');
    } catch (e) {
      fromUrl = null;
    }

    if (applyLayout(fromUrl)) {
      remember(fromUrl);
    } else {
      applyLayout(remembered());
    }

    for (var r = 0; r < radios.length; r++) {
      radios[r].addEventListener('change', function () {
        if (this.checked) remember(this.value);
      });
    }
  }

  /* ===================================================================== *
   * 2 · Search                                                            *
   * ===================================================================== */

  var trigger = document.getElementById('search-open');
  var dialog = document.getElementById('search');
  if (!trigger || !dialog || typeof dialog.showModal !== 'function') return;

  var field = document.getElementById('search-q');
  var status = document.getElementById('search-status');
  var list = document.getElementById('search-results');

  /* Everything the generator hands this file, and all of it off one element:
   * the trigger is a button with a label, and the dialog is where the search
   * contract lives. */
  var INDEX_URL = dialog.getAttribute('data-index');
  var BASE = dialog.getAttribute('data-base');
  var TEXT = {
    loading: dialog.getAttribute('data-loading'),
    empty: dialog.getAttribute('data-empty'),
    error: dialog.getAttribute('data-error'),
    /* `{n}` matches, and the same with `{shown}` of them drawn. */
    count: dialog.getAttribute('data-count'),
    countCapped: dialog.getAttribute('data-count-capped')
  };

  /* The commentary marker — a piece of a name, not a message. See MARKED. */
  var MARKER = dialog.getAttribute('data-marker');

  /* Row layout, mirroring `search_index.dart`. Named rather than indexed
   * inline, so a field-order change is one edit here instead of a hunt through
   * the matcher — and a wrong guess reads as a wrong name rather than `r[2]`.
   */
  var KEY = 0, PALI = 1, SINHALA = 2, PARENT = 3, CHAPTER = 4, MARKED = 5;

  /* Same four fields for the folded copies built at load, and named for the
   * same reason — more so, if anything: this array is built in one place and
   * read in another, so `row[2]` here is an offset only the loop remembers.
   */
  var F_PALI = 0, F_SINHALA = 1, F_PALI_START = 2, F_SINHALA_START = 3;

  var MAX_RESULTS = 50;
  var PATH_DEPTH = 2; /* nearest ancestors shown under a result */

  /* How long the index may take before the wait is worth saying out loud, and
   * how long before it counts as never arriving. See [load] for both.
   */
  var LOADING_DELAY_MS = 200;
  var LOAD_TIMEOUT_MS = 15000;

  var rows = null;       /* the fetched index */
  var normalized = null; /* [paliFolded, siFolded, paliStart, siStart] per row */
  var loading = false;
  var failed = false;
  var loadingTimer = null; /* pending "loading" message, if one is owed */

  /* The one transform that makes a typed query and a stored name comparable.
   *
   * A transcription of `removeConjunctFormatting` + `shortenVowels`
   * (packages/wisdom_shared/lib/src/text/pali_conjuncts.dart:263,168):
   *
   *   - strip ZWJ (U+200D) and ZWNJ (U+200C). The index ships welded Pali,
   *     whose touching ZWJ nobody types, and Sinhala names carrying ligature
   *     ZWJ a reader may or may not type. Removing it from both sides is what
   *     lets either spelling find either name.
   *   - fold ේ→ෙ and ෝ→ො. A no-op on today's data — 0 of 16,355 Pali names
   *     carry the long vowels — and insurance against an upstream re-sync that
   *     introduces them, since the app's own Pali rendering folds them and a
   *     reader would then be typing what they saw.
   *
   * The zero-width pair is written as escapes. As literals they are invisible
   * in the source and in every diff of it, so a deletion would look like no
   * change at all — and the failure it causes (search quietly missing welded
   * names) looks like a data problem, not a one-character edit.
   */
  var ZERO_WIDTH = /[\u200c\u200d]/g;
  var LONG_E = /ේ/g;
  var LONG_O = /ෝ/g;

  function fold(s) {
    return s
      .replace(ZERO_WIDTH, '')
      .replace(LONG_E, 'ෙ')
      .replace(LONG_O, 'ො');
  }

  /* Where a name actually begins, past the ordinal the book prints in front of
   * it — "5. මඞ්ගලසුත්තං" begins at 3.
   *
   * ## Why this is not cosmetic
   *
   * **7,986 of the 16,355 Pali names start with a digit**, and 8,012 of the
   * Sinhala ones. Ranked on the raw string, a search for මඞ්ගල finds the
   * Maṅgala Sutta only as a mid-string match and sorts it *below* every prefix
   * hit — which is how the first build of this file put a commentary
   * sub-section (මඞ්ගලපඤ්හසමුට්ඨානකථා) above the most famous sutta in the
   * Khuddakapāṭha. Nobody types the ordinal, so on the corpus's most-searched
   * names the prefix bucket was doing the opposite of its job.
   *
   * An offset rather than a second stripped string: the number stays matchable
   * (a reader scanning "12." in a vagga list is doing something reasonable) and
   * the row still *displays* the name the printed page carries. Only the
   * question "does the query start this name" moves past it.
   *
   * Shapes measured across the corpus: `5. `, `1-2. `, `4 `, `5-8 ` — a run of
   * digits, optionally a hyphenated second run, then dots or spaces. 15,803 of
   * the 32,710 names match it and none is emptied by it. The 195 that still
   * begin with a digit afterwards are names that are *only* a number, or odd
   * forms like `7-5, 6`; they have no name proper to rank and are left at 0.
   */
  var ORDINAL = /^[0-9]+(-[0-9]+)?[.\s]+/;

  function nameStart(s) {
    var m = s.match(ORDINAL);
    if (!m) return 0;
    /* A name that is nothing but its number keeps offset 0 — pointing past the
     * end of the string would make every query miss it. */
    return s.length > m[0].length ? m[0].length : 0;
  }

  function setStatus(text) {
    status.textContent = text;
  }

  /* The name as the page this row links to heads itself: 6,674 commentary rows
   * append the marker, and without it those results are identical to their
   * canon twins, trail and all.
   *
   * `pathFor` deliberately does not call this — the site's breadcrumb leaves
   * the marker off a trail, and marking two ancestors as well would print the
   * same word three times in one result.
   */
  function displayName(row) {
    return row[MARKED] ? row[PALI] + ' ' + MARKER : row[PALI];
  }

  /* `<base><key>` for a node with its own page; `<base><chapter>#<key>` for the
   * 1,603 that live inside a grouped chapter file. Getting this wrong is
   * invisible in testing and 404s in production, which is why `chapterIdx` is
   * in the index at all.
   *
   * Extensionless, matching every other link the site emits — `tipitakaUrl` in
   * Dart, and the URL grammar the app's deep-link codec parses.
   */
  function hrefFor(row) {
    if (row[CHAPTER] < 0) return BASE + row[KEY];
    return BASE + rows[row[CHAPTER]][KEY] + '#' + row[KEY];
  }

  /* The nearest few ancestors, outermost first — "දීඝනිකාය › සීලක්ඛන්ධ", and
   * bare of the commentary marker for the reason [displayName] gives.
   *
   * Two levels, not the whole trail: the full path to a leaf runs five or six
   * names and would wrap to three lines under every result, burying the names
   * the reader is scanning. Two is what separates the 2,216 leaves that share a
   * name with another leaf.
   */
  function pathFor(row) {
    var names = [];
    var at = row[PARENT];
    while (at >= 0 && names.length < PATH_DEPTH) {
      names.unshift(rows[at][PALI]);
      at = rows[at][PARENT];
    }
    return names.join(' › ');
  }

  /* Substring over both name columns, exact prefix first.
   *
   * No fuzzy matching and no scoring library. A reader looking for මඞ්ගලසුත්තං
   * types the start of it; the case worth designing for is a name matching in
   * the middle — a vagga inside a longer compound — which plain `indexOf`
   * already covers.
   *
   * "Prefix" means the start of the *name*, which is not always the start of
   * the string — see [nameStart]. A hit at either counts.
   *
   * **Every row is looked at, even once both buckets are full**, so `total` is
   * exact. Stopping at the cap left the status line announcing 50 whether 50
   * or 4,000 matched; scanning on costs an `indexOf` pair per remaining row.
   */
  function search(query) {
    var prefix = [];
    var contains = [];
    var total = 0;
    for (var i = 0; i < rows.length; i++) {
      var row = normalized[i];
      var pali = row[F_PALI].indexOf(query);
      var si = row[F_SINHALA].indexOf(query);
      if (pali < 0 && si < 0) continue;
      total++;
      if (
        pali === 0 ||
        pali === row[F_PALI_START] ||
        si === 0 ||
        si === row[F_SINHALA_START]
      ) {
        if (prefix.length < MAX_RESULTS) prefix.push(i);
      } else if (contains.length < MAX_RESULTS) {
        contains.push(i);
      }
    }
    return {
      matches: prefix.concat(contains).slice(0, MAX_RESULTS),
      total: total
    };
  }

  /* Built with DOM calls, not an innerHTML string.
   *
   * Node names are corpus data, and the one thing a name must never do is
   * become markup. `textContent` cannot; a template string one careless edit
   * later can. It is also faster here — 50 rows, no reparse.
   */
  function draw(matches) {
    list.textContent = '';
    var frag = document.createDocumentFragment();
    for (var i = 0; i < matches.length; i++) {
      var row = rows[matches[i]];
      var li = document.createElement('li');
      var a = document.createElement('a');
      a.href = hrefFor(row);

      var name = document.createElement('span');
      name.className = 'search-name';
      name.textContent = displayName(row);
      a.appendChild(name);

      var path = pathFor(row);
      if (path) {
        var crumb = document.createElement('span');
        crumb.className = 'search-path';
        crumb.textContent = path;
        a.appendChild(crumb);
      }

      li.appendChild(a);
      frag.appendChild(li);
    }
    list.appendChild(frag);
  }

  function run() {
    if (!rows) return;
    var query = fold(field.value).trim();
    if (!query) {
      list.textContent = '';
      setStatus('');
      return;
    }
    var found = search(query);
    draw(found.matches);
    if (!found.total) {
      setStatus(TEXT.empty);
    } else if (found.total > found.matches.length) {
      setStatus(
        TEXT.countCapped
          .replace('{n}', found.total)
          .replace('{shown}', found.matches.length)
      );
    } else {
      setStatus(TEXT.count.replace('{n}', found.total));
    }
  }

  /* Both ways a fetch can end. Clearing the pending message is the part worth
   * having a function for: forget it in one branch and the status line
   * overwrites an answer with "loading" a moment after the answer arrived.
   */
  function settled() {
    loading = false;
    if (loadingTimer !== null) {
      window.clearTimeout(loadingTimer);
      loadingTimer = null;
    }
  }

  /* Fetched on first open, never on page load. The index is 254 KB gzipped —
   * more than every other byte a page serves put together — and most readers
   * arrive from a search engine, read one sutta and leave without opening it.
   */
  function load() {
    if (rows || loading || failed) return;
    loading = true;

    /* Announced only if there is actually a wait. The fetch is per document,
     * but `_headers` serves the index `immutable` under a hashed URL, so from
     * the second page on it comes out of the browser's cache with no round
     * trip at all — and a message drawn and pulled back inside 200 ms reads as
     * the dialog glitching, not as it working. Late is the only time "loading"
     * is information.
     */
    loadingTimer = window.setTimeout(function () {
      loadingTimer = null;
      setStatus(TEXT.loading);
    }, LOADING_DELAY_MS);

    /* A request that never settles — a phone on a dead connection holds one
     * open indefinitely — used to leave `loading` true for the life of the
     * page, and reopening clears only `failed`, so the dialog could never try
     * again. Aborting turns the hang into the error path that already exists
     * and is already retried on the next open.
     */
    var abort = null;
    if (typeof AbortController === 'function') {
      abort = new AbortController();
      window.setTimeout(function () {
        /* A no-op once the fetch has settled. */
        abort.abort();
      }, LOAD_TIMEOUT_MS);
    }

    fetch(INDEX_URL, abort ? { signal: abort.signal } : undefined)
      .then(function (response) {
        if (!response.ok) throw new Error(response.status);
        return response.json();
      })
      .then(function (data) {
        rows = data;
        /* Folded once, here, rather than per keystroke: 16,355 rows × 2 names
         * is ~30 ms once against ~30 ms on every character typed. The two
         * offsets ride along for the same reason — `[paliFolded, siFolded,
         * paliNameStart, siNameStart]`.
         */
        normalized = new Array(rows.length);
        for (var i = 0; i < rows.length; i++) {
          /* The *displayed* name, so typing අට්ඨකථා finds all 6,731 commentary
           * nodes and not just the 57 named with it upstream. */
          var pali = fold(displayName(rows[i]));
          var si = fold(rows[i][SINHALA]);
          normalized[i] = [pali, si, nameStart(pali), nameStart(si)];
        }
        settled();
        setStatus('');
        run();
      })
      .catch(function () {
        settled();
        failed = true;
        setStatus(TEXT.error);
      });
  }

  trigger.hidden = false;
  trigger.addEventListener('click', function () {
    dialog.showModal();
    field.focus();
    /* Opening again is asking again. Nothing else clears this, so one dropped
     * connection used to mean a permanent error message. */
    failed = false;
    load();
  });

  field.addEventListener('input', run);

  /* A result click closes the dialog. Usually the navigation does that for us,
   * but not for a `<chapter>#<leaf>` link clicked from that same chapter: the
   * fragment change reloads nothing, so the panel sits there looking like a
   * dead click while the `:has(:target)` filter runs behind the backdrop.
   */
  list.addEventListener('click', function (event) {
    if (event.target.closest('a')) dialog.close();
  });

  /* By id, like every other element here. Reaching for `.search-close` made a
   * class the stylesheet owns into a handle this file depends on, and renaming
   * it would have left the button drawn, focusable and dead.
   */
  document
    .getElementById('search-close')
    .addEventListener('click', function () {
      dialog.close();
    });

  /* Clicking the backdrop closes. `::backdrop` is not an element and takes no
   * listener of its own, so a backdrop click lands on the dialog — which means
   * the only way to tell the two apart is where the pointer was.
   */
  dialog.addEventListener('click', function (event) {
    if (event.target !== dialog) return;
    var box = dialog.getBoundingClientRect();
    var inside =
      event.clientX >= box.left &&
      event.clientX <= box.right &&
      event.clientY >= box.top &&
      event.clientY <= box.bottom;
    if (!inside) dialog.close();
  });

  /* Down out of the field and through the results, and back up into it.
   *
   * Results are anchors, so Tab and Enter already work; this is the arrow
   * behaviour every search field has trained readers to expect, and without it
   * reaching the third result means three Tabs.
   */
  dialog.addEventListener('keydown', function (event) {
    if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') return;
    var links = list.querySelectorAll('a');
    if (!links.length) return;
    event.preventDefault();

    if (document.activeElement === field) {
      /* Up from the field stays in the field — there is nothing above it. */
      if (event.key === 'ArrowDown') links[0].focus();
      return;
    }

    var at = -1;
    for (var i = 0; i < links.length; i++) {
      if (links[i] === document.activeElement) { at = i; break; }
    }
    /* Focus is elsewhere in the dialog — the close button, or nowhere. The
     * keypress was already swallowed above, so returning would eat the arrow
     * and move nothing; enter the list at the end the key points to. */
    if (at < 0) {
      if (event.key === 'ArrowDown') {
        links[0].focus();
      } else {
        field.focus();
      }
      return;
    }

    var next = at + (event.key === 'ArrowDown' ? 1 : -1);
    if (next < 0) {
      field.focus(); /* back up out of the list */
    } else if (next < links.length) {
      links[next].focus();
    }
  });
})();
