# TouchPoint Design Language

This is the living visual and interaction contract for TouchPoint. It borrows the calm, native structure of Desk while giving this product its own emotional register. TouchPoint is a relationship-planning tool, not a greeting-card gallery: dates, people, readiness, and trust lead; decoration follows.

## Product character

- Calm enough for repeated professional use, warm enough for family and friends.
- Planning is the primary experience. Content creation is supporting work.
- The interface should make the next meaningful action obvious without making the user feel behind.
- Planning must feel controlled and legible. Always show who, what, when, contact method, time zone, and readiness before scheduling.
- AI is an optional accelerator. Every core workflow must be complete without it.

## Audience strategy

TouchPoint uses one relationship model and one universal interface. An optional `Focus` changes what is shown first without asking the user to adopt a professional or personal identity.

- `Work` focuses clients and colleagues.
- `Personal` focuses family and friends.
- `All` keeps every relationship visible and is the default for new users.
- Changing focus never migrates or deletes people, dates, templates, or plans.
- Keep `People` as the universal entity and `Client` as one relationship type. Do not force CRM terminology into shared surfaces.
- Both experiences retain `Plan the Year`, native Messages/Mail handoff, manual completion, and the same trust contract.

## Cross-platform contract

TouchPoint will have native iOS and Android clients. Share product semantics and tokens, not platform-specific rendering code.

- Use the platform's native navigation, lists, sheets, dialogs, menus, date pickers, toggles, search, typography scaling, and accessibility behavior.
- Keep domain models platform-neutral: `Person`, `ImportantDate`, `GreetingPlan`, `ContactMethod`, `Template`, and `GreetingStatus`.
- Persist enum identifiers independently from localized labels. Current stable IDs include `client`, `family`, `home_anniversary`, `client_appreciation`, `sms`, `email`, `reminder`, `planned`, and `completed`.
- Component names describe intent rather than framework types: `PersonRow`, `EventRow`, `StatusPill`, `SelectionRow`, `PrimaryAction`, and `EmptyState`.
- Values in this document are logical points on iOS and density-independent pixels on Android unless a platform guideline requires an adjustment.
- SF Symbols are iOS implementations, not shared identifiers. Android maps the same semantic role to a Material Symbol.

## Foundations

### Color

| Token | Light reference | Purpose |
| --- | --- | --- |
| `accent` | Indigo `#5856D6` | Navigation, selection, links, focus, ordinary actions |
| `moment.indigo` | Indigo `#5856D6` | Stable saved appearance for templates and collections; independent from the current app accent |
| `moment.coral` | Coral `#E85447` | Birthdays and warm personal moments |
| `moment.rose` | Rose `#C9457A` | Wedding and relationship anniversaries |
| `moment.amber` | Amber `#BD7A0F` | Seasonal moments and ready-to-send actions |
| `moment.forest` | Forest `#297A4F` | Christmas and completed actions |
| `moment.teal` | Teal `#0D7D85` | Appreciation and professional relationship moments |
| `destructive` | System red | Composer errors and destructive actions |

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

### Row alignment

Rows with a leading or trailing icon/avatar and stacked text align the visual
elements to the vertical center of the row content. This applies to selection,
identity, event, status, and explanatory rows, including rows whose supporting
text wraps. In SwiftUI use `TouchPointMetric.rowContentAlignment` (currently
`.center`). Use top alignment only when the leading icon belongs to a genuinely
multiline text input; that exception is named
`TouchPointMetric.multilineTextFieldAlignment`.

### Typography

Use the platform system font and Dynamic Type/font scaling. Do not encode fixed font sizes in shared product specifications.

- Screen title: native large or inline navigation title.
- Card title or person name: platform headline or semibold subheadline.
- Row primary value: semibold subheadline.
- Supporting detail: caption or regular subheadline in secondary color.
- Section title: semibold subheadline in secondary color.
- Detail/editor field label: secondary caption above the primary semibold subheadline value. Keep the label visible while editing.
- Status: semibold caption; never rely on color alone.
- Dates and numeric counters use tabular/monospaced digits when alignment matters.

Letter spacing stays at the platform default. Long names and translated strings may wrap; compact controls and statuses stay on one line and truncate only when their full value is available through accessibility.

## Screen structure

### App shell

The primary destinations are `Home`, `Calendar`, `People`, `Occasions`, and `Templates`. Use a native bottom tab bar/navigation bar. Settings and account management are secondary destinations opened from the relevant toolbar entry.

