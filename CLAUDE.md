# QUALITY GATE — paste this section into CLAUDE.md
# Version: Build Nova 2.1 / July 2026
# Purpose: every app produced by this pipeline must be indistinguishable
# from an app built by a small design-led studio over several weeks.

## PRIME DIRECTIVE

You are not filling a niche. You are shipping a product. If any screen of the
app could plausibly appear in ten other apps with a different accent color,
the work is not done. Uniqueness is structural (layout, interaction,
components), not cosmetic (colors, icons, names).

**Variance philosophy: no pattern is banned globally — a tab bar, a paged
onboarding, a staged splash are all legitimate tools. What is banned is
REPETITION: the same structure appearing in consecutive apps of the
portfolio. The registry decides what is available, not a canon. The bans
below target LOW-EFFORT DEFAULTS, not formats.**

Every app MUST be built from a Build Nova 2.x spec. If the spec is missing
the Art Direction block or the Signature Feature block — STOP and request a
complete spec. Never improvise these from defaults.

## ZERO TOLERANCE LIST (instant fail — never ship if any are present)

- Placeholder anything: "Lorem", "Sample", "Test", "TODO", stock example data
  that makes no sense in the niche, empty About screens, dead settings toggles.
- Runtime seed/demo/sample data of ANY kind — sample content is legal ONLY
  inside #Preview blocks. Fresh install = zero user data + designed empty states.
- A low-effort onboarding: icon + title + subtitle slides that teach nothing,
  change nothing, and connect to nothing in the real UI. Paged/TabView
  onboarding IS a legitimate format — what fails is emptiness, and reusing
  the previous apps' onboarding structure (see Cross-App Variance).
- A splash whose only idea is a logo scale/fade. Splash construction (loop
  or staged) is free per app — see Splash System — but a bare logo animation
  is not a splash identity.
- Plain `List` inside `TabView` as the primary architecture with no custom
  layout work anywhere.
- Raw SF Symbols as the entire iconography with zero treatment (no custom
  weights, no enclosures, no tinted containers, no hierarchical rendering).
- `RoundedRectangle(cornerRadius: 12)` white cards on `Color(.systemGroupedBackground)`
  as the only surface treatment in the app.
- `.animation(.default)` or unconfigured `withAnimation { }` anywhere.
- Identical corner radius, spacing, and type scale as any previous app in the
  portfolio registry.
- Buttons without a pressed state. Lists without empty states. Network- or
  computation-driven views without loading and error states.
- Any auth screen, login, or profile — UNLESS the spec declares a backend
  in §14 (then auth exists, follows the Firebase Backend addon rules, and
  gets full art-direction treatment; in-app account deletion is mandatory).

## DESIGN IDENTITY (required per app)

Each app gets its own design system, defined in the spec and implemented as a
`DesignSystem.swift` (or Theme folder) before any screen is built:

1. **Typography**: a deliberate type scale (at minimum: display, title, body,
   caption) with chosen weights and tracking. Rounded vs. default vs. serif
   (`.fontDesign`) must be a conscious choice that matches the app's mood.
   Two consecutive apps in the portfolio must not share the same combination.
2. **Color tokens**: semantic tokens only (`surface`, `surfaceElevated`,
   `accent`, `accentMuted`, `textPrimary`, `textSecondary`, `positive`,
   `warning`) — never raw colors inline. Full dark mode variants. The palette
   must come from the spec's Art Direction block.
3. **Shape language**: ONE consistent radius/shape philosophy per app
   (e.g. squircle-heavy 20–28pt, or sharp 4–8pt editorial, or capsule-based).
   Nested containers use concentric radii (inner = outer − padding).
4. **Component library**: minimum 6 bespoke reusable components (custom
   button style, custom card, custom input, custom picker/segmented control,
   custom progress/stat element, custom empty-state view). "Bespoke" means
   visually distinct from Apple defaults, not restyled defaults.
5. **Depth & elevation**: choose ONE elevation strategy (soft diffused
   shadows / hairline borders + fills / layered translucency) and apply it
   consistently. Never mix all three randomly.

## MOTION RULES

- Springs are the default, tuned per app: `.spring(response: 0.3...0.5,
  dampingFraction: 0.7...0.9)` from the spec's motion personality. Never
  `.default`, never `.linear` for UI (linear only for constant motion like
  progress). The SAME spring numbers must not travel between apps.
- Durations: press feedback 100–160ms; small transitions 150–250ms;
  sheets/full-screen 300–450ms. UI animation over 500ms is a bug.
- Every tappable element scales on press (`0.96–0.98`) via a shared
  `ButtonStyle`. Asymmetric timing: press can be deliberate, release is snappy.
- Lists/grids entering the screen stagger in (30–60ms per item, cap at ~8 items,
  never block interaction).
- Frequency rule: actions used dozens of times per session get minimal or no
  animation. Rare moments (first launch, achievement, completion) may have
  delight (confetti, morphing, drawn-on checkmarks).
- Respect Reduce Motion: replace movement with opacity, keep comprehension aids.
- Every state change is animated (numbers count, bars grow, cards reorder
  smoothly with `matchedGeometryEffect` where appropriate). Nothing pops
  instantly between two visually distant states.

## DEPTH REQUIREMENTS

- The Signature Feature from the spec must be implemented in full, including
  its computation/visualization logic. It is the last thing to cut — cut
  secondary screens instead.
- Every data-driven view implements the full state matrix:
  empty (designed, with guidance + CTA) / partial / populated / error.
  Empty states are designed compositions, not a gray icon + "No data".
- Haptics map: light impact on selection, medium on commit/success actions,
  `.success`/`.warning`/`.error` notifications where semantically true.
  Defined per screen in the spec.
- Real interactivity beyond CRUD: at least two of — drag/reorder, swipe
  actions with custom styling, long-press context previews, interactive
  charts/visualizations, gesture-driven controls, live-updating computed
  insights.
- Onboarding (if present): must EARN its place — it either teaches the app
  by showing the real UI working, or collects preferences that visibly
  configure the app, or both. Format (paged / single-screen / interactive
  scenes) is free — chosen per app, recorded in the registry.

## CROSS-APP VARIANCE (portfolio registry — the actual law)

Before building, read the portfolio registry (previous apps' recorded DNA:
navigation paradigm, interaction archetype, palette family, type
combination, shape language, splash archetype+construction, onboarding
style). The current app must differ from the LAST 10 apps in at least:
navigation paradigm OR primary interaction archetype, AND palette family,
AND type combination, AND splash archetype, AND onboarding style.
Any pattern absent from the last 10 entries is fair game — including tab
bars, paged onboardings, and staged splashes. After shipping, append this
app's full DNA line to the registry.

## PRE-SHIP CHECKLIST (all must pass)

- [ ] Zero items from the Zero Tolerance List present
- [ ] DesignSystem file exists; no inline raw colors/fonts in screens
- [ ] 6+ bespoke components; press states everywhere
- [ ] Full state matrix on every data view; empty states are designed
- [ ] Signature Feature fully working with real logic
- [ ] Motion: springs tuned per app, durations within limits, stagger on
      lists, Reduce Motion handled
- [ ] Haptics map implemented
- [ ] Dark mode reviewed screen by screen (not just "it compiles")
- [ ] Dynamic Type: layout survives XL sizes; iPad: no stretched iPhone layout
- [ ] Portfolio registry check passed and registry updated (full DNA line)
- [ ] The honest test: "Would a designer believe a human team spent 3 weeks
      on this?" If hesitation — iterate before shipping.
