---
version: 1.0.0
name: SpecNav Warm Editorial
description: Design language for SpecNav generated review surfaces, terminal output, and documentation diagrams.
colors:
  canvas: "#faf9f5"
  surface:
    soft: "#f5f0e8"
    card: "#efe9de"
    dark: "#181715"
    dark_elevated: "#252320"
  brand:
    primary: "#cc785c"
    primary_active: "#a9583e"
  accent:
    teal: "#5db8a6"
    amber: "#e8a55a"
  text:
    ink: "#141413"
    body: "#3d3d3a"
    muted: "#6c6a64"
    muted_soft: "#8e8b82"
    on_dark: "#faf9f5"
    on_dark_soft: "#a09d96"
  line:
    hairline: "#e6dfd8"
  status:
    error: "#c64545"
    success: "#5db872"
typography:
  display: "Tiempos Headline, Cormorant Garamond, Georgia, Times New Roman, serif"
  body: "Inter, -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif"
  mono: "JetBrains Mono, SFMono-Regular, Consolas, monospace"
  scale:
    h1: "clamp(44px, 7vw, 72px)"
    h2: "clamp(30px, 4vw, 48px)"
    h3: "28px"
    lead: "18px"
    body: "16px"
    small: "13px"
    eyebrow: "12px"
spacing:
  base_unit: "8px"
  card_padding: "32px"
  tile_padding: "20px"
  grid_gap: "16px"
  hero_gap: "32px"
  section_margin: "96px"
  page_max_width: "1200px"
  page_padding: "64px 24px 80px"
rounded:
  card: "12px"
  pill: "999px"
  code: "6px"
components:
  report_page: "Stakeholder verification report shell on {colors.canvas} with topline brand row, hero, dark domain band, and section cards."
  cta_card: "Verdict callout card on {colors.brand.primary} with white text and inline code chips."
  dark_panel: "Domain results band on {colors.surface.dark} using {colors.text.on_dark} headings."
  domain_card: "Per-domain verdict card on {colors.surface.dark_elevated}; green verdict border tints toward {colors.status.success}, red or blocked verdict border tints toward {colors.status.error}."
  status_badge: "Uppercase pill using {rounded.pill}; pass variant tints {colors.status.success}, blocked variant tints {colors.status.error}."
  meta_tile: "Key fact tile on {colors.canvas} bordered by {colors.line.hairline} with bold ink label."
  artifact_table: "Coverage table on {colors.canvas} with header row on {colors.surface.soft} and hairline row dividers."
  code_chip: "Inline monospace chip colored {colors.brand.primary_active} using {rounded.code}."
  stage_diagram: "README and stage explainer images in the canonical B+D illustrated map style, 16:9, produced at 2560x1440 PNG."
  terminal_status: "Plain markdown tables and key-value lines emitted by status, route, doctor, and contract scripts."
---

# SpecNav Warm Editorial

## Overview

SpecNav is a CLI plugin suite. Its user-facing visual surfaces are: generated
stakeholder HTML reports (`verify/aggregate-report.html`, `verify-report.html`
rendered by `plugins/specnav-verification/scripts/verify-domains.js`),
terminal markdown output from status and contract scripts, and the
documentation diagram set governed by
`docs/memory/specnav-visual-style.md`. This spec records the design tokens and
component contract those surfaces already implement, so future report or
diagram changes are validated against a declared system instead of ad-hoc CSS.
The review style identifier emitted in reports is `claude-warm-editorial`.

## Colors

Warm parchment canvas with dark product panels and coral action surfaces.

- Canvas and section cards stay on the warm neutrals (`canvas`, `surface.soft`, `surface.card`).
- The domain results band uses the dark surfaces (`surface.dark`, `surface.dark_elevated`).
- Coral (`brand.primary`) is reserved for the verdict callout; never use it for body text.
- Status colors are semantic only: `status.success` for pass or green verdicts, `status.error` for red or blocked.
- Teal and amber accents are available for illustration and secondary highlights, not for verdict semantics.

## Typography

- Display headings use the serif stack (`typography.display`) with tight letter spacing, weight 400.
- Body copy uses the humanist sans stack (`typography.body`) at line-height 1.55.
- Code, file paths, and identifiers always render in the mono stack (`typography.mono`).
- Eyebrow labels are uppercase, letter-spaced 0.12em, muted color.

## Layout

- Reports are a single centered column, max width per `spacing.page_max_width`.
- Hero is a two-column grid (content plus verdict card) collapsing to one column under 820px.
- Domain grid is three columns desktop, one column mobile.
- Section rhythm follows `spacing.section_margin`; card interiors follow `spacing.card_padding`.

## Elevation & Depth

- Depth is expressed by surface color steps (canvas, soft, card, dark, dark elevated) and hairline borders, not drop shadows.
- Diagrams may use soft paper texture and subtle isometric shadows per the visual style memory.

## Motion

- Generated HTML reports are static documents: no animation, no transitions, no scroll effects.
- Terminal output has no motion semantics.
- Diagram imagery is still; no animated GIFs in README stage sections.

## Shapes

- Cards and tables use `rounded.card`.
- Badges and pills use `rounded.pill`.
- Inline code chips use `rounded.code`.
- Diagram nodes follow the route-map station language from the visual style memory.

## Components

The component inventory and their surface contracts are declared in the
frontmatter `components` map. `report_page`, `cta_card`, `dark_panel`,
`domain_card`, `status_badge`, `meta_tile`, `artifact_table`, and `code_chip`
are implemented in `renderAggregateHtml`. `stage_diagram` is governed by
`docs/memory/specnav-visual-style.md`. `terminal_status` is implemented by the
`toMarkdown` and `toText` helpers in core and contract scripts.

## Voice & Content

- Voice is calm, technical, and evidence-first; verdicts are stated plainly (`green`, `red`, `blocked`).
- Every claim in a report links to a machine artifact path in mono type.
- No marketing superlatives inside generated reports; the report footer names the style contract.
- Blocker strings are shown verbatim; never paraphrase a blocker identifier.

## Theme & Internationalization

- Theme capability: light-only. Generated reports ship one fixed warm-light palette; the dark band is a fixed surface inside the light theme, not a theme mode.
- Theme toggle: omitted by policy. Reports are static files with no runtime theming and no toggle control.
- Internationalization: documentation surface is bilingual; generated report and terminal surfaces are English-only in this version.
- Supported locales: `en` and `zh-CN` for README and docs (`README.md`, `README.zh-CN.md`, localized diagram sets under `docs/assets/readme/en/` and `docs/assets/readme/zh-CN/`); `en` only for generated HTML reports and script output.
- Default locale: `en`.

## Do's and Don'ts

- Do keep verdict semantics on `status.success` and `status.error` only.
- Do keep file paths and identifiers in mono chips.
- Do follow the B+D illustrated map contract for any new diagram.
- Don't introduce flat SaaS dashboard cards, neon or glassmorphism styles, or purple-blue gradients (negative constraints inherited from the visual style memory).
- Don't add a theme toggle or dark mode to generated reports without updating this spec first.
- Don't localize generated reports partially; report locale support changes here before implementation.