`Home` is the product center, not a marketing screen. Its first viewport must contain:

1. The TouchPoint navigation title.
2. The next planned or ready-to-send greeting.
3. A visible entry to `Plan the Year`.
4. A hint of the upcoming schedule.

### First-run focus

The first launch offers `Work`, `Personal`, and `All` as starting focuses.

- Preselect `All`; choosing a narrower focus is optional.
- Explain each option through audience and workflow, not feature checklists or pricing language.
- State that the focus can be changed later without losing data.
- Persist `Focus` and onboarding completion in platform preferences. Migrate legacy `professional` and `personal` values without touching relationship data.

### Focus-aware Home

- Home uses one vocabulary and layout for every user.
- The selected focus scopes the workload summary and upcoming actions; `All` shows the complete schedule.
- A settings gear in the Home toolbar opens focus settings. Changing focus updates Home immediately.

### Focus-aware defaults

- Focus changes ordering and defaults, never capability. Every relationship and occasion remains reachable.
- `Work` prioritizes `Client` then `Colleague`; `Personal` prioritizes `Family` then `Friend`; `All` is neutral.
- Templates and occasion pickers place the current focus's likely moments first while retaining the full shared collection.
- These defaults are presentation preferences only and must not be persisted into relationship records unless the user saves a draft.

### Editor and planning flows

- Present focused creation flows in a native sheet with a navigation container.
- Use inline titles, leading `Cancel` or `Close`, and a precise confirmation verb.
- Multi-step workflows show compact progress and keep one primary action anchored at the bottom.
- Back preserves the draft within the flow. Cancel discards it.
- Disable the primary action only when a visible prerequisite is missing.
- Show a concise success result with the number of greetings created.
- The Apple Intelligence generator follows the same hierarchy: model status, direction, collapsible context, and editable output use surface cards; `Generate message` is the full-width primary action anchored above the sheet safe area, while refinement remains secondary.

### Detail and editor surfaces

Person detail and its shared create/edit screen follow Desk's `ClientDetailView`, `ClientDetailSections`, and `ClientEditorView` layout:

- Use a `ScrollView` on the system grouped background, a leading-aligned stack with `16` points between sections, `16` horizontal insets, and `18` vertical insets.
- Use `SurfaceSection` for a secondary semibold subheadline heading followed by a grouped card, with `10` points between them. Inset headings `16` points from the card's leading edge.
- Each card groups related rows without additional nested cards. `SurfaceRowDivider` starts `52` points from the card's leading edge, aligned with row text after the icon.
- Use `FormIconTile` for neutral field and metadata icons: `28 × 28`, radius `7`, secondary foreground, and tertiary grouped background. Reserve colored `IconTile` surfaces for meaningful occasion identity.
- `FormFieldRow` puts a caption label above the value or editable control. `FormValueRow` uses the same layout for saved values and selection controls. Both use `12`-point content insets and center icons vertically; only multiline note inputs align at the top.
- Selection controls use native menus/pickers or sheets and a trailing chevron. Ordinary values have no disclosure indicator. Long values wrap; editable text retains native text-field behavior.
- Text fields use native prompts in the system placeholder color. Notes use a `TextEditor` with a persistent label, hidden scroll background, and a neutral icon.
- Supporting explanations sit below the card in secondary footnote text. Empty sections use a compact neutral icon row instead of a full-screen placeholder.
- Keep native lists for standalone collections. A detail screen may group its associated dates or greetings into card rows without nesting a `List` inside a card.

The reference establishes the visual treatment. TouchPoint keeps its own person fields, manual greeting semantics, centered row alignment, and action placement described below.

### Collections

People, templates, greetings, and activity use native lists directly. Do not place a list inside a decorative card. Preserve platform row behavior, separators, search, swipe actions, and disclosure indicators.

Collection states are explicit:

- Initial loading: centered progress on grouped background.
- Empty: platform unavailable/empty state with one useful creation action.
- Initial error: focused retry state.
- Refresh failure: keep the last usable content and show the error inline.
- Loaded: native list; do not add a redundant surrounding surface.

Template collections use the shared semantic appearance palette. A saved color token always resolves to its named color, including `indigo`; changing the global app accent must not recolor saved collection identities. Collection rows show the collection icon, name, and template count. Creation and editing use a compact identity preview plus dedicated native icon and color selection screens. Deletion requires confirmation and moves contained templates to `Ungrouped` without deleting them.

