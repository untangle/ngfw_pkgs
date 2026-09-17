import { test as setup, expect } from '@playwright/test'
import fs from 'node:fs/promises'
import path from 'node:path'

const authFile = process.env.NGFW_STORAGE_STATE || 'playwright/.auth/admin.json'

setup('authenticate to the NGFW appliance', async ({ page }) => {
  const username = process.env.NGFW_USERNAME
  const password = process.env.NGFW_PASSWORD

  if (!username || !password) {
    throw new Error('Set NGFW_USERNAME and NGFW_PASSWORD before running the NGFW Playwright pilot.')
  }

  await page.goto('/auth/login?url=%2Fadmin&realm=Administrator', { waitUntil: 'domcontentloaded' })
  await page.locator('input[name="username"], input[placeholder="username"]').first().fill(username)
  await page.locator('input[name="password"], input[placeholder="password"]').first().fill(password)
  const submit = page.getByRole('button', { name: /sign in|login/i }).first()
  if (await submit.isVisible().catch(() => false)) {
    await submit.click()
  } else {
    await page.locator('input[name="password"], input[placeholder="password"]').first().press('Enter')
  }
  await expect(page).not.toHaveURL(new RegExp('login(?:$|[/?#])'), { timeout: 30_000 })

  await fs.mkdir(path.dirname(authFile), { recursive: true })
  await page.context().storageState({ path: authFile })
})
