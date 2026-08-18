/// The search dialog: a trigger in the toolbar and a `<dialog>` at the end of
/// the body. The script that drives it is `site.js`, which the shell emits —
/// see `document_shell.dart`, and note it is not a *search* script: it owns
/// `?layout=` too.
///
/// Mirrors: lib/presentation/widgets/search/search_bar.dart — the app's search
/// field. The *strings* are shared with it; the mechanism is not, because the
/// app searches SQLite FTS over the text and this searches names in an array.
///
/// ## Why a modal and not a page
///
/// A `/search` page would need the index on load, cost a navigation away from
/// what the reader is reading, and give a crawler a page of `FIGURES.treeNodes`
/// rows with no content on it. The modal is opened from the bar, answers, and
/// gets out of the way. `showModal()` also brings the focus trap, `::backdrop`
/// and Esc-to-close that a hand-rolled overlay has to reimplement badly.
///
/// ## The trigger ships `hidden`
///
/// Everything else on this site works with JavaScript off (C8). This does not
/// — there is no way to search that many names without running code — so the
/// control is emitted hidden and `site.js` unhides it. A reader with no JS
/// sees no button rather than a button that does nothing, and the markup stays
/// deterministic instead of being injected from a string at runtime.
library;

import '../domain/site_page.dart';
import 'entry_renderer.dart';
import 'node_labels.dart';

/// Accessible name of the trigger, and of the dialog it opens.
///
/// The app's `searchPlaceholder` (`app_si.arb:30`) — "search the Tipitaka".
/// The trailing ellipsis is the app's and is kept: on a control it is the
/// long-standing convention for "this opens something rather than doing it",
/// which is exactly true here.
const String searchLabel = 'ත්‍රිපිටකයේ සොයන්න...';

/// Placeholder inside the field. The app's `searchHint` (`app_si.arb:68`), in
/// the same role — `search_bar.dart:278` passes it as `hintText`.
const String searchFieldHint = 'සෙවුම් පදය ඇතුළත් කරන්න';

/// The app's `noResultsFound` (`app_si.arb:32`).
const String searchNoResults = 'ප්‍රතිඵල හමු නොවීය';

/// The app's `close` (`app_si.arb:66`).
const String searchCloseLabel = 'වසන්න';

/// Shown while the index is in flight.
///
/// The app's `loading` (`app_si.arb:22`). It earns its place here in a way it
/// does not in the app: the index is a real download over whatever connection
/// the reader has, and a modal that opens to an empty list reads as a broken
/// modal rather than a busy one.
const String searchLoading = 'පූරණය වෙමින්...';

/// Shown when the index cannot be fetched at all.
///
/// The app's `errorLoadingSearch` (`app_si.arb:178`) — same failure, same
/// words: the results could not be loaded.
const String searchError = 'ප්‍රතිඵල පූරණය කිරීමේ දෝෂයකි';

/// How many names matched; `{n}` is the number. `role="status"` announced a
/// bare "50" without it — no noun, and no way to tell an answer from a ceiling.
///
/// The app has no equivalent, so the wording is tipitaka.lk's title search
/// (`src/views/TSearch.vue:66`), shortened, with "වචන" → "නම්".
const String searchResultCount = 'ගැළපෙන නම් {n}ක්';

/// Same when more matched than the dialog draws; `{shown}` is the cap.
/// tipitaka.lk's two-sentence form (`TSearch.vue:68`) in one line. `{n}` stays
/// exact — the scan counts every row before it stops collecting.
const String searchResultCountCapped = 'ගැළපෙන නම් {n}ක් — මුල් {shown} පහත';

/// DOM ids, written once here and read by `site.js` through these names
/// alone. The stylesheet styles classes, not ids, so a rename here is a change
/// in exactly two files.
const String searchDialogId = 'search';
const String searchTriggerId = 'search-open';
const String searchFieldId = 'search-q';
const String searchStatusId = 'search-status';
const String searchResultsId = 'search-results';
const String searchCloseId = 'search-close';

