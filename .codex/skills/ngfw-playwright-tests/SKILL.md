---
name: ngfw-playwright-tests
description: Write, extend, or review Playwright tests for the NGFW Vue UI using the repository's existing setup, fixtures, selectors, data lifecycle, and test-lane conventions. Use when a user supplies an NGFW UI scenario, validation matrix, CRUD flow, grid check, or persistence requirement and expects executable TypeScript tests.
---

# NGFW Playwright Tests

Turn an explicit NGFW UI scenario into maintainable Playwright Test code in the existing repository. The deliverable is executable, reviewable test code plus only the smallest supporting fixture, data, setup, teardown, or application test-hook changes that the scenario actually needs.

## Required operating rules

- Work from the repository at `untangle-vue-ui/source/playwright` and inspect its current `README.md`, `package.json`, `playwright.config.ts`, `.gitignore`, setup files, tests, and any local fixtures/helpers before editing. For UI ownership, follow imports: the NGFW `source/src` files may be thin route/store/setup wrappers and import shared UI from the sibling `vuntangle/src` checkout. Read the owning shared component under that shared tree plus router entries when a locator, route, conditional section, or validation rule is not already verified.
- Discover the wrapper-to-shared path instead of guessing it: search `untangle-vue-ui/source/src` for `from 'vuntangle'`, identify the wrapper and imported export, then follow that export through `vuntangle/src/shared/index.js` into the shared component tree. This import walk is the source of truth for any feature, not a fixed list of local component directories.
- Read [references/repo-playwright.md](references/repo-playwright.md) for the known repository map, current commands, lifecycle, and boundaries. Read [references/playwright-patterns.md](references/playwright-patterns.md) when designing helpers, waits, assertions, fixtures, or data-driven cases.
- For feature-specific behavior, dynamically trace the relevant wrapper, router entry under `untangle-vue-ui/source/src/router`, shared export, and owning component source. Repository knowledge notes may provide useful context, but source and the rendered DOM remain authoritative; do not require a feature-specific scenario matrix to be bundled with this skill.
- Treat the user's scenario, prerequisites, concrete steps, and expected results as the contract. Do not silently invent a route, field, value, appliance identity, API response, selector, cleanup strategy, or expected behavior. If a missing detail can be safely discovered from repository source or the rendered DOM, discover and verify it; if it still cannot be established, stop at the smallest necessary question or clearly mark the unresolved prerequisite instead of producing a falsely confident test.
- Never create or modify repository `docs/` or knowledge-base documents. Documentation is outside this skill's scope; keep the deliverable limited to the requested Playwright implementation, review, and validation.
- Separate intent from implementation: data factories/constants hold scenario values, fixtures/helpers hold repeated UI mechanics, and specs coordinate the user behavior and business assertions. Keep one-off feature assertions in the spec until repetition is demonstrated.
- Add sufficient but minimal comments to generated tests: explain non-obvious readiness waits, locator workarounds, lifecycle/cleanup decisions, or product-specific behavior; do not comment self-explanatory Playwright actions or restate the code.
- Classify each test before placing it: smoke/read-only, CRUD/state-changing, or data-validation/presentation. Keep these lanes separate. A grid-management test must not secretly create persistent appliance data; a CRUD test must own generated data and cleanup; a smoke test should use existing appliance state.
- Reuse the existing `setup-auth` project, storage state, base URL, and project dependencies. Never put credentials, storage state, appliance-specific secrets, or private URLs in source. Do not add a login to each test or copy website/ETM setup into NGFW.
- Prefer accessible, user-facing locators (`getByRole`, `getByLabel`, `getByText`, `getByPlaceholder`) and stable intentional test ids/attributes. Confirm the rendered DOM for custom Vuetify/Vuntangle controls; a Vue `v-model` or source label is not proof that an input has that accessible name. Use narrow CSS or component internals only as a last resort and document why.
- Rely on Playwright auto-waiting and retrying assertions. Wait for observable readiness—URL, heading/form, enabled control, loader disappearance, response completion when useful, toast, row, or persisted value. Do not add arbitrary `waitForTimeout` calls to mask a race. Do not catch and ignore failures.
- Assert the observable result at the right boundaries: the intended route/form, accepted values and conditional visibility, validation feedback for negative cases, save feedback/route, durable read-back in the grid/details view, and cleanup/restoration for state-changing tests. Assert the requested behavior, not Vue internals, generated classes, or an unverified RPC implementation.
- Keep tests isolated and rerunnable. Generate unique names/tags for shared appliances, resolve runtime-dependent parents/resources, and register created state for cleanup. Use `try/finally` or the repository's teardown contract so cleanup still runs after a post-create assertion fails. Do not mutate an existing known interface unless the scenario includes a verified restore path.
- Do not use `test.only`, committed `test.skip`, `page.pause()`, fixed sleeps, or browser-context bypasses in the final code. The existing config forbids `only` in CI; temporary diagnosis must be removed.

