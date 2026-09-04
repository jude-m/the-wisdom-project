import 'package:test/test.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

/// Guards the universal-link codec: `/tipitaka/<nodeKey>[?e=<page>[.<entry>]]`.
///
/// This is the app's *only* entry point for OS deep links, shared URLs and
/// research citations, and it had no coverage at all — which is how the dotted
/// commentary keys stayed broken. Parsing is deliberately lenient (a malformed
/// shared URL returns null, never throws), so almost every case here asserts
/// either a successful decode or a clean null.
void main() {
  group('accepts the shapes real links come in', () {
    test('https on either production origin — they share one path', () {
      // Topology decision (2026-07-23): the static site is the apex and the
      // Flutter app is `app.`, with no `/app/` path prefix on either. The same
      // path therefore has to resolve identically on both hosts, which is what
      // lets the share button stay ignorant of which surface it is on.
      const expected = TipitakaLink(nodeKey: 'sn-2-3-1-3');
      expect(
        TipitakaLink.tryParse('https://sammaditthi.net/tipitaka/sn-2-3-1-3'),
        expected,
      );
      expect(
        TipitakaLink.tryParse('https://app.sammaditthi.net/tipitaka/sn-2-3-1-3'),
        expected,
      );
    });

    test('http on any host, so localhost and LAN boxes work', () {
      expect(
        TipitakaLink.tryParse('http://192.168.1.200:8080/tipitaka/sn-2-3'),
        const TipitakaLink(nodeKey: 'sn-2-3'),
      );
    });

    test('the sammaditthi:// dev scheme, where "tipitaka" parses as the host', () {
      expect(
        TipitakaLink.tryParse('sammaditthi://tipitaka/sn-2-3?e=12.4'),
        const TipitakaLink(nodeKey: 'sn-2-3', pageIndex: 12, entryIndex: 4),
      );
    });

    test('a base-href prefix, for the web app served under /app', () {
      expect(
        TipitakaLink.tryParse('https://host/app/tipitaka/sn-2-3'),
        const TipitakaLink(nodeKey: 'sn-2-3'),
      );
    });

    test('a trailing slash, which browsers and chat apps add freely', () {
      expect(
        TipitakaLink.tryParse('https://host/tipitaka/sn-2-3/'),
        const TipitakaLink(nodeKey: 'sn-2-3'),
      );
    });

    test('an uppercased nodeKey, normalised down', () {
      expect(
        TipitakaLink.tryParse('https://host/tipitaka/SN-2-3')?.nodeKey,
        'sn-2-3',
      );
    });

    test('surrounding whitespace, since links arrive via the clipboard', () {
      expect(
        TipitakaLink.tryParse('  https://host/tipitaka/sn-2-3\n'),
        const TipitakaLink(nodeKey: 'sn-2-3'),
      );
    });

    test('an uppercased custom-scheme link, because the host normalises', () {
      // Not a contradiction with the rejected `/TIPITAKA/` case below: RFC 3986
      // makes scheme and host case-insensitive but the *path* case-sensitive,
      // and in `sammaditthi://tipitaka/x` the segment is the host. So the same
      // word is forgiving in one form and exact in the other, by spec.
      expect(
        TipitakaLink.tryParse('SAMMADITTHI://TIPITAKA/SN-2-3'),
        const TipitakaLink(nodeKey: 'sn-2-3'),
      );
    });

    test('an empty path segment, which sloppy concatenation produces', () {
      expect(
        TipitakaLink.tryParse('https://host/tipitaka//sn-2-3'),
        const TipitakaLink(nodeKey: 'sn-2-3'),
      );
    });

    test('a custom-scheme link with an unexpected host, treated as a prefix', () {
      // Only the last two segments are load-bearing, so `sammaditthi://foo/…`
      // resolves exactly like the `/app/` base-href case above.
      expect(
        TipitakaLink.tryParse('sammaditthi://foo/tipitaka/sn-2-3'),
        const TipitakaLink(nodeKey: 'sn-2-3'),
      );
    });
  });

  group('dotted commentary keys resolve (regression)', () {
    // The bug: `_nodeKeyPattern` allowed only `[a-z0-9]` runs joined by
    // hyphens, so every key with a dot inside a segment was rejected before it
    // ever reached the tree. 53 real nodes have that shape — all under
    // `atta-ap-*` and `atta-vp-*`, 50 of them leaves — and deep links to them
    // silently resolved to null. These three keys are taken from tree.json.
    //
    // The full build → parse round trip for a dotted key lives in the
    // "round trips" group, so it is exercised in both URL forms.
    for (final key in const [
      'atta-ap-dhs-2-1-1.1',
      'atta-vp-cv-3-2.5',
      'atta-ap-vbh-6-1.91',
    ]) {
      test('$key parses', () {
        expect(
          TipitakaLink.tryParse('https://host/tipitaka/$key')?.nodeKey,
          key,
        );
      });
    }
  });

  group('a nodeKey-shaped fragment names the target', () {
    // A folded leaf's URL is `…/tipitaka/<pageKey>#<leafKey>`
    // (docs/todo/web-strategy/deep-linking-and-shareable-urls.md, "Grouped-sutta
    // fragments" — LOCKED). The path names the file, the fragment names the
    // sutta, and the sutta is what the reader asked for.
    test('the fragment wins over the path key', () {
      expect(
        TipitakaLink.tryParse(
          'https://host/tipitaka/sn-2-3#atta-ap-dhs-2-1-1.1',
        )?.nodeKey,
        'atta-ap-dhs-2-1-1.1',
      );
    });

    test('and the path key is kept as the page serving it', () {
      expect(
        TipitakaLink.tryParse('https://host/tipitaka/sn-2-1-10-3#sn-2-1-10-4'),
        const TipitakaLink(nodeKey: 'sn-2-1-10-4', pageKey: 'sn-2-1-10-3'),
      );
    });

    test('a fragment does not disturb the position', () {
      expect(
        TipitakaLink.tryParse('https://host/tipitaka/sn-2-3?e=12.4#an-2-64'),
        const TipitakaLink(
          nodeKey: 'an-2-64',
          pageKey: 'sn-2-3',
          pageIndex: 12,
          entryIndex: 4,
        ),
      );
    });

    test('a fragment that cannot be a nodeKey leaves the path key alone', () {
      for (final url in [
        'https://host/tipitaka/sn-2-3#note_4', // underscore is not a separator
        'https://host/tipitaka/sn-2-3#', // empty
      ]) {
        expect(TipitakaLink.tryParse(url), const TipitakaLink(nodeKey: 'sn-2-3'),
            reason: url);
      }
    });

    test('a via_ fragment names the door instead of the target', () {
      // What the site writes on a canon sutta whose vaṇṇanā is shared with the
      // suttas after it. The path is the page — usually the *chapter*, since a
      // merged vaṇṇanā is normally folded onto one — so it cannot name the
      // vaṇṇanā, and the fragment says which sutta was left rather than which
      // node to open. Turning one into the other needs the tree, so the codec
      // carries it and `openTipitakaLinkProvider` resolves it.
      expect(
        TipitakaLink.tryParse(
            'https://host/tipitaka/atta-sn-2-3-1#via_sn-2-3-1-3'),
        const TipitakaLink(
            nodeKey: 'atta-sn-2-3-1', originKey: 'sn-2-3-1-3'),
      );
    });

    test('a via_ payload that cannot name a node names no door', () {
      // The prefix alone does not make a fragment an origin. `parse` rejects a
      // *path* that cannot be a nodeKey, and the payload is held to the same
      // pattern, so a link never reports a door that could not be walked
      // through. The link itself survives: the path is still a valid address,
      // and a fragment the grammar cannot read has always been ignorable.
      for (final fragment in ['via_', 'via_%20junk', 'via_../etc', 'via_a_b']) {
        expect(
          TipitakaLink.tryParse('https://host/tipitaka/atta-sn-2-3#$fragment'),
          const TipitakaLink(nodeKey: 'atta-sn-2-3'),
          reason: '#$fragment reported an origin key',
        );
      }
    });

    test('a nodeKey-shaped fragment is still a target, not a door', () {
      // `via-sn-2-3` — hyphen, not underscore — is a legal nodeKey shape, and
      // the grammar must keep reading it as one. This is the whole reason the
      // marker id uses an underscore.
      expect(
        TipitakaLink.tryParse('https://host/tipitaka/atta-sn-2-3-1#via-sn-2-3'),
        const TipitakaLink(nodeKey: 'via-sn-2-3', pageKey: 'atta-sn-2-3-1'),
      );
    });

    test('a page anchor that happens to be key-shaped keeps both keys', () {
      // `#top` is a legal nodeKey *shape*, so the grammar cannot tell it from a
      // real leaf — and this codec deliberately knows nothing about which keys
      // exist. Both survive parsing, and the reader that has a tree resolves
      // the target first and falls back to the page (openTipitakaLinkProvider).
      expect(
        TipitakaLink.tryParse('https://host/tipitaka/sn-2-3#top'),
        const TipitakaLink(nodeKey: 'top', pageKey: 'sn-2-3'),
      );
    });

    test('a fragment repeating the path key asks for the anchor alone', () {
      // What a chapter anchored on its first leaf writes for that leaf: same
      // key both sides, and not one address written twice. Bare, that path is
      // the whole run; with the fragment it is the anchor sutta on its own.
      expect(
        TipitakaLink.tryParse('https://host/tipitaka/sn-2-3#sn-2-3'),
        const TipitakaLink(nodeKey: 'sn-2-3', pageKey: 'sn-2-3'),
      );
    });

    test('a target that owns its URL emits no fragment', () {
      expect(
        const TipitakaLink(nodeKey: 'sn-2-3').toUri('https://host').fragment,
        isEmpty,
      );
      expect(
        const TipitakaLink(nodeKey: 'sn-2-1-10-4', pageKey: 'sn-2-1-10-3')
            .toUri('https://host')
            .toString(),
        'https://host/tipitaka/sn-2-1-10-3#sn-2-1-10-4',
      );
    });

    test('round trips through both schemes', () {
      const link = TipitakaLink(
        nodeKey: 'sn-2-1-10-4',
        pageKey: 'sn-2-1-10-3',
        pageIndex: 7,
        entryIndex: 2,
      );
      expect(TipitakaLink.parse(link.toUri('https://host')), link);
      expect(TipitakaLink.parse(link.toCustomSchemeUri()), link);
    });
  });

  group('a copied file URL still resolves', () {
    // The site's own files are `<nodeKey>.html`; its links are extensionless,
    // but a URL copied from a browser served the file directly carries it.
    test('a .html suffix is tolerated on the path', () {
      expect(
        TipitakaLink.tryParse('https://host/tipitaka/sn-2-3.html')?.nodeKey,
        'sn-2-3',
      );
    });

    test('and on the page key beside a fragment', () {
      expect(
        TipitakaLink.tryParse(
          'https://host/tipitaka/sn-2-1-10-3.html#sn-2-1-10-4',
        ),
        const TipitakaLink(nodeKey: 'sn-2-1-10-4', pageKey: 'sn-2-1-10-3'),
      );
    });

    test('but nothing we build writes one', () {
      expect(
        const TipitakaLink(nodeKey: 'sn-2-3').toUri('https://host').toString(),
        'https://host/tipitaka/sn-2-3',
      );
    });
  });

  group('rejects what is not one of our links', () {
    const rejected = <String, String>{
      'ftp://host/tipitaka/sn-2-3': 'unsupported scheme',
      'mailto:someone@example.com': 'no scheme we handle',
      'https://host/sn-2-3': 'no /tipitaka/ segment',
      'https://host/tipitaka': 'nodeKey missing',
      'https://host/tipitaka/sn-2-3/extra': 'nodeKey is not the last segment',
      'https://host/TIPITAKA/sn-2-3': 'path segments are case-sensitive',
      'https://host/tipitaka/sn_2_3': 'underscore is not a separator',
      'https://host/tipitaka/sn--2': 'separators do not repeat',
      'https://host/tipitaka/-sn-2': 'must start with an alphanumeric run',
      'https://host/tipitaka/sn-2-': 'must end with an alphanumeric run',
      'https://host/tipitaka/සන': 'non-ASCII is not a nodeKey',
      'not a uri at all': 'no scheme',
    };

    rejected.forEach((input, why) {
      test('$why — "$input"', () {
        expect(TipitakaLink.tryParse(input), isNull);
      });
    });

    test('a URI too malformed for Uri.tryParse returns null, never throws', () {
      // This is the only thing that reaches the `Uri.tryParse` guard, and it
      // takes a broken *authority* to get there. Dart parses far more than you
      // would expect: "not a uri at all" above is a valid relative reference
      // (rejected one line later, for having no scheme) and even a bad percent
      // escape like `%GG` parses (rejected by the nodeKey pattern).
      expect(
        TipitakaLink.tryParse('https://host:notaport/tipitaka/sn-2-3'),
        isNull,
      );
      expect(TipitakaLink.tryParse('http://[::1/tipitaka/sn-2-3'), isNull);
    });
  });

  group('the ?e= position parses, or is dropped without taking the link', () {
    TipitakaLink? linkWith(String query) =>
        TipitakaLink.tryParse('https://host/tipitaka/sn-2-3?e=$query');

    ({int? page, int? entry}) positionIn(TipitakaLink? link) =>
        (page: link?.pageIndex, entry: link?.entryIndex);

    ({int? page, int? entry}) positionOf(String query) =>
        positionIn(linkWith(query));

    test('"12.4" is page 12, entry 4', () {
      expect(positionOf('12.4'), (page: 12, entry: 4));
    });

    test('"12" is page 12 with no entry', () {
      expect(positionOf('12'), (page: 12, entry: null));
    });

    test('"0.0" is a real position, not an absent one', () {
      expect(positionOf('0.0'), (page: 0, entry: 0));
    });

    test('a trailing dot keeps the page and drops the entry', () {
      expect(positionOf('12.'), (page: 12, entry: null));
    });

    test('a bad entry keeps the page', () {
      // Only the *page* is load-bearing: an unreadable entry degrades to the
      // top of that page rather than throwing the whole position away.
      expect(positionOf('12.x'), (page: 12, entry: null));
      expect(positionOf('1.-2'), (page: 1, entry: null));
    });

    for (final bad in const ['', 'abc', '-1', '1.2.3']) {
      test('"$bad" drops the position but keeps the link', () {
        final link = linkWith(bad);
        expect(positionIn(link), (page: null, entry: null));
        // The link itself must still open — at the node's own start.
        expect(link?.nodeKey, 'sn-2-3');
      });
    }

    test('a repeated e= takes the last one', () {
      // Dart's Uri.queryParameters is a Map, so duplicates collapse last-wins.
      // Pinned because it is inherited behaviour, not a decision we made.
      expect(
        TipitakaLink.tryParse('https://host/tipitaka/sn-2-3?e=1&e=2'),
        const TipitakaLink(nodeKey: 'sn-2-3', pageIndex: 2),
      );
    });

    test('the parameter name is case-sensitive, so ?E= is not a position', () {
      expect(
        TipitakaLink.tryParse('https://host/tipitaka/sn-2-3?E=12.4'),
        const TipitakaLink(nodeKey: 'sn-2-3'),
      );
    });

    test('an unrelated query parameter is ignored', () {
      expect(
        TipitakaLink.tryParse('https://host/tipitaka/sn-2-3?utm_source=x'),
        const TipitakaLink(nodeKey: 'sn-2-3'),
      );
    });

    test('?layout= rides along untouched — it belongs to a later stage', () {
      // Documented grammar (the reading-layout decision, 2026-07-20), but no
      // code reads it yet — not the codec, and not `openTipitakaLinkProvider`
      // downstream, where the lenient token→enum mapping is meant to land. All
      // this pins is that a param we don't own cannot cost us the link *or*
      // the position, whenever that consumer does arrive.
      expect(
        TipitakaLink.tryParse('https://host/tipitaka/sn-2-3?layout=stacked'),
        const TipitakaLink(nodeKey: 'sn-2-3'),
      );
      expect(
        TipitakaLink.tryParse(
          'https://host/tipitaka/sn-2-3?e=12.4&layout=stacked',
        ),
        const TipitakaLink(nodeKey: 'sn-2-3', pageIndex: 12, entryIndex: 4),
      );
    });
  });

  group('building URLs', () {
    test('the canonical form has no query when there is no position', () {
      expect(
        const TipitakaLink(nodeKey: 'sn-2-3').toUri('https://sammaditthi.net'),
        Uri.parse('https://sammaditthi.net/tipitaka/sn-2-3'),
      );
    });

    test('page and entry are joined with a dot', () {
      expect(
        const TipitakaLink(nodeKey: 'sn-2-3', pageIndex: 12, entryIndex: 4)
            .toUri('https://sammaditthi.net'),
        Uri.parse('https://sammaditthi.net/tipitaka/sn-2-3?e=12.4'),
      );
    });

    test('a page with no entry emits the bare page', () {
      expect(
        const TipitakaLink(nodeKey: 'sn-2-3', pageIndex: 12)
            .toUri('https://sammaditthi.net'),
        Uri.parse('https://sammaditthi.net/tipitaka/sn-2-3?e=12'),
      );
    });

    test('an entry with no page emits nothing — the entry is meaningless alone', () {
      expect(
        const TipitakaLink(nodeKey: 'sn-2-3', entryIndex: 4)
            .toUri('https://sammaditthi.net'),
        Uri.parse('https://sammaditthi.net/tipitaka/sn-2-3'),
      );
    });

    test('a path on the base is preserved as a prefix', () {
      expect(
        const TipitakaLink(nodeKey: 'sn-2-3').toUri('https://host/app').toString(),
        'https://host/app/tipitaka/sn-2-3',
      );
    });

    test('a port on the base is preserved', () {
      expect(
        const TipitakaLink(nodeKey: 'sn-2-3')
            .toUri('http://localhost:8080')
            .toString(),
        'http://localhost:8080/tipitaka/sn-2-3',
      );
    });

    test('a scheme-less base trips the dev-time assert', () {
      // LINK_BASE_URL is developer-controlled, so this is caught in debug
      // rather than shipped as a silently broken share button.
      //
      // "dev-time" is literal: asserts are stripped from release builds, where
      // the same base would emit a scheme-less URL instead of throwing. This
      // test holds because `dart test` runs with asserts enabled — it pins the
      // debug guard, not a release-mode guarantee.
      expect(
        () => const TipitakaLink(nodeKey: 'sn-2-3').toUri('sammaditthi.net'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('the custom scheme puts "tipitaka" in the host position', () {
      expect(
        const TipitakaLink(nodeKey: 'sn-2-3', pageIndex: 12)
            .toCustomSchemeUri()
            .toString(),
        'sammaditthi://tipitaka/sn-2-3?e=12',
      );
    });
  });

  group('round trips', () {
    const links = [
      TipitakaLink(nodeKey: 'sn-2-3-1-3'),
      TipitakaLink(nodeKey: 'an-1'),
      TipitakaLink(nodeKey: 'atta-ap-dhs-2-1-1.1'),
      TipitakaLink(nodeKey: 'atta-ap-dhs-2-1-1.1', pageIndex: 7, entryIndex: 2),
      TipitakaLink(nodeKey: 'sn-2-3', pageIndex: 0),
      TipitakaLink(nodeKey: 'sn-2-3', pageIndex: 0, entryIndex: 0),
      TipitakaLink(nodeKey: 'sn-2-3', pageIndex: 412, entryIndex: 17),
      // The two-key forms. Every row above leaves `pageKey` null, so the whole
      // path-and-fragment half of the grammar — the half `SitePlan.servingLink`
      // builds and the static site writes into every grouped chapter's links —
      // used to round-trip nowhere.
      //
      // A folded leaf: the path is the chapter carrying it, the fragment is the
      // sutta the reader asked for.
      TipitakaLink(nodeKey: 'sn-2-3-1-3', pageKey: 'sn-2-3-1'),
      // The same key on both sides, which is one address and not one written
      // twice: a chapter anchored on its first leaf, asked for that leaf alone
      // rather than for the whole run. `parse` used to collapse this form and
      // the constructor used to refuse to hold it, so it is the shape most
      // likely to be normalised away again by mistake.
      TipitakaLink(nodeKey: 'sn-2-3-1', pageKey: 'sn-2-3-1'),
      // Both keys and a position — what a research citation deep link carries.
      TipitakaLink(
          nodeKey: 'sn-2-3-1-3',
          pageKey: 'sn-2-3-1',
          pageIndex: 4,
          entryIndex: 1),
      // The origin form: the other user of the fragment, and the reason
      // `pageKey` and `originKey` exclude each other.
      TipitakaLink(nodeKey: 'atta-sn-2-3-1', originKey: 'sn-2-3-1-3'),
      TipitakaLink(
          nodeKey: 'atta-sn-2-3-1',
          originKey: 'sn-2-3-1-3',
          pageIndex: 4,
          entryIndex: 1),
    ];

    for (final link in links) {
      test('shareable URL: $link', () {
        expect(TipitakaLink.parse(link.toUri('https://sammaditthi.net')), link);
      });

      test('custom scheme: $link', () {
        expect(TipitakaLink.parse(link.toCustomSchemeUri()), link);
      });
    }

    test('an entry with no page is the one state that cannot survive', () {
      // The constructor allows a combination the URL grammar has no way to
      // express, so this is the sole input where build → parse legitimately
      // returns something *different*. Asserted rather than left implicit: if
      // the codec ever starts carrying a page-less entry, it fails here first.
      const orphan = TipitakaLink(nodeKey: 'sn-2-3', entryIndex: 4);
      expect(
        TipitakaLink.parse(orphan.toUri('https://sammaditthi.net')),
        const TipitakaLink(nodeKey: 'sn-2-3'),
      );
      expect(TipitakaLink.parse(orphan.toCustomSchemeUri()), isNot(orphan));
    });
  });

  group('value semantics', () {
    test('equal links are equal and hash alike', () {
      // One side is built at runtime on purpose. Two identical const literals
      // are canonicalised to the *same object*, so comparing them would pass
      // even if `==` were `identical` — the assertion has to cross an object
      // boundary to say anything about value semantics at all.
      final parsed =
          TipitakaLink.tryParse('https://host/tipitaka/sn-2-3?e=12.4')!;
      const literal =
          TipitakaLink(nodeKey: 'sn-2-3', pageIndex: 12, entryIndex: 4);
      expect(identical(parsed, literal), isFalse);
      expect(parsed, literal);
      expect(parsed.hashCode, literal.hashCode);
    });

    test('each field participates in equality', () {
      const base = TipitakaLink(nodeKey: 'sn-2-3', pageIndex: 12, entryIndex: 4);
      expect(base, isNot(const TipitakaLink(nodeKey: 'sn-2-4', pageIndex: 12, entryIndex: 4)));
      expect(base, isNot(const TipitakaLink(nodeKey: 'sn-2-3', pageIndex: 13, entryIndex: 4)));
      expect(base, isNot(const TipitakaLink(nodeKey: 'sn-2-3', pageIndex: 12, entryIndex: 5)));
      const marked = TipitakaLink(nodeKey: 'atta-sn-2-3', originKey: 'sn-2-4');
      expect(marked, isNot(const TipitakaLink(nodeKey: 'atta-sn-2-3')));
      expect(
          marked,
          isNot(const TipitakaLink(
              nodeKey: 'atta-sn-2-3', originKey: 'sn-2-5')));
    });

    test('a link cannot be both served elsewhere and arrived at through a door',
        () {
      // Both write the fragment and a URL has one. Caught in the constructor
      // rather than silently resolved by the writer, where whichever branch
      // came first would quietly win.
      expect(
        () => TipitakaLink(
            nodeKey: 'sn-2-3', pageKey: 'sn-2', originKey: 'sn-2-4'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a missing position is not the same as position zero', () {
      expect(
        const TipitakaLink(nodeKey: 'sn-2-3'),
        isNot(const TipitakaLink(nodeKey: 'sn-2-3', pageIndex: 0)),
      );
    });
  });
}
