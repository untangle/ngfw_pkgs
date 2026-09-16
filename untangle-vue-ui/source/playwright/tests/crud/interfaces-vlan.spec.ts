import { test, expect, type Locator, type Page } from '@playwright/test'

const interfaceName = 'vlanBridge'
const parentInterfaceName = 'External'
const vlanId = '11'

const uiReadyTimeout = 60_000
const saveNavigationTimeout = 60_000

test.describe.configure({ timeout: 180_000 })

async function waitForInterfacesReady(page: Page, grid: Locator) {
  // Interface.vue loads settings and status independently. During either
  // request the shared layout renders Vuetify's global page-load overlay.
  // Waiting for the route alone can therefore race the first usable grid.
  await expect(page.getByRole('heading', { name: /^interfaces$/i })).toBeVisible({ timeout: uiReadyTimeout })
  await expect(page.locator('.v-overlay--active')).toHaveCount(0, { timeout: uiReadyTimeout })

  const addInterfaceButton = page.getByRole('button', { name: /add interface/i })
  await expect(addInterfaceButton).toBeVisible({ timeout: uiReadyTimeout })
  await expect(addInterfaceButton).toBeEnabled({ timeout: uiReadyTimeout })
  await expect(grid).toBeVisible({ timeout: uiReadyTimeout })
  await expect(grid.locator('.ag-center-cols-container .ag-row').first()).toBeVisible({ timeout: uiReadyTimeout })
}