## Implementation workflow

1. Normalize the request into preconditions, navigation, each user action, the state change it should cause, expected UI/result, data ownership, and cleanup. Preserve the exact values supplied by the user and label environment-dependent values.
2. Inspect the current Playwright project selection and existing helpers. Choose the smallest existing project/file convention that will run the test. Extend a helper or fixture only when the interaction is reused or its selector logic is non-trivial.
3. Trace the route and owning Vue components. Start with the NGFW wrapper to identify the imported `vuntangle` component, then inspect the shared implementation under the sibling `vuntangle/src` checkout. Confirm source labels, conditional branches, validation limits, save behavior, success/error feedback, and the real post-save route. Then confirm accessible names/roles and custom-control behavior in the live DOM when possible.
4. Select or create scenario data. Use pre-existing named interfaces only when the test is explicitly a data-validation/read-back test against controlled appliance state. For creates, use a unique factory and runtime-discovered eligible dependencies. Never hardcode IDs merely because a sample environment currently uses them.
5. Implement the smallest reliable spec. Use semantic locators, narrow grid scopes, explicit tab/section activation, state-based waits, and clear `expect` assertions. For data matrices, use independent cases or parameterized cases only when each case has distinct, diagnosable setup and assertion output.
6. Add cleanup before or alongside the create flow. If the repository has no safe cleanup boundary for a requested CRUD operation, do not hide the gap; add the smallest explicit cleanup mechanism or report the blocker before introducing persistent mutations.
7. Run focused type/test/lint checks using the repository's installed tooling. Prefer `yarn test:interfaces` or a targeted `yarn playwright test <spec> --project=<project> --no-deps` when credentials/state are available, and run the relevant lint/type check if configured. Treat environment/auth failures separately from code failures and report them precisely.
8. Review the diff for secrets, hardcoded environment identifiers, brittle selectors, fixed sleeps, unbounded retries, accidental test-lane changes, and cleanup gaps. Summarize changed files, validation performed, and any unresolved appliance prerequisite.

## Expected handoff

When implementation is requested, return the changed files and the focused validation result. Mention any exact scenario detail that could not be verified from source/live DOM or any required appliance state. When only a design or review is requested, do not modify the repository.

## NGFW UI knowledge and discovery rules

This is reusable NGFW-specific knowledge, not a substitute for checking the
current appliance DOM. Appliance builds can differ from the checked-out
Vue/shared source; when they disagree, the rendered DOM is authoritative for
selectors.

### Application shell and routes

- The Playwright base URL normally includes the appliance `/console/` base
  path. Keep protocol, host, credentials, and storage state in runtime
  configuration only.
- The settings route source is
  `untangle-vue-ui/source/src/router/setting.js`. Verified route families
  include `settings/network/interfaces`, `settings/network/dhcp`,
  `settings/network/dns`, `settings/network/advanced`,
  `settings/network/troubleshooting`, `settings/routing/routes`,
  `settings/routing/dynamicRoutes`,
  `settings/firewall/denial-of-service`,
  `settings/services/dynamic-blocklist`, and the generic
  `settings/:category/:ruleType` rule route.
- The generic rule route produces pages such as
  `settings/firewall/access`, `settings/firewall/filter`,
  `settings/firewall/bypass`, `settings/firewall/nat`, and
  `settings/firewall/port-forward`. Confirm the exact route from the router;
  never infer it only from a sidebar label.
- The sidebar exposes expandable groups as buttons, for example
  `getByRole('button', { name: 'Firewall', exact: true })`, and child pages
  as links, for example `getByRole('link', { name: 'Access', exact: true })`.
  Prefer this real user path when it is stable.
