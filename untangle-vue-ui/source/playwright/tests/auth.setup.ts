import fs from 'node:fs'
import path from 'node:path'
import { test as setup, expect } from '@playwright/test'

const storageState = process.env.NGFW_STORAGE_STATE || 'playwright/.auth/admin.json'

setup('create authenticated NGFW state', async ({ page }) => {
  const username = process.env.NGFW_USERNAME
  const password = process.env.NGFW_PASSWORD
  if (!username || !password) {
    throw new Error('NGFW_USERNAME and NGFW_PASSWORD are required for the setup-auth project')
  }

  const appBase = (process.env.NGFW_APP_BASE_PATH || '/console').replace(/\/$/, '')
  // The Vue router exposes authentication at /login. Visiting the app root
  // produces the SPA's not-found view because the shell has no root route.
  await page.goto(`${appBase}/login`)
  if (/\/setup(?:\/|$)/.test(page.url())) {
    throw new Error('The appliance is in setup mode; complete appliance setup before running Config → Network tests')
  }
  if (!/\/login(?:\/|$)/.test(page.url())) {
    throw new Error(`The appliance did not expose the Vue login route (landed at ${new URL(page.url()).pathname})`)
  }
  await page.getByPlaceholder(/Username:?$/, { exact: true }).fill(username)
  await page.getByPlaceholder(/Password:?$/, { exact: true }).fill(password)
  await page.getByRole('button', { name: /sign in|login/i }).click()
  await expect(page).not.toHaveURL(/(?:\/login|\/auth\/login)(?:$|\?)/)

  fs.mkdirSync(path.dirname(storageState), { recursive: true })
  await page.context().storageState({ path: storageState })
})