### Template library

- Search and filters are independent: occasion, relationship audience, channel, language, and collection can be combined.
- Keep collection scope, context-filter entry, and sorting in one compact native control row above the results. Show applied context filters as removable chips; the searchable navigation field remains the dedicated text-search surface.
- Template creation shows a compact identity preview, uses the shared semantic color-token palette, and opens occasions in a large searchable multi-select sheet grouped into Personal moments, U.S. holidays, Observances, and Latin American dates.
- The shared occasion sheet uses collapsible category rows and expands matching categories while searching. Use single-select for event/date/filter fields and staged multi-select with `Cancel`/`Done` for templates and yearly planning.
- Every new template has one explicit language. Preselect the user's `Default language` preference (English on a fresh install); do not offer `Any language` as a template value.
- Template collections include Favorites, Ungrouped, and Archived.
- Template sorting defaults to Name; Recently updated is also available.
- Automatic template resolution uses recipient relationship, preferred channel, and language. A per-recipient exception overrides an occasion-wide choice, which overrides automatic resolution.
- Content edits create a local template revision. Favorite and archive changes do not create content revisions.
- Every template, including starter templates, can be edited, restored from history, or deleted. Deleted starters must not reappear when the library loads or syncs.
- Template rows show the title and message preview without default badges or version metadata. Version details belong in the editor's history section.

### Person detail and editor

`Person` is the shared relationship entity for clients, family, friends, and colleagues. Professional context enriches the entity but does not create a separate client model.

- Require a display name and at least one actionable contact value: phone or email.
- Support optional organization, relationship, preferred contact method, preferred language, and IANA time-zone identifier.
- Keep create and edit on the same component and draft contract. Focus may change a default title and confirmation verb, not the field hierarchy.
- Stage important-date additions, edits, and removals inside the person draft. Persist them only with the main `Add` or `Save` action.
- Show saved important dates separately from generated greeting plans. A source date is not a scheduled action.
- Search people by name, email, and organization.
- Do not add SMS consent or provider fields. TouchPoint opens the user's system composer and never acts as the sender.
- Detail starts with a compact identity card: `44`-point initials avatar, bold title3 name, and caption relationship/organization. Contact, preferences, communication, context, important dates, and planned greetings use the shared detail/editor cards.
- Keep phone and email selectable for copying. Display notes and tags as wrapping text so long content remains readable.
- Keep `Stop communication` as a native toggle in its own detail section with the existing confirmation and explanatory footer.
- The editor's only save entry is the trailing navigation toolbar `Save` / `Add` action. Do not repeat a save button at the bottom of the content.
- In the editor, important-date rows open the date editor and have an explicit `44 × 44` remove control. Additions, edits, and removals remain staged until the toolbar save succeeds.
- Place `Delete person` at the very end of the edit screen, below all fields and recoverable errors. It is a separate full-width solid system-red button with a white body label and a smaller white caption-size trash icon at the shared large symbol scale, `50` points high with a continuous `16`-point radius. Do not wrap it in a card or show it during creation.
- Deletion requires confirmation. After a successful delete, dismiss both the editor and the deleted person's detail. Failed writes retain the draft and show an inline red error; clear the stale error after an edit.

### Occasion library

