import { test, expect } from '@playwright/test'

test('Interfaces screen renders the appliance interface grid', async ({ page }) => {
  await page.goto('', { waitUntil: 'commit' })
  await page.evaluate(() => {
    window.history.pushState({}, '', '/console/settings/network/interfaces')
    window.dispatchEvent(new PopStateEvent('popstate'))
  })

  await expect(page).toHaveURL(new RegExp('settings/network/interfaces(?:$|[?#])'), { timeout: 30_000 })

  const grid = page.locator('#appliance-interfaces')
  await expect(grid).toBeVisible({ timeout: 30_000 })
  const firstRow = grid.locator('.ag-center-cols-container .ag-row').first()
  await expect(firstRow).toBeVisible({ timeout: 30_000 })
  for (const column of ['device', 'description', 'status', 'config']) {
    await expect(firstRow.locator(`[col-id="${column}"]`)).toBeVisible()
  }
})
