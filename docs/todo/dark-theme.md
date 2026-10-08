# Dark theme

Placeholder. The dark theme is not designed yet. Known issues are collected here so they are not lost; the plan comes later.

The warm theme is also a dark colour scheme, so issues here usually hit it too.

## Known issues

### Dimmed text does not dim in the dark and warm themes

Dark and warm set `onSurfaceVariant` to `onBackground` at alpha 0.7 (`app_theme.dart`, `dark()` and `warm()`). `withValues(alpha: x)` replaces the alpha; it does not multiply it. So `onSurfaceVariant.withValues(alpha: 0.7)` comes out the same as plain `onSurfaceVariant` in these two themes. Light is fine: its `onSurfaceVariant` is opaque.

```dart
// Dark: onSurfaceVariant already has alpha 0.7.
variant.withValues(alpha: 0.7);            // alpha 0.7: no change
variant.withValues(alpha: variant.a * 0.7); // alpha 0.49: dimmed
```

Where it shows:

- **Model name in the research chat** (`research_chat_view.dart`, the `· model` label). Alpha 0.6 replaces 0.7, so it is barely dimmer.

Search for `onSurfaceVariant.withValues` to find any others.

Two ways to fix, to decide when designing the theme:

- Per call site: multiply, as in the example above.
- At the root: give dark and warm an opaque `onSurfaceVariant` (the colour already blended onto the surface), so `withValues(alpha:)` behaves the same in every theme. The blend is exact only on `surface`: muted text on other backgrounds, such as the expanded-matches box (`surfaceContainerLow`), comes out slightly different from today.

The multiply is right under both options: with an opaque colour `a` is 1.0, so it still gives 0.7.

### Search filter row and match menu (to check by hand)

Found while building the search pane redesign, chunk C (2026-10-07). The row and chip colours are the ones from before that chunk (kept on purpose); only the menu is new. These come from reading the dark and warm palettes, not from looking.

- **Chips sit darker than their row.** Chip fill `surfaceContainerLow` on the row's `surfaceContainerHighest`: in light that is a lighter chip on a darker row, so it looks raised. In dark (`#1A1A1A` on `#333333`) and warm (`#332B1F` on `#554838`) it is the other way round, so the chips look sunken. Refine at rest (`surfaceContainerLowest`) is darker still (`PillChip`).
- **Selected chips are loud.** `secondary` is the bright orange accent in dark (gold in warm), where light uses a muted taupe.
- **Refine with filters on has a white ring in dark.** Its border is `primary`, which is pure white in dark. The fill is the orange accent at 20%.
- **Selected row in the match menu barely shows.** It is filled with `surfaceContainerLow` on a `surface` menu. In light that is cream on white; in dark (`#1A1A1A` on `#1E1E1E`) and warm it is darker than the menu and almost invisible. The radio still marks the choice (`match_options_menu.dart`).