- `Occasions` sits between `People` and `Templates`. It shows a searchable, expandable tree of groups, subgroups, built-in occasions, and user-created occasions.
- Keep the library and occasion, parent-group, and template selectors as native inset-grouped lists with search. Use centered rows, a `12`-point icon/text gap, semibold subheadline titles, and secondary captions. Groups use neutral `FormIconTile`; occasions use their semantic `IconTile`; templates retain their saved appearance.
- Group rows expand through a trailing chevron and offer a separate `44 × 44` edit control. Occasion rows disclose the editor. Selection uses an accent checkmark plus the accessibility selected trait; `None` and `Top level` follow the same pattern.
- Creation and editing of occasions, groups, and subgroups share the person editor's grouped-background `ScrollView`, `SurfaceSection`, `FormFieldRow`, `FormValueRow`, and inset `SurfaceRowDivider`. Apply `16` horizontal / `18` vertical screen insets, `16` section spacing, and persistent caption field labels.
- Group related controls under Details, Annual date, and Automatic greeting. Month/day and date-rule controls use native menus; parent group opens a searchable selector that excludes the edited node and its descendants. Supporting explanations sit below cards in secondary footnote text; message previews use a `16`-point inset.
- Keep `Cancel` and `Add` / `Save` in the navigation toolbar. Use accurate creation titles and no deletion action for unsaved items. New occasion/subgroup actions inside a saved group use the shared tertiary row style.
- Place `Delete occasion` / `Delete group` at the bottom using `TouchPointDeleteButton`, matching Edit Person. Preserve native confirmation and persistence behavior. Clear a stale write error when the draft changes.
- Empty libraries offer creation; searches with no matches and template libraries without active templates show explicit empty states. Template and parent selectors retain `None` / `Top level` as reachable choices.
- Group and occasion editors support names, parent groups, ordering and deletion. Deleting a group promotes its children; deleting a library occasion preserves saved dates and greetings.
- An occasion can use a date entered for each person, a fixed annual date, or its built-in holiday calendar. Calendar rules preserve moving holidays.
- Any active template can be attached to an occasion. Adding the occasion to a person schedules an annual greeting with that template at 09:00 in the recipient's time zone when the person is saved. The editor explains this before saving. Without an attached active template, only the date is saved.
- Person saves atomically commit dates, generated greetings and template variation cursors. Repeated saves and yearly planning must not duplicate greetings. Communication opt-outs prevent automatic planning.
- Editing a linked personal date moves its pending greeting while retaining its message. Removing a date removes its pending linked greetings; completed and skipped history stays available.
- Library edits affect subsequent assignments. Existing dates and greeting content retain their saved snapshots. Template deletion detaches library assignments.
- The catalog and stable date/greeting references are included in local persistence, export/import and CloudKit snapshots; old archives seed the built-in tree.

### Important dates

- Birthdays, home anniversaries, wedding anniversaries, and similar annual events store `month` and `day`, never a midnight timestamp.
- The editor uses explicit month/day controls and does not show or persist a fake year.
- Validate the day against the selected month. February 29 is valid; in non-leap years its annual action resolves to February 28 in the recipient's time zone.
- Global holidays such as Christmas and Thanksgiving are calendar rules, not duplicated person-level dates.

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
- Trailing content shows the localized date and contact method.
- A detail surface may additionally show whether the action is planned, ready, completed, or skipped.
- Keep annual dates date-only. Show a reminder time only when it has been scheduled.

### Icon tile

Use a neutral or semantically tinted platform icon at semibold subheadline weight in a `28 x 28` softly tinted tile. Icons communicate the entity or interaction. Every icon-only control needs an accessibility label.

### Status pill

Reserve compact pills for actionable planning state: `Planned`, `Ready`, `Completed`, and `Skipped`. Pair color with text. Do not use pills for ordinary metadata such as relationship or language. `Completed` means the user completed the handoff action; it is not a delivery receipt.

### Primary action

Each surface or step has at most one visually dominant action. Use the shared solid accent button. The label contains an icon plus regular body text and remains visible during loading; replace the icon with a small progress indicator. Toolbar and confirmation-dialog actions retain native treatment. Final entity deletion in person and occasion/group editors uses the shared `TouchPointDeleteButton` described below; saving stays in the toolbar.

### Destructive editor action

- Use `TouchPointDeleteButton` for `Delete person`, `Delete occasion`, and `Delete group` (including subgroups). It wraps `TouchPointPrimaryButtonStyle(tint: .red)` so these screens cannot drift apart.
- Place it at the very end of the edit screen, below fields, supporting copy, and recoverable errors, outside any card. Hide it during creation.
- Use solid system red, a centered white regular body label, height `50`, and continuous radius `16`. Keep the trash icon at caption typography with `.imageScale(.large)`, slightly smaller than the label.
- Every trash symbol uses `TouchPointTrashIcon` and its shared `.large` symbol scale. Preserve native menu and swipe-action layouts; the platform owns their final rendering.
- Ask for native confirmation before deleting, explain the actual consequence, dismiss only after a successful write, and show a recoverable inline red error on failure.
- Detaching a template only changes the draft association. It remains a red tertiary row action with a link icon inside the template section.

### Tertiary action

