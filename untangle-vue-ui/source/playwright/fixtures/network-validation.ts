import { expect, test as base, type Page, type Route } from '@playwright/test'

type MutationAttempt = {
  method: string
  url: string
}

export type NetworkValidationFixtures = {
  mutationGuard: {
    attempts: MutationAttempt[]
    expectNoAttempt: () => void
  }
}

function rpcMethod(route: Route): string {
  try {
    const payload = route.request().postDataJSON()
    return typeof payload?.method === 'string' ? payload.method : ''
  } catch {
    return ''
  }
}

function isConfigurationMutation(method: string): boolean {
  // Network/system writes are deliberately blocked. Reads continue to the
  // appliance so the tests exercise the real rendered settings and options.
  return /(?:^|\.)(?:set|save|update|delete|add|remove|apply|reset|commit|create|destroy|write|enable|disable)[A-Z_a-z]/.test(
    method,
  )
}

export const test = base.extend<NetworkValidationFixtures>({
  mutationGuard: [async ({ page }, use) => {
    const attempts: MutationAttempt[] = []
    await page.route('**/*JSON-RPC*', async route => {
      const method = rpcMethod(route)
      if (isConfigurationMutation(method)) {
        attempts.push({ method, url: route.request().url() })
        // The migrated UI rolls a checkbox back when the RPC rejects. Return
        // a synthetic success so dependency tests can keep the local Vue
        // state enabled while no request reaches the appliance.
        let id: unknown = null
        try {
          id = route.request().postDataJSON()?.id ?? null
        } catch {
          // Keep the JSON-RPC response valid even for a non-JSON write body.
        }
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ jsonrpc: '2.0', id, result: null }),
        })
        return
      }
      await route.continue()
    })

    await use({
      attempts,
      expectNoAttempt() {
        expect(attempts, 'invalid client-side data must prevent a configuration RPC').toEqual([])
      },
    })

    await page.unroute('**/*JSON-RPC*')
  }, { auto: true }],
})

export { expect }

export function appPath(route: string) {
  const base = process.env.NGFW_APP_BASE_PATH || '/console'
  return `${base.replace(/\/$/, '')}/${route.replace(/^\//, '')}`
}

export async function open(page: Page, route: string, ready: string | RegExp) {
  const target = appPath(route)
  await page.goto(target)
  const escaped = target.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  await expect(page).toHaveURL(new RegExp(escaped))
  await expect(page.getByText(ready, { exact: true }).first()).toBeVisible()
}

export function visibleError(field: ReturnType<Page['getByLabel']>) {
  const input = field.locator(
    'xpath=ancestor::*[contains(concat(" ", normalize-space(@class), " "), " v-input ")][1]',
  )
  return input.locator(
    '.v-messages.error--text .v-messages__message:visible, .v-messages[role="alert"] .v-messages__message:visible',
  )
}

function inputShell(field: ReturnType<Page['getByLabel']>) {
  return field.locator(
    'xpath=ancestor::*[contains(concat(" ", normalize-space(@class), " "), " v-input ")][1]',
  )
}

export async function hasValidationError(field: ReturnType<Page['getByLabel']>) {
  const ariaInvalid = await field.getAttribute('aria-invalid')
  const classes = await inputShell(field).getAttribute('class')
  const messageCount = await visibleError(field).count()
  return ariaInvalid === 'true' || /(?:error--text|v-input--has-state)/.test(classes || '') || messageCount > 0
}

async function softValidationPoll(check: () => Promise<boolean>, expected: boolean) {
  let matched = false
  try {
    await expect.poll(check).toBe(expected)
    matched = true
  } catch {
    // Report the failed validation as a soft assertion so later matrix values
    // in the same test still execute.
  }
  await expect.soft(matched).toBe(true)
}

export async function expectInvalid(
  field: ReturnType<Page['getByLabel']>,
  value: string,
  message?: RegExp,
) {
  await field.fill(value)
  await field.blur()
  await softValidationPoll(() => hasValidationError(field), true)
  if (message) await expect.soft(inputShell(field).locator('.v-messages__message')).toContainText(message)
}

export async function expectRejected(field: ReturnType<Page['getByLabel']>, value: string) {
  await field.fill(value)
  await field.blur()
  const storedValue = await field.inputValue()
  await softValidationPoll(
    () => hasValidationError(field).then(hasError => hasError || storedValue !== value),
    true,
  )
}

export async function expectValid(field: ReturnType<Page['getByLabel']>, value: string) {
  await field.fill(value)
  await field.blur()
  await softValidationPoll(() => hasValidationError(field), false)
}

export async function clickSave(page: Page) {
  await page.getByRole('button', { name: /^save$/i }).last().click()
}

export async function clickDialogAction(page: Page, name: RegExp = /^(add|update|ok)$/i) {
  await page.getByRole('dialog').getByRole('button', { name }).click()
}

export function activeWindow(page: Page) {
  return page.locator('.v-window-item--active').last()
}