async function openInterfaces(page: Page) {
  const interfacesUrl = new RegExp('settings/network/interfaces(?:$|[?#])')
  if (!interfacesUrl.test(page.url())) {
    await page.goto('', { waitUntil: 'commit' })
    await page.evaluate(() => {
      window.history.pushState({}, '', '/console/settings/network/interfaces')
      window.dispatchEvent(new PopStateEvent('popstate'))
    })
  }
  await expect(page).toHaveURL(/settings\/network\/interfaces(?:$|[?#])/, { timeout: 30_000 })

  const grid = page.locator('#appliance-interfaces')
  await waitForInterfacesReady(page, grid)
  return grid
}

function rowsFor(grid: Locator, name: string) {
  return grid.locator('.ag-center-cols-container .ag-row').filter({ hasText: name })
}

function firstRowFor(grid: Locator, name: string) {
  return rowsFor(grid, name).first()
}

function statusCard(page: Page) {
  const statusHeading = page.getByRole('heading', { name: /^status$/i })
  return statusHeading.locator('xpath=ancestor::div[contains(@class, "v-card")][1]')
}

async function deleteTemporaryInterface(page: Page) {
  const grid = await openInterfaces(page)
  const row = firstRowFor(grid, interfaceName)
  if ((await row.count()) === 0) return

  const device = (await row.locator('[col-id="device"]').innerText()).trim()
  await page.evaluate((deviceName) => {
    window.history.pushState({}, '', `/console/settings/network/interfaces/${encodeURIComponent(deviceName)}`)
    window.dispatchEvent(new PopStateEvent('popstate'))
  }, device)
  await expect(page).toHaveURL(/settings\/network\/interfaces\/[^/]+(?:$|[?#])/, { timeout: 30_000 })

  const deleteButton = page.getByRole('button', { name: /delete interface/i })
  await expect(deleteButton).toBeVisible({ timeout: 30_000 })
  await deleteButton.click()

  const dialog = page.getByRole('dialog').last()
  await expect(dialog).toBeVisible()
  await dialog.getByRole('button', { name: /^yes$/i }).click()

  await expect(page).toHaveURL(/settings\/network\/interfaces(?:$|[?#])/, { timeout: saveNavigationTimeout })
  const finalGrid = page.locator('#appliance-interfaces')
  await waitForInterfacesReady(page, finalGrid)
  await expect(rowsFor(finalGrid, interfaceName)).toHaveCount(0, { timeout: 30_000 })
}

test('VLAN CRUD: grid stays unaddressed and status inherits External IPv4', async ({ page }) => {
  let saveClicked = false
  const initialGrid = await openInterfaces(page)

  const existingRow = rowsFor(initialGrid, interfaceName)
  await expect(existingRow).toHaveCount(0)

  const parentRow = firstRowFor(initialGrid, parentInterfaceName)
  await expect(parentRow).toBeVisible({ timeout: 30_000 })
  await expect(parentRow.locator('[col-id="description"]')).toHaveText(parentInterfaceName)
  await parentRow.locator('[col-id="description"]').click()

  const parentStatusCard = statusCard(page)
  await expect(parentStatusCard).toBeVisible({ timeout: 30_000 })
  const parentStatusIpv4Row = parentStatusCard.locator('table').first().locator('tbody tr').filter({ hasText: /IPv4 Address/i })
  await expect(parentStatusIpv4Row).toBeVisible({ timeout: 30_000 })
  const parentAddressText = (await parentStatusIpv4Row.innerText()).trim()
  const parentAddressMatch = parentAddressText.match(/\b(?:\d{1,3}\.){3}\d{1,3}(?:\/\d{1,2})?\b/)
  expect(parentAddressMatch, `Expected ${parentInterfaceName} status to have a visible IPv4 address`).not.toBeNull()
  const parentAddress = parentAddressMatch![0]

  try {
    await page.getByRole('button', { name: /add interface/i }).click()
    await page.getByText('VLAN', { exact: true }).click()
    await expect(page).toHaveURL(/settings\/network\/interfaces\/add\/vlan(?:$|[?#])/, { timeout: 30_000 })

    await page.getByLabel('Interface Name').fill(interfaceName)
    await page.getByLabel('VLAN ID').fill(vlanId)

    await page.getByRole('button', { name: /config type.*addressed/i }).click()
    await page.getByRole('option', { name: 'Bridged', exact: true }).click()

    const parentButton = page.getByRole('button', { name: /^\s*Parent Interface\s*$/ })
    await parentButton.click()
    const parentMenu = page.locator('.v-menu__content:visible').last()
    await expect(parentMenu.getByRole('option', { name: parentInterfaceName, exact: true })).toBeVisible()
    await parentMenu.getByRole('option', { name: parentInterfaceName, exact: true }).click()

    const bridgedToButton = page.getByRole('button', { name: /^\s*Bridged To\s*$/ })
    await bridgedToButton.click()
    const bridgedToMenu = page.locator('.v-menu__content:visible').last()
    await expect(bridgedToMenu.getByRole('option', { name: parentInterfaceName, exact: true })).toBeVisible()
    await bridgedToMenu.getByRole('option', { name: parentInterfaceName, exact: true }).click()

    const parentControl = page.locator('[role="button"][aria-haspopup="listbox"]').filter({ hasText: /Parent Interface/ })
    const bridgedToControl = page.locator('[role="button"][aria-haspopup="listbox"]').filter({ hasText: /Bridged To/ })
    await expect(parentControl).toContainText(parentInterfaceName)
    await expect(bridgedToControl).toContainText(parentInterfaceName)

    saveClicked = true
    await page.getByRole('button', { name: /^\s*save\s*$/i }).click()
    await expect(page).toHaveURL(/settings\/network\/interfaces(?:$|[?#])/, { timeout: saveNavigationTimeout })

    const savedGrid = page.locator('#appliance-interfaces')
    await waitForInterfacesReady(page, savedGrid)
    const savedRow = firstRowFor(savedGrid, interfaceName)
    await expect(savedRow).toBeVisible({ timeout: uiReadyTimeout })
    await expect(savedRow.locator('[col-id="description"]')).toHaveText(interfaceName)
    await expect(savedRow.locator('[col-id="config"]')).toHaveText(/Bridged/i)

    await savedRow.locator('[col-id="description"]').click()
    const selectedStatusCard = statusCard(page)
    await expect(selectedStatusCard).toBeVisible({ timeout: 30_000 })
    const statusIpv4Row = selectedStatusCard.locator('table').first().locator('tbody tr').filter({ hasText: /IPv4 Address/i })
    await expect(statusIpv4Row).toBeVisible({ timeout: 30_000 })
    await expect(statusIpv4Row).toContainText(parentAddress)

    // Assert after status data is loaded; the initial grid snapshot can be stale.
    const savedIpv4Cell = savedRow.locator('[col-id="ipv4Address"]')
    await savedIpv4Cell.scrollIntoViewIfNeeded()
    await expect(savedIpv4Cell).toHaveText(/^\s*(?:-|)\s*$/)
    await expect(savedIpv4Cell).not.toContainText(parentAddress)
  } finally {
    if (saveClicked) await deleteTemporaryInterface(page)
  }
})