An action that occupies its own row inside a `List`, `Form`, or grouped surface card uses `TouchPointTertiaryButtonStyle`. The row has a neutral `28 x 28` icon tile with a continuous `7`-point corner radius, `12` points between icon and title, and `.subheadline.weight(.semibold)` text. Ordinary actions use the app accent for icon and title; destructive actions pass a red tint. While an asynchronous action runs, keep its title visible and replace the tile icon with a small progress indicator. The style fills the row width while the surrounding container retains native insets and separators. Do not apply it to navigation, selection, compact inline controls, menu items, toolbar, alert, or swipe actions.

### Selection row

Use a selection row for a value that opens a picker, menu, or destination. It contains an icon tile, concise label/value, and a disclosure affordance appropriate to the platform. Make the full row interactive.

## Plan the Year

This is TouchPoint's signature workflow and must stay faster than scheduling greetings individually.

1. Select people, with `Select all` available.
2. Select one or more occasions.
3. Choose how the user will reach out and select one greeting template per occasion. A neutral standard greeting remains available.
4. Review recipients, the exact number of greetings that can be created, action, and template choices before saving.

Schedule once, then allow individual message edits from Calendar or a person's detail screen. People without the selected date and greetings already planned for the same person, occasion, and day are excluded from the review count.

Selection is staged locally until final confirmation. Do not mutate the calendar when moving between steps. The first release supports `Text message`, `Email`, and `Reminder only`. These are user actions, not delivery channels controlled by TouchPoint.

## Manual send contract

TouchPoint never sends an SMS or email automatically and never connects to a third-party delivery provider.

- On iOS, text actions open `MFMessageComposeViewController` with the phone number and message body prefilled.
- On iOS, email actions open `MFMailComposeViewController` with recipient, subject, and body prefilled.
- Android must use the corresponding platform compose intent while preserving the same product behavior.
- The system composer always leaves the final `Send` action to the user. TouchPoint must not describe this as approval because there is no later automatic send.
- If the system composer reports `.sent`, mark the TouchPoint action `Completed`. This records the user's action, not carrier delivery or recipient receipt.
- Cancelled composers leave the greeting `Ready` or `Planned`. A composer error stays local and offers a retry.
- TouchPoint does not claim or expose `Delivered`, `Opened`, `Clicked`, provider-level `Failed`, unsubscribe, sender verification, or delivery analytics.
- If Messages or Mail is unavailable, explain which device capability or account is missing. Do not silently fall back to a web service or third-party provider.

## Local reminder contract

TouchPoint may schedule on-device notifications for future greeting actions. These reminders are distinct from message delivery and require no SMS/email provider.

- Ask for notification permission automatically on the first launch, with a system usage description explaining that notifications help the user remember upcoming greetings and never send messages automatically.
- Schedule each reminder for the stored UTC action instant, which was derived from `09:00` in the recipient's time zone.
- Reconcile pending notifications when events or people change and whenever the app becomes active. Completed and skipped actions must not retain pending reminders.
- Notification copy says the greeting is ready and asks the user to open TouchPoint. It must not imply that a message was or will be sent automatically.
- Store only the greeting UUID in notification metadata. Do not place phone numbers, email addresses, or message bodies in the notification payload.
- Android should preserve these semantics with a platform notification scheduled for the same action instant and an explicit permission flow where required.

## Local data

The current prototype persists a versioned JSON snapshot in the app's Application Support directory. Schema `v7` includes stable identifiers, people context, event recurrence, complete archive metadata, and a last-modified timestamp for private iCloud snapshot recovery; English display labels remain separate from machine values.

- Persist people, important dates, greeting plans, templates, contact methods, and completion state.
- Write atomically so an interrupted save does not leave a partially written snapshot.
- Keep stored values platform-neutral: UUIDs, enums with stable raw values, ISO-8601 instants, month/day pairs, and IANA time-zone identifiers.
- Decode legacy `v1`–`v6` payloads, then atomically rewrite the successfully loaded snapshot as `v7`. Never discard a readable older snapshot merely because labels or newly added fields are absent.
- Surface load or save failure inline while preserving usable in-memory content.
- Treat this file as prototype storage, not the permanent synchronization architecture. A future account/team backend must define migrations and conflict behavior explicitly.

## Content and trust