- If the appliance does not serve deep links directly, the existing pilot has
  verified this fallback: load the console entry, push the confirmed console
  path, dispatch `PopStateEvent('popstate')`, then assert URL and heading.
  Reconfirm the base path before reusing it; this is not a blanket navigation
  bypass.

### Authenticated shell areas

The authenticated shell exposes Apps and Reports separately from Settings:

- Apps is `apps/1`. The current appliance exposes four clickable app-card
  names: Web Filter, Virus Blocker, Captive Portal, and Threat Prevention.
  Their observed routes are `apps/1/web-filter`,
  `apps/1/virus-blocker`, `apps/1/captive-portal`, and
  `apps/1/threat-prevention`. The names currently render as
  `.app-card__name--clickable` spans rather than links or buttons, so confirm
  the DOM before choosing a locator. Each app page commonly has Status and
  other section buttons plus Remove, Refresh, and Save actions; inspect those
  sections read-only and never infer a control's accessible label from its
  Vue source alone.
- Captive Portal currently exposes an active-users grid
  `#captive-portal-active-users`, a `Search here...` input, and Reset View
  and Refresh buttons. Other app pages may render metrics and report links
  without an AG Grid, so wait for the page heading and section content rather
  than assuming every app has a table.
- Reports is `reports`. It is an in-page report catalog, not a normal
  route-per-report list in the current build. The page exposes the heading
  Reports, a `Search reports ...` input, Add Condition, Add/Import, and
  Export buttons, report category containers with
  `[data-testid="report-category-title"]`, and report entries with
  `[data-testid="report-option"]` and `role="listitem"`. Report options
  can be lazy-rendered and selecting one may remain on `reports`; do not
  invent a detail URL. Treat Export and Add/Import as mutating or
  externally-effectful unless the scenario explicitly authorizes them.
- The Settings sidebar's authenticated hrefs currently include these groups:
  Network: `settings/network/interfaces`,
  `settings/network/port-forward`, `settings/network/nat`,
  `settings/network/bypass`, `settings/network/dhcp`,
  `settings/network/dns`, `settings/network/advanced`, and
  `settings/network/troubleshooting`; Routing:
  `settings/routing/routes` and `settings/routing/dynamicRoutes`; Firewall:
  `settings/firewall/filter`, `settings/firewall/access`, and
  `settings/firewall/denial-of-service`.
- The System menu currently exposes
  `settings/system/settings`, `settings/system/administration`,
  `settings/system/events`, `settings/system/email`,
  `settings/system/logging`, `settings/system/local-directory`,
  `settings/system/upgrade`, and `settings/system/about`. Services
  currently exposes `settings/services/branding-manager`,
  `configuration-backup`, `directory-connector`,
  `dynamic-blocklist`, `intrusion-prevention`, `live-support`,
  `policy-manager`, `reports`, `wan-balancer`, and
  `wan-failover` under the `settings/services/` prefix.
- These menu hrefs are a live authenticated inventory. The generic router
  remains the source of truth for route ownership, and feature availability
  can vary by appliance license or build. If a menu route renders an error or
  license page, assert and report that observable state instead of fabricating
  feature locators.

### Source-to-shared trace

The product rules wrapper
`untangle-vue-ui/source/src/components/settings/rules/RulesList.vue`
imports `RulesList` from `vuntangle`. Follow the export in
`../vuntangle/src/shared/index.js` to
`../vuntangle/src/shared/Rules/RulesList.vue` and
`../vuntangle/src/shared/Rules/RulesGrid.vue`. The wrapper maps route
`access` to appliance configuration `access-rules`.

For every feature, use the wrapper for route/store/lifecycle mapping, the
shared component for likely structure, and the live DOM for final names, roles,
attributes, and conditional rendering.

### Grid and row contract

NGFW grids commonly use the shared `u-grid`/AG Grid component. After
confirming the feature id, use a scoped row locator:

```ts
const grid = page.locator('#access-rules')
const rows = grid.locator('.ag-center-cols-container .ag-row')
const row = rows.filter({ hasText: expectedDescription }).first()
await expect(grid).toBeVisible()
await expect(row).toBeVisible()
```

