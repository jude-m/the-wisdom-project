# App reader backlog

Open work on the app's reading surface. Opened 2026-09-11, when
`reading-units-and-grouping.md` moved to `docs/decisions/` — the reader rework it
planned (Part 4, B1–B6) is done, and this is where the leftovers live so the rule
doc can be a rule doc.

**Scope: the app.** The apex static site has its own list,
`docs/todo/web-strategy/static-site-backlog.md`. The rule both surfaces follow is
[`../decisions/reading-units-and-grouping.md`](../decisions/reading-units-and-grouping.md).

---

## R1. The tab label and breadcrumb do not follow the scroll

Scrolling from Mūlapariyāya into Sabbāsava leaves the app claiming you are still
in Mūlapariyāya. The label is set when the tab opens and never revisited.

**Much smaller than it was.** It was hard while a tab ran to the end of a content
file; now a unit is bounded and `SliceIndex.keyAt` already answers *which node
owns this row* — the same lookup search landing uses. **Nothing calls it for
this yet**, and that is the whole of the work: watch the top-visible row, ask
`keyAt`, update the label and the breadcrumb when the answer changes.

Two things to decide when someone picks it up:

- **A container unit renders many leaves.** Does the label track the leaf under
  the reader, or stay on the node that was tapped? Tracking is what the user
  sees; staying is what they asked for. The breadcrumb probably wants to track
  even if the tab label does not.
- **How often to ask.** Per scroll frame is wasteful and per settle is laggy;
  the answer only changes at a row boundary, so it should key off the
  top-visible index changing, not off scroll offset.