- Lead with concrete dates and names, not celebratory slogans.
- Use warm but restrained language. Avoid guilt-inducing copy such as `You forgot` or `Overdue` for personal moments.
- A scheduled message preview must show variable substitutions such as the recipient's name before opening the system composer.
- Template variables are resolved when a plan is created. `{{first_name}}` and `{{name}}` must not reach the system composer as literal text.
- Clearly distinguish `Save draft`, `Schedule`, `Open Messages/Mail`, and `Completed`.
- Never imply that TouchPoint delivered a message. The app can only record that the user completed the system compose flow.

## Accessibility and motion

- Support system text scaling, VoiceOver/TalkBack, high contrast, dark mode, and reduced motion.
- Do not encode occasion, relationship, or greeting status only with color or initials.
- Conditional rows enter from beneath their controlling row with a short opacity plus vertical move transition. Respect Reduce Motion.
- Selection changes may use light platform haptics. Scheduling and destructive actions require stronger confirmation; routine navigation does not.
- Keep animations short and functional. Greeting-page animation is a separate recipient experience and must not leak into the planning UI.

## Localization, dates, and time zones

- All user-facing strings belong in localization resources before production release.
- Store instants in UTC and store the recipient IANA time-zone identifier separately.
- Birthdays and anniversaries are date-only values. Never shift them by converting midnight across time zones.
- Create the action instant at `09:00` in the recipient's IANA time zone, then persist that instant in UTC. Planning an occasion later on the same recipient-local day keeps it due today instead of moving it to the next year.
- Show recipient date, recipient time, and zone in greeting detail. When the recipient zone differs from the device zone, also show the equivalent local `Your time` value.
- Compact Home and Calendar rows show the occasion date in the recipient's zone; Calendar grouping uses that same recipient-local day.
- Format dates, names, phone numbers, pluralization, and week starts with platform locale APIs.
- Templates declare their language. Automatic translation or AI rewriting requires an explicit preview and approval.

## Current design decisions

- Working product name: `TouchPoint`.
- Working tagline: `Plan once. Never forget again.` It belongs in store/marketing material, not repeated throughout the app UI.
- Initial shell: Home, Calendar, People, Templates.
- Home combines the next action, annual planning entry, and a filterable near-term schedule.
- Default annual-plan action: text message opened in the system Messages composer.
- Sending is always manual. No SMS/email provider integration is planned.
- Optional reminders use local device notifications. Notification permission is requested automatically on the first launch; timing and privacy preferences remain configurable in Settings.
- Source UI language for the prototype: English; localization architecture remains required.
- First-run focus offers `Work`, `Personal`, and preselected `All`.
- Work annual planning defaults to `Client`; Personal defaults to `Family`; All begins with every relationship visible.
- Focus, onboarding completion, and reminder preferences persist in `UserDefaults` and iCloud KVS; relationship data remains in the separate JSON snapshot.
- The prototype saves a `v7` local JSON snapshot between launches and migrates readable `v1`–`v6` data in place. Private iCloud backup stores the complete archive as a CloudKit asset; local operation remains available offline.
- Apple Intelligence message generation uses the on-device Foundation Models framework on iOS 26+ and never blocks manual editing.
- Apple Intelligence entry actions are disabled before presentation when the chosen language or local model is unavailable; the parent form footer explains the exact reason. Date/timing, audience, channel, and language are inherited context values, not free-form fields inside the generator.
- Standalone actions inside lists, forms, and grouped row cards share `TouchPointTertiaryButtonStyle`; ordinary actions remain accent-colored and destructive actions are red.
- Keep the minimum deployment target at iOS 18. Gate Foundation Models at runtime and explain device, settings, locale, and model-readiness limitations in context.

## Open product questions

- Should the first release support both Messages and Mail composers, or prioritize Messages in onboarding while retaining Mail?
- Which event types require a year as well as month/day?
- Should one person support multiple household or business roles?
- Will shared team accounts own people and templates at the workspace level?

## Review checklist

- The first viewport explains today's work without explanatory feature copy.
- Every scheduled item exposes person, occasion, date, contact method, time zone, and status at the appropriate detail level.
- There is only one primary action per step or card.
- Lists use native collection surfaces; related form rows share one card.
- Loading, empty, error, disabled, success, and partial-data states are designed.
- Light/dark mode and large text remain readable without overlap.
- Icons have semantic platform mappings and accessible labels.
- Date-only occasions are not accidentally converted as instants.
- AI is absent from the critical path.
- No screen implies that TouchPoint sends, delivers, tracks, or opens messages automatically.
- New reusable patterns are documented here before screen-specific variants spread.