Screen/grid ids observed in the current UI are:

| Screen | Route | Grid id |
| --- | --- | --- |
| Interfaces | `settings/network/interfaces` | `appliance-interfaces` |
| Firewall Access | `settings/firewall/access` | `access-rules` |
| Firewall Filter | `settings/firewall/filter` | `filter-rules` |
| DoS rules | `settings/firewall/denial-of-service` | `shield-rules` |
| DHCP | `settings/network/dhcp` | `dhcp-reservations`, `leases`, `dhcp-relays` |
| Static routes | `settings/routing/routes` | `static-routes` |
| Dynamic blocklists | `settings/services/dynamic-blocklist` | `dynamic-blocklists` |

- Scope rows/cells to the grid; do not use page-wide text when navigation and
  several grids are present.
- AG Grid headers expose `role="columnheader"`, cells expose
  `role="gridcell"`, and rows are under
  `.ag-center-cols-container .ag-row`. Prefer a business value over row
  index or generated row id.
- Use verified `col-id` cells. Rules grids may expose `description`,
  `conditions`, and `action`, or split conditions into
  `source-conditions`, `destination-conditions`, and
  `other-conditions`; inspect the current DOM before choosing.
- A grid may render `No data available`; wait for observable loading
  completion, then assert the expected row or explicit empty state.
- `Search here...` is common but not unique on multi-grid screens. Scope it
  to the active grid/card. Grid checkboxes/actions may have weak names; scope
  them to a verified row/cell and never use page-wide `nth()`.

The live Access grid currently has Rule Id, Enabled, IPv6, Description,
Source, Destination, Other, and Action columns. Its SSH row is rendered as
`Allow SSH`, with `Destination Port == 22`, `Protocol == TCP`, and
`Accept`. This is appliance data, not a universal constant: another build
may use `Accept SSH on LANs`. For “SSH rule”, verify the actual description
and assert the required port/protocol/action/scope instead of inventing a
label.

### Controls, dialogs, and waits

- Assert a visible heading for route readiness, then the feature form/grid and
  loader completion. When confirmed for the feature, wait for the Vuetify
  global `.v-overlay--active` to have count zero; never add fixed sleeps.
- Vuetify `u-btn` controls are generally exposed as buttons named Save,
  Refresh, Add Rule, Add Interface, Import Settings, and Export Settings.
  Scope repeated actions to the feature card.
- Access `Add Rule` opens a non-persisting dialog. Confirmed labels include
  Description, Rule Enabled, and IPv6 Support Enabled. Condition/action
  selectors are custom Vuetify controls often rendered as
  `[role="button"][aria-haspopup="listbox"]`, not native selects or
  comboboxes. Open the visible control, wait for the visible list, and choose
  a rendered option; use `selectOption` only for a verified native select.
- The dialog exposes Cancel and Add Rule. Exploration may open and cancel it;
  it must not click the committing Add Rule unless the scenario is a CRUD test
  with owned data and cleanup.
- Native text, number, checkbox, radio, and custom Vuetify controls are mixed.
  Use `getByLabel` only after confirming the rendered association. If a
  custom checkbox lacks an accessible name, scope to its visible label/field
  container and use its verified input/control structure.
- Screens can repeat controls: DHCP has Server/Relays sections and multiple
  grids; Advanced has section buttons and checkboxes; DoS has a checkbox,
  number field, and rules grid. Assert the active section before locating a
  repeated search, refresh, or table.
- A page may show Save while default rules are explicitly read-only. Do not
  infer editability from a toolbar button or click a read-only row expecting a
  dialog; assert the notice/absence of row actions when relevant.

### Test-lane rules

- Route/grid presence is smoke or data-validation: read controlled appliance
  state and do not add, edit, delete, toggle, reorder, import, export, or save.
- Existing rules are appliance preconditions. If name, enabled state, source
  scope, destination port, protocol, or action matters, make each expectation
  explicit. If the user only says “SSH rule”, report unresolved LAN/WAN or
  exact-description ambiguity after inspecting the live row.
- Read-only exploration may expand navigation, switch visible sections, use a
  search field, inspect checkboxes, and open/cancel dialogs. It must not change
  a checkbox, drag a row, choose a persistent value, or invoke a mutating
  operation.
