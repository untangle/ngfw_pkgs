# Playwright patterns for generated tests

Use the Playwright Test API already installed by the repository. This is a
focused reliability guide, not a replacement for the official API reference.

## Locators

Use the strongest locator that matches what a user can identify:

~~~ts
page.getByRole('button', { name: /save/i })
page.getByRole('heading', { name: /edit/i })
page.getByLabel('Field Label', { exact: true })
page.getByPlaceholder('Expected placeholder', { exact: true })
page.getByText(itemName, { exact: true })
page.getByTestId('intentional-stable-id')
~~~

For repeated content, narrow the scope before asserting:

~~~ts
const list = page.getByTestId('records-list')
const row = list.getByRole('row').filter({ hasText: itemName }).first()
await row.scrollIntoViewIfNeeded()
await expect(row.getByTestId('status-cell')).toContainText(expectedStatus)
~~~

Use `getByRole`, `getByLabel`, and other user-facing locators first, followed
by an intentional test id or stable attribute. Custom controls may require
clicking the visible closed control and selecting a visible option by role.
Do not use `selectOption` unless the DOM contains a native select. If two
controls share a translated label, scope to the active section or use a stable
relationship verified in the rendered DOM.

## Actions and state-based waits

Playwright actions wait for actionability, and web-first assertions retry.
Follow an action with the observable state it should cause:

~~~ts
await page.getByRole('button', { name: /save/i }).click()
await expect(page).toHaveURL(/<expected-route-pattern>/)
await expect(page.getByRole('heading', { name: /expected page/i })).toBeVisible()
await expect(page.getByTestId('records-list')).toBeVisible()
~~~

Reaching a URL is not proof that the page is ready. Wait for meaningful
signals such as a heading, enabled control, loader disappearance, response
completion when useful, toast, row, or persisted value. For slow mutations,
use a bounded operation-specific timeout rather than a fixed sleep. When a
mutation returns to the page already under test, reuse that route and wait for
the application state transition instead of reloading it.

Useful assertions include `toHaveURL`, `toBeVisible`, `toBeHidden`,
`toBeEnabled`, `toBeDisabled`, `toHaveText`, `toContainText`, `toHaveValue`,
`toBeChecked`, `toHaveAttribute`, and `toHaveCount`. Use `expect.poll` only
for genuine eventual application state when there is no better UI readiness
signal, with a bounded timeout and meaningful callback.

Avoid `waitForTimeout`. Avoid `networkidle` as a generic cure on applications
with long-lived requests. Use `page.waitForURL` for explicit route
transitions, `locator.waitFor` for a concrete state, and
`page.waitForResponse` only when a stable operation predicate has been
verified in application source; the UI assertion remains the primary contract.

## Forms, tabs, and conditional controls

Activate the user-visible tab or section before interacting with controls that
are rendered conditionally:

~~~ts
await page.getByRole('tab', { name: /advanced/i }).click()
await expect(page.getByLabel('Dependent Field', { exact: true })).toBeVisible()
await page.getByLabel('Dependent Field', { exact: true }).fill(value)
~~~

For a mode change, assert the mode and then assert the dependent controls:

~~~ts
await page.getByRole('radio', { name: /^mode b$/i }).check()
await expect(page.getByLabel('Mode B Value', { exact: true })).toBeVisible()
await expect(page.getByLabel('Mode A Value', { exact: true })).toBeHidden()
~~~

Use the actual rendered role. Custom radio, switch, and input wrappers can
alter the accessible structure; verify it before committing a selector. Use
`toBeDisabled` for controls disabled by the UI rather than merely asserting
their value.

## Fixtures and helpers

Import test and expect from the repository's stable fixture entry point when
one exists; otherwise use `@playwright/test`. A fixture should provide shared
context or repeated actions without hiding the business assertion. A helper
should accept a data object and return useful locators or values rather than
embedding scenario-specific values:

~~~ts
type RecordData = { name: string; category?: string }

async function openRecords(page: Page) {
  await page.goto('/feature/records')
  await expect(page.getByTestId('records-list')).toBeVisible()
}
~~~

When using `test.extend`, keep environment setup worker-scoped only when it is
safe for concurrent tests. Do not change concurrency without reviewing data
isolation and cleanup.

## Assertions and errors

Every requested expected result should become a focused assertion with a
message implied by the locator or, where useful, an explicit reason. Prefer a
small number of durable business assertions over huge snapshots. For
negative validation, assert the message or field error and that save did not
produce the successful postcondition. For save errors, assert the visible
rollback/error signal when the scenario covers it; do not turn errors into
passes.

Do not use broad `try/catch` blocks that return undefined or log and continue.
Catch only to attach cleanup or context, then rethrow. If cleanup fails,
preserve the original failure and report cleanup failure in a controlled way
supported by the test framework.

## Data-driven tests

Use independent cases for independent validation rules. A compact table is
appropriate when each row has the same setup/action/expectation shape and
produces useful case titles:

~~~ts
for (const scenario of scenarios) {
  test(`Feature: rejects ${scenario.title}`, async ({ page }) => {
    // scenario-specific data, action, and assertion
  })
}
~~~

Prefer `test.describe` or a fixture when setup/teardown is shared, and use
`test.step` for readable phases. Do not make one test silently cover multiple
unrelated rules.

## Cleanup

For a create flow, register identity as soon as the save is accepted, then
clean up in `finally` or a teardown fixture. A final list assertion is not
cleanup. For an edit flow, capture original values before mutation and restore
them if the application supports a safe UI/API contract. If the scenario only
validates existing data, do not add cleanup that changes that data.
