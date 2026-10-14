import fs from 'node:fs/promises'
import path from 'node:path'
import { test as setup, expect } from '@playwright/test'

const storageState =
  process.env.NGFW_STORAGE_STATE || 'playwright/.auth/admin.json'

setup('authenticate to the NGFW appliance', async ({ page }) => {
  const username = process.env.NGFW_USERNAME
  const password = process.env.NGFW_PASSWORD

  if (!username || !password) {
    throw new Error(
      'NGFW_USERNAME and NGFW_PASSWORD are required for the setup-auth project'
    )
  }

  const appBase = (process.env.NGFW_APP_BASE_PATH || '/console').replace(
    /\/$/,
    ''
  )

  // Try the Vue login route first.
  await page.goto(`${appBase}/login`, {
    waitUntil: 'domcontentloaded',
  })

  if (/\/setup(?:\/|$)/.test(page.url())) {
    throw new Error(
      'The appliance is in setup mode; complete appliance setup before running Config → Network tests'
    )
  }

  // Fall back to the legacy NGFW authentication route if necessary.
  if (!/\/login(?:\/|$)/.test(new URL(page.url()).pathname)) {
    await page.goto('/auth/login?url=%2Fadmin&realm=Administrator', {
      waitUntil: 'domcontentloaded',
    })
  }

  if (/\/setup(?:\/|$)/.test(page.url())) {
    throw new Error(
      'The appliance is in setup mode; complete appliance setup before running tests'
    )
  }

  const usernameInput = page
    .locator(
      'input[name="username"], input[placeholder="username"], input[placeholder="Username"]'
    )
    .first()

  const passwordInput = page
    .locator(
      'input[name="password"], input[placeholder="password"], input[placeholder="Password"]'
    )
    .first()

  await expect(usernameInput).toBeVisible()
  await usernameInput.fill(username)
  await passwordInput.fill(password)

  const submit = page.getByRole('button', {
    name: /sign in|login/i,
  }).first()

  if (await submit.isVisible().catch(() => false)) {
    await submit.click()
  } else {
    await passwordInput.press('Enter')
  }

  await expect(page).not.toHaveURL(
    /(?:\/login|\/auth\/login)(?:$|[/?#])/,
    { timeout: 30_000 }
  )

  await fs.mkdir(path.dirname(storageState), { recursive: true })
  await page.context().storageState({ path: storageState })
})
