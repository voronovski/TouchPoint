# TouchPoint Design Language

This is the living visual and interaction contract for TouchPoint. It borrows the calm, native structure of Desk while giving this product its own emotional register. TouchPoint is a relationship-planning tool, not a greeting-card gallery: dates, people, readiness, and trust lead; decoration follows.

## Product character

- Calm enough for repeated professional use, warm enough for family and friends.
- Planning is the primary experience. Content creation is supporting work.
- The interface should make the next meaningful action obvious without making the user feel behind.
- Automation must feel controlled and legible. Always show who, what, when, channel, time zone, and approval state before scheduling.
- AI is an optional accelerator. Every core workflow must be complete without it.

## Audience strategy

TouchPoint is professional-first and relationship-inclusive.

- The first paid product is optimized for relationship-based professionals: Realtors, lenders, insurance agents, financial advisors, attorneys, and comparable client-facing businesses.
- The primary value proposition is reliable relationship follow-up at scale, not access to greeting-card content.
- Dashboard priorities are upcoming workload, approvals, delivery state, and exceptions.
- `Plan the Year`, bulk selection, contact import, consent tracking, business branding, and delivery analytics take precedence over decorative greeting features.
- A professional account may also contain family, friends, and colleagues. These people use the same respectful core model and are not treated as second-class records.
- Do not force CRM terminology into every surface. Use `People` as the universal entity and `Client` as a relationship type.
- Personal use remains possible, but the first paid tier, onboarding examples, and roadmap must have a clear professional return on investment.

## Cross-platform contract

TouchPoint will have native iOS and Android clients. Share product semantics and tokens, not platform-specific rendering code.

- Use the platform's native navigation, lists, sheets, dialogs, menus, date pickers, toggles, search, typography scaling, and accessibility behavior.
- Keep domain models platform-neutral: `Person`, `ImportantDate`, `GreetingPlan`, `Delivery`, `Template`, and `DeliveryStatus`.
- Component names describe intent rather than framework types: `PersonRow`, `EventRow`, `StatusPill`, `SelectionRow`, `PrimaryAction`, and `EmptyState`.
- Values in this document are logical points on iOS and density-independent pixels on Android unless a platform guideline requires an adjustment.
- SF Symbols are iOS implementations, not shared identifiers. Android maps the same semantic role to a Material Symbol.

## Foundations

### Color

| Token | Light reference | Purpose |
| --- | --- | --- |
| `accent` | Indigo `#5856D6` | Navigation, selection, links, focus, ordinary actions |
| `moment.coral` | Coral `#E85447` | Birthdays and warm personal moments |
| `moment.rose` | Rose `#C9457A` | Wedding and relationship anniversaries |
| `moment.amber` | Amber `#BD7A0F` | Seasonal moments and approval pending |
| `moment.forest` | Forest `#297A4F` | Christmas and confirmed delivery/success |
| `moment.teal` | Teal `#0D7D85` | Appreciation and professional relationship moments |
| `destructive` | System red | Errors, failed delivery, destructive actions |

Use semantic system background, label, separator, and fill colors in light and dark appearances. Hard-coded moment colors communicate occasion identity only; they must not compete with the global accent for actions. Never use green for an ordinary selectable state.

### Spacing and shape

- Screen horizontal inset: `16`.
- Scroll content top/bottom inset: `18` minimum.
- Section-to-section spacing: `16`.
- Section title to surface: `10`.
- Card content inset: `12`; use `16` only for message previews.
- Row gap between leading identity and content: `12`.
- Card radius: `16`, continuous on iOS and the closest smooth shape on Android.
- Nested icon tile: `28 x 28`, radius `7`.
- Standard primary action: full width, height `50`, radius `16`.
- Minimum interactive target: `44 x 44` on iOS and `48 x 48` on Android.

### Typography

Use the platform system font and Dynamic Type/font scaling. Do not encode fixed font sizes in shared product specifications.

- Screen title: native large or inline navigation title.
- Card title or person name: platform headline or semibold subheadline.
- Row primary value: semibold subheadline.
- Supporting detail: caption or regular subheadline in secondary color.
- Section title: semibold subheadline in secondary color.
- Status: semibold caption; never rely on color alone.
- Dates and numeric counters use tabular/monospaced digits when alignment matters.

Letter spacing stays at the platform default. Long names and translated strings may wrap; compact controls and statuses stay on one line and truncate only when their full value is available through accessibility.

## Screen structure

### App shell

The primary destinations are `Home`, `Calendar`, `People`, and `Templates`. Use a native bottom tab bar/navigation bar. Settings and account management are secondary destinations opened from the relevant toolbar entry.

`Home` is the product center, not a marketing screen. Its first viewport must contain:

1. The TouchPoint navigation title.
2. The next scheduled or approval-required greeting.
3. A visible entry to `Plan the Year`.
4. A hint of the upcoming schedule.

### Editor and planning flows

- Present focused creation flows in a native sheet with a navigation container.
- Use inline titles, leading `Cancel` or `Close`, and a precise confirmation verb.
- Multi-step workflows show compact progress and keep one primary action anchored at the bottom.
- Back preserves the draft within the flow. Cancel discards it.
- Disable the primary action only when a visible prerequisite is missing.
- Show a concise success result with the number of greetings created.

### Collections

People, templates, greetings, and activity use native lists directly. Do not place a list inside a decorative card. Preserve platform row behavior, separators, search, swipe actions, and disclosure indicators.

Collection states are explicit:

- Initial loading: centered progress on grouped background.
- Empty: platform unavailable/empty state with one useful creation action.
- Initial error: focused retry state.
- Refresh failure: keep the last usable content and show the error inline.
- Loaded: native list; do not add a redundant surrounding surface.

## Components

### Surface card

Use one card to group related information or controls. Fill with the secondary grouped background. Avoid cards inside cards. Divide multiple rows with a separator inset past the leading icon or avatar.

### Person avatar

Use a photo when the user has supplied one. Otherwise use one or two initials in a circular, softly tinted background. The tint may reflect relationship category, but the written relationship remains available where it matters. Do not use generic stock portraits.

### Person row

- Avatar, name, relationship or best contact detail, optional high-value trailing state.
- Use a disclosure indicator only when the row navigates.
- The entire row is the hit target.
- Never repeat a redundant `Person` label above the name.

### Event row

- Avatar first, then person name and occasion.
- Trailing content shows the localized date and delivery channel.
- A detail surface may additionally show approval/delivery status.
- Keep annual dates date-only. Show a delivery time only when it has been scheduled.

### Icon tile

Use a neutral or semantically tinted platform icon at semibold subheadline weight in a `28 x 28` softly tinted tile. Icons communicate the entity or interaction. Every icon-only control needs an accessibility label.

### Status pill

Reserve compact pills for actionable delivery state: `Needs approval`, `Scheduled`, `Sent`, `Opened`, and `Failed`. Pair color with text. Do not use pills for ordinary metadata such as relationship or language.

### Primary action

Each surface or step has at most one visually dominant action. Use the shared solid accent button. The label contains an icon plus regular body text and remains visible during loading; replace the icon with a small progress indicator. Destructive, toolbar, and list actions retain native treatment.

### Selection row

Use a selection row for a value that opens a picker, menu, or destination. It contains an icon tile, concise label/value, and a disclosure affordance appropriate to the platform. Make the full row interactive.

## Plan the Year

This is TouchPoint's signature workflow and must stay faster than scheduling greetings individually.

1. Select people, with `Select all` available.
2. Select one or more occasions.
3. Choose delivery channel and approval behavior.
4. Review the number of plans, recipients, and time-zone behavior.
5. Schedule once, then allow individual exceptions from Calendar or a person's detail screen.

Selection is staged locally until final confirmation. Do not mutate the calendar when moving between steps. The first release supports `Text message`, `Email`, and `Reminder only` as product concepts; enable a delivery channel in production only after its sender, consent, unsubscribe, and failure behavior are implemented.

## Content and trust

- Lead with concrete dates and names, not celebratory slogans.
- Use warm but restrained language. Avoid guilt-inducing copy such as `You forgot` or `Overdue` for personal moments.
- A scheduled message preview must show variable substitutions such as the recipient's name before final approval.
- Clearly distinguish `Save draft`, `Schedule`, `Approve`, and `Send now`.
- A recipient-facing link must use a verified TouchPoint or customer-branded domain and present the sender identity immediately.
- Never imply delivery succeeded until the provider confirms it. `Sent`, `Delivered`, `Opened`, and `Clicked` are distinct states.

## Accessibility and motion

- Support system text scaling, VoiceOver/TalkBack, high contrast, dark mode, and reduced motion.
- Do not encode occasion, relationship, or delivery status only with color or initials.
- Conditional rows enter from beneath their controlling row with a short opacity plus vertical move transition. Respect Reduce Motion.
- Selection changes may use light platform haptics. Scheduling and destructive actions require stronger confirmation; routine navigation does not.
- Keep animations short and functional. Greeting-page animation is a separate recipient experience and must not leak into the planning UI.

## Localization, dates, and time zones

- All user-facing strings belong in localization resources before production release.
- Store instants in UTC and store the recipient IANA time-zone identifier separately.
- Birthdays and anniversaries are date-only values. Never shift them by converting midnight across time zones.
- Calculate delivery time in the recipient's zone and show the zone in review and detail screens.
- Format dates, names, phone numbers, pluralization, and week starts with platform locale APIs.
- Templates declare their language. Automatic translation or AI rewriting requires an explicit preview and approval.

## Current design decisions

- Working product name: `TouchPoint`.
- Working tagline: `Plan once. Never forget again.` It belongs in store/marketing material, not repeated throughout the app UI.
- Initial shell: Home, Calendar, People, Templates.
- Home combines the next action, annual planning entry, and a filterable near-term schedule.
- Default annual-plan delivery: text message, with manual approval on.
- Source UI language for the prototype: English; localization architecture remains required.
- First paid audience: relationship-based professionals, while preserving family, friend, and colleague relationships.
- Annual planning defaults to the `Client` filter and can be widened to any relationship or all people.

## Open product questions

- Is SMS the only launch delivery channel, or should email ship at parity?
- Must every automated SMS use a hosted greeting link, or can short text-only greetings be sent directly?
- What is the consent model for imported professional contacts?
- Which event types require a year as well as month/day?
- Should one person support multiple household or business roles?
- Will shared team accounts own people and templates at the workspace level?

## Review checklist

- The first viewport explains today's work without explanatory feature copy.
- Every scheduled item exposes person, occasion, date, delivery channel, time zone, and status at the appropriate detail level.
- There is only one primary action per step or card.
- Lists use native collection surfaces; related form rows share one card.
- Loading, empty, error, disabled, success, and partial-data states are designed.
- Light/dark mode and large text remain readable without overlap.
- Icons have semantic platform mappings and accessible labels.
- Date-only occasions are not accidentally converted as instants.
- AI is absent from the critical path.
- New reusable patterns are documented here before screen-specific variants spread.