/// The toolbar button.
///
/// Shares its box with `.up` — one CSS rule names both — and sits beside it, so
/// the two read as one set of controls. `hidden` until the script runs.
///
/// It carries no `data-` attributes. The two it used to hold — the index URL
/// and the link prefix — are the dialog's business, not the button's, and
/// keeping them here would mean threading a build-time URL through `toolbar`
/// and `breadcrumb` to reach a control that never uses it.
///
/// `aria-haspopup="dialog"` so the label is not the only thing saying what the
/// button does: it is announced as opening something, which is the difference
/// between a reader expecting a panel and a reader expecting to be navigated
/// away from the sutta they are on. No `aria-expanded` beside it — that is for
/// a control that also closes what it opened, and this one does not; the
/// dialog owns its own close.
String searchTrigger() =>
    '<button class="search-trigger" id="$searchTriggerId" type="button" '
    'hidden aria-haspopup="dialog" '
    'title="$searchLabel" aria-label="$searchLabel">$_searchGlyph</button>';

/// The modal itself, emitted at the end of every page's body.
///
/// Empty of results by design: nothing here is server-rendered, so the markup
/// is identical on every page (`FIGURES.realPages`) and compresses to nothing
/// after the first.
///
/// `<ul>` and not a bare list of anchors — a screen reader announces "list, N
/// items", which is the count a searcher wants and the one thing this markup
/// can say for free.
///
/// The status line is `role="status"`, so "loading", "no results" and the match
/// count are announced without moving focus off the field the reader is still
/// typing in.
///
/// Every string it can show arrives as a `data-` attribute, and so does every
/// URL, for the same reason: the script writes them into the page but must not
/// *own* them, or the site would hold Sinhala — and its URL grammar — in two
/// places. `data-marker` is a piece of a *name* rather than a message, so it is
/// welded (D1) to match the `<h1>` of the page it links to; which rows take it
/// is the index's column 6.
///
/// [indexUrl] is `SiteAssets.searchIndex`, carrying the hash that pairs this
/// index with the script that reads it. `data-base` is
/// [TipitakaLink.pathSegment]'s one spelling, which is what keeps a result link
/// from drifting off the URL grammar the rest of the site — and the app's
/// deep-link codec — agree on.
///
/// Both sit on the dialog rather than the trigger so that everything `site.js`
/// is handed comes off one element.
String searchDialog(String indexUrl) => '<dialog class="search" '
    'id="$searchDialogId" '
    'aria-label="$searchLabel" '
    'data-index="$indexUrl" data-base="${tipitakaUrl('')}" '
    'data-loading="$searchLoading" data-empty="$searchNoResults" '
    'data-error="$searchError" '
    'data-count="$searchResultCount" '
    'data-count-capped="$searchResultCountCapped" '
    'data-marker="${weldTitle(commentaryMarker)}">'
    '<div class="search-head">'
    // `type="search"` for the platform clear button and the right virtual
    // keyboard. Autocomplete and the browser's own history are off: they offer
    // Latin form-filling suggestions over a Sinhala field, covering the results
    // the dialog is drawing underneath.
    '<input class="search-field" id="$searchFieldId" type="search" '
    'placeholder="$searchFieldHint" aria-label="$searchFieldHint" '
    'autocomplete="off" autocorrect="off" spellcheck="false">'
    '<button class="search-close" id="$searchCloseId" type="button" '
    'title="$searchCloseLabel" aria-label="$searchCloseLabel">'
    '$_closeGlyph</button>'
    '</div>'
    '<p class="search-status" id="$searchStatusId" role="status"></p>'
    '<ul class="search-results" id="$searchResultsId"></ul>'
    '</dialog>';

/// Inline SVG on the same terms as the layout and up icons: `currentColor`, no
/// second request, drawn to the same 1.6 stroke so the bar reads as one set.
const String _searchGlyph = '<svg class="search-icon" viewBox="0 0 24 24" '
    'fill="none" stroke="currentColor" stroke-width="1.6" '
    'stroke-linecap="round" aria-hidden="true">'
    '<circle cx="11" cy="11" r="7"/><path d="M20 20l-4.3-4.3"/></svg>';

const String _closeGlyph = '<svg class="search-close-icon" viewBox="0 0 24 24" '
    'fill="none" stroke="currentColor" stroke-width="1.6" '
    'stroke-linecap="round" aria-hidden="true">'
    '<path d="M6 6l12 12"/><path d="M18 6L6 18"/></svg>';
