import { test, expect, type Locator, type Page } from '@playwright/test'
import { createVlanAutoData, createVlanData, createVlanPppoeData, createVlanQosData } from '../data/vlan-test-data'

const interfaceName = 'vlanBridge'
const parentInterfaceName = 'External'
const vlanId = '11'
const createSaveNavigationTimeout = 90_000

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

async function findAvailableVlan(
  grid: Locator,
  parentDevice: string,
  startingVlanId: number,
  startingInterfaceName = `vlan${startingVlanId}`,
) {
  const nameParts = startingInterfaceName.match(/^(.*?)(\d+)$/)

  for (let vlanIdNumber = startingVlanId; vlanIdNumber <= 4094; vlanIdNumber += 1) {
    const interfaceName = nameParts
      ? `${nameParts[1]}${vlanIdNumber}`
      : vlanIdNumber === startingVlanId
      ? startingInterfaceName
      : `${startingInterfaceName}${vlanIdNumber}`
    const vlanDevice = `${parentDevice}.${vlanIdNumber}`
    const interfaceNameExists = (await rowsFor(grid, interfaceName).count()) > 0
    const vlanIdExists = (await rowsFor(grid, vlanDevice).count()) > 0

    if (!interfaceNameExists && !vlanIdExists) {
      return {
        interfaceName,
        vlanId: String(vlanIdNumber),
        vlanDevice,
      }
    }
  }

  throw new Error(`No available VLAN ID found from ${startingVlanId} through 4094`)
}

function visibleMenu(page: Page) {
  return page.locator('.v-menu__content:visible').last()
}

async function setLabeledControl(control: Locator, checked: boolean) {
  await expect(control).toBeVisible({ timeout: uiReadyTimeout })

  if ((await control.isChecked()) !== checked) {
    // Vuetify renders the input behind a ripple element. Clicking the
    // associated label avoids the ripple intercepting the input click.
    const label = control.locator('xpath=../../label')
    await expect(label).toBeVisible({ timeout: uiReadyTimeout })
    await label.click()
  }

  if (checked) {
    await expect(control).toBeChecked({ timeout: uiReadyTimeout })
  } else {
    await expect(control).not.toBeChecked({ timeout: uiReadyTimeout })
  }
}

function statusCard(page: Page) {
  const statusHeading = page.getByRole('heading', { name: /^status$/i })
  return statusHeading.locator('xpath=ancestor::div[contains(@class, "v-card")][1]')
}

async function deleteTemporaryInterface(page: Page, targetInterfaceName = interfaceName) {
  const grid = await openInterfaces(page)
  const row = firstRowFor(grid, targetInterfaceName)
  if ((await row.count()) === 0) return

  const device = (await row.locator('[col-id="device"]').innerText()).trim()
  await page.evaluate(deviceName => {
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
  await expect(rowsFor(finalGrid, targetInterfaceName)).toHaveCount(0, { timeout: 30_000 })
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
  const parentStatusIpv4Row = parentStatusCard
    .locator('table')
    .first()
    .locator('tbody tr')
    .filter({ hasText: /IPv4 Address/i })
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

    const parentControl = page
      .locator('[role="button"][aria-haspopup="listbox"]')
      .filter({ hasText: /Parent Interface/ })
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
    const statusIpv4Row = selectedStatusCard
      .locator('table')
      .first()
      .locator('tbody tr')
      .filter({ hasText: /IPv4 Address/i })
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

test('VLAN create: creates vlan1 on External and displays connected interface status', async ({ page }) => {
  test.setTimeout(240_000)
  let saveClicked = false

  try {
    const initialGrid = await openInterfaces(page)
    const parentRow = firstRowFor(initialGrid, createVlanData.parentInterface)
    await expect(parentRow).toBeVisible({ timeout: uiReadyTimeout })
    await expect(parentRow.locator('[col-id="description"]')).toHaveText(createVlanData.parentInterface)
    const parentDevice = (await parentRow.locator('[col-id="device"]').innerText()).trim()
    const expectedDevice = `${parentDevice}.${createVlanData.vlanId}`

    await test.step('verify the VLAN name and device are available', async () => {
      // Fail clearly if the fixed scenario data already exists.
      await expect(rowsFor(initialGrid, createVlanData.interfaceName)).toHaveCount(0)
      await expect(rowsFor(initialGrid, expectedDevice)).toHaveCount(0)
    })

    await test.step('click Add Interface and select VLAN', async () => {
      await page.getByRole('button', { name: /add interface/i }).click()
      await page.getByText('VLAN', { exact: true }).click()
      await expect(page).toHaveURL(/settings\/network\/interfaces\/add\/vlan(?:$|[?#])/, {
        timeout: 30_000,
      })
      await expect(page.getByRole('heading', { name: /add .*vlan/i })).toBeVisible({ timeout: 30_000 })
    })

    await test.step('enter VLAN details and select Addressed', async () => {
      await page.getByLabel('Interface Name', { exact: true }).fill(createVlanData.interfaceName)

      const configTypeButton = page.getByRole('button', { name: /config type/i })
      await configTypeButton.click()
      const configTypeMenu = visibleMenu(page)
      await configTypeMenu.getByRole('option', { name: createVlanData.configType, exact: true }).click()
      await expect(configTypeButton).toContainText(createVlanData.configType)

      const parentButton = page.getByRole('button', { name: /^Parent Interface$/ })
      await parentButton.click()
      const parentMenu = visibleMenu(page)
      await expect(parentMenu.getByRole('option', { name: createVlanData.parentInterface, exact: true })).toBeVisible()
      await parentMenu.getByRole('option', { name: createVlanData.parentInterface, exact: true }).click()

      const vlanIdField = page.getByLabel('VLAN ID', { exact: true })
      await vlanIdField.fill(String(createVlanData.vlanId))
      await vlanIdField.press('Tab')
      await expect(vlanIdField).toHaveValue(String(createVlanData.vlanId))
    })

    await test.step('enable WAN and NAT after entering VLAN ID', async () => {
      const wanSwitch = page.getByLabel('WAN Interface', { exact: true })
      await expect(wanSwitch).toBeEnabled({ timeout: uiReadyTimeout })
      await setLabeledControl(wanSwitch, createVlanData.wanInterface)

      const natCheckbox = page.getByLabel('NAT traffic exiting this interface (and bridged peers)', { exact: true })
      await setLabeledControl(natCheckbox, createVlanData.natTraffic)
    })

    await test.step('select Auto (DHCP) on the IPv4 tab', async () => {
      await page.getByRole('button', { name: 'IPv4', exact: true }).click()
      const ipv4Auto = page.getByRole('radio', { name: createVlanData.ipv4ConfigType, exact: true })
      await setLabeledControl(ipv4Auto, true)
    })

    await test.step('select IPv6 Disabled and configure QoS and VRRP', async () => {
      await page.getByRole('button', { name: 'IPv6', exact: true }).click()
      const ipv6Disabled = page.getByRole('radio', { name: createVlanData.ipv6ConfigType, exact: true })
      await setLabeledControl(ipv6Disabled, true)

      const qosTab = page.getByRole('button', { name: /^qos$/i })
      await expect(qosTab).toBeVisible({ timeout: uiReadyTimeout })
      await qosTab.click()
      const qosEnabled = page.getByLabel('QoS Enabled', { exact: true })
      await setLabeledControl(qosEnabled, createVlanData.qosEnabled)

      const uploadBandwidth = page.getByLabel('Upload', { exact: true })
      const downloadBandwidth = page.getByLabel('Download', { exact: true })
      await expect(uploadBandwidth).toBeEnabled({ timeout: uiReadyTimeout })
      await expect(downloadBandwidth).toBeEnabled({ timeout: uiReadyTimeout })
      await uploadBandwidth.fill(String(createVlanData.uplinkBandwidth))
      await downloadBandwidth.fill(String(createVlanData.downlinkBandwidth))
      await expect(uploadBandwidth).toHaveValue(String(createVlanData.uplinkBandwidth))
      await expect(downloadBandwidth).toHaveValue(String(createVlanData.downlinkBandwidth))

      const vrrpTab = page.getByRole('button', { name: /^vrrp$/i })
      await expect(vrrpTab).toBeVisible({ timeout: uiReadyTimeout })
      await vrrpTab.click()
      const vrrpEnabled = page.getByLabel('VRRP Enabled', { exact: true })
      await setLabeledControl(vrrpEnabled, createVlanData.vrrpEnabled)

      const vrrpId = page.getByLabel('VRRP ID', { exact: true })
      const vrrpPriority = page.getByLabel('VRRP Priority', { exact: true })
      await expect(vrrpId).toBeEnabled({ timeout: uiReadyTimeout })
      await expect(vrrpPriority).toBeEnabled({ timeout: uiReadyTimeout })
      await vrrpId.fill(String(createVlanData.vrrpId))
      await vrrpPriority.fill(String(createVlanData.vrrpPriority))
      await expect(vrrpId).toHaveValue(String(createVlanData.vrrpId))
      await expect(vrrpPriority).toHaveValue(String(createVlanData.vrrpPriority))
    })

    await test.step('save VLAN and verify the created row', async () => {
      const saveButton = page.getByRole('button', { name: /^save$/i })
      await expect(saveButton).toBeEnabled({ timeout: uiReadyTimeout })
      saveClicked = true
      await saveButton.click()
      await expect(page).toHaveURL(/settings\/network\/interfaces(?:$|[?#])/, {
        timeout: createSaveNavigationTimeout,
      })

      const savedGrid = page.locator('#appliance-interfaces')
      await waitForInterfacesReady(page, savedGrid)
      const savedRow = firstRowFor(savedGrid, createVlanData.interfaceName)
      await expect(savedRow).toBeVisible({ timeout: uiReadyTimeout })
      await savedRow.scrollIntoViewIfNeeded()

      await expect(savedRow.locator('[col-id="device"]')).toHaveText(expectedDevice)
      await expect(savedRow.locator('[col-id="description"]')).toHaveText(createVlanData.interfaceName)
      await expect(savedRow.locator('[col-id="status"]')).toContainText(/connected/i)
      await expect(savedRow.locator('[col-id="duplex"]')).toHaveText('Full Duplex')
      await expect(savedRow.locator('[col-id="speed"]')).toHaveText('1 Gbps')
      await expect(savedRow.locator('[col-id="config"]')).toHaveText(createVlanData.configType)
      await expect(savedRow.locator('[col-id="ipv4Address"]')).toHaveText(/^\s*(?:-|)\s*$/)
    })
  } finally {
    if (saveClicked) await deleteTemporaryInterface(page, createVlanData.interfaceName)
  }
})

test('create-vlan-auto: creates vlan2 on External with Auto DHCP', async ({ page }) => {
  test.setTimeout(180_000)
  let saveClicked = false

  try {
    const initialGrid = await openInterfaces(page)
    const parentRow = firstRowFor(initialGrid, createVlanAutoData.parentInterface)
    await expect(parentRow).toBeVisible({ timeout: uiReadyTimeout })
    await expect(parentRow.locator('[col-id="description"]')).toHaveText(createVlanAutoData.parentInterface)
    const parentDevice = (await parentRow.locator('[col-id="device"]').innerText()).trim()
    const expectedDevice = `${parentDevice}.${createVlanAutoData.vlanId}`

    await test.step(`verify ${createVlanAutoData.interfaceName} is not already present`, async () => {
      const interfaceNameExists = (await rowsFor(initialGrid, createVlanAutoData.interfaceName).count()) > 0
      const vlanIdExists = (await rowsFor(initialGrid, expectedDevice).count()) > 0

      if (interfaceNameExists || vlanIdExists) {
        const conflicts = [
          interfaceNameExists ? `interface name "${createVlanAutoData.interfaceName}"` : '',
          vlanIdExists ? `VLAN ID "${createVlanAutoData.vlanId}"` : '',
        ]
          .filter(Boolean)
          .join(' or ')

        test.skip(true, `Interface with ${conflicts} already exists`)
        return
      }
    })

    await test.step('click Add Interface and select VLAN', async () => {
      await page.getByRole('button', { name: /add interface/i }).click()
      await page.getByText('VLAN', { exact: true }).click()
      await expect(page).toHaveURL(/settings\/network\/interfaces\/add\/vlan(?:$|[?#])/, {
        timeout: 30_000,
      })
      await expect(page.getByRole('heading', { name: /add .*vlan/i })).toBeVisible({ timeout: 30_000 })
    })

    await test.step('enter VLAN details and select the configured type', async () => {
      await page.getByLabel('Interface Name', { exact: true }).fill(createVlanAutoData.interfaceName)

      const configTypeButton = page.getByRole('button', { name: /config type/i })
      await configTypeButton.click()
      await visibleMenu(page).getByRole('option', { name: createVlanAutoData.configType, exact: true }).click()
      await expect(configTypeButton).toContainText(createVlanAutoData.configType)

      const parentButton = page.getByRole('button', { name: /^Parent Interface$/ })
      await parentButton.click()
      const parentMenu = visibleMenu(page)
      await expect(
        parentMenu.getByRole('option', { name: createVlanAutoData.parentInterface, exact: true }),
      ).toBeVisible()
      await parentMenu.getByRole('option', { name: createVlanAutoData.parentInterface, exact: true }).click()

      const vlanIdField = page.getByLabel('VLAN ID', { exact: true })
      await vlanIdField.fill(String(createVlanAutoData.vlanId))
      await vlanIdField.press('Tab')
      await expect(vlanIdField).toHaveValue(String(createVlanAutoData.vlanId))
    })

    await test.step('enable WAN and NAT', async () => {
      const wanSwitch = page.getByLabel('WAN Interface', { exact: true })
      await expect(wanSwitch).toBeEnabled({ timeout: uiReadyTimeout })
      await setLabeledControl(wanSwitch, createVlanAutoData.wanInterface)

      const natCheckbox = page.getByLabel('NAT traffic exiting this interface (and bridged peers)', { exact: true })
      await setLabeledControl(natCheckbox, createVlanAutoData.natTraffic)
    })

    await test.step('select Auto DHCP for IPv4 and Disabled for IPv6', async () => {
      await page.getByRole('button', { name: 'IPv4', exact: true }).click()
      await setLabeledControl(page.getByRole('radio', { name: createVlanAutoData.ipv4ConfigType, exact: true }), true)

      await page.getByRole('button', { name: 'IPv6', exact: true }).click()
      await setLabeledControl(page.getByRole('radio', { name: createVlanAutoData.ipv6ConfigType, exact: true }), true)
    })

    await test.step('save vlan2 and verify it appears in the grid', async () => {
      const saveButton = page.getByRole('button', { name: /^save$/i })
      await expect(saveButton).toBeEnabled({ timeout: uiReadyTimeout })
      saveClicked = true
      await saveButton.click()
      await expect(page).toHaveURL(/settings\/network\/interfaces(?:$|[?#])/, {
        timeout: createSaveNavigationTimeout,
      })

      const savedGrid = page.locator('#appliance-interfaces')
      await waitForInterfacesReady(page, savedGrid)
      const savedRow = firstRowFor(savedGrid, createVlanAutoData.interfaceName)
      await expect(savedRow).toBeVisible({ timeout: uiReadyTimeout })
      await expect(savedRow.locator('[col-id="device"]')).toHaveText(expectedDevice)
      await expect(savedRow.locator('[col-id="description"]')).toHaveText(createVlanAutoData.interfaceName)
      await expect(savedRow.locator('[col-id="config"]')).toHaveText(createVlanAutoData.configType)
    })
  } finally {
    if (saveClicked) await deleteTemporaryInterface(page, createVlanAutoData.interfaceName)
  }
})

test('create-vlan-qos: creates a VLAN with QoS bandwidth', async ({ page }) => {
  test.setTimeout(180_000)
  let saveClicked = false

  try {
    const initialGrid = await openInterfaces(page)
    const parentRow = firstRowFor(initialGrid, createVlanQosData.parentInterface)
    await expect(parentRow).toBeVisible({ timeout: uiReadyTimeout })
    await expect(parentRow.locator('[col-id="description"]')).toHaveText(createVlanQosData.parentInterface)
    const parentDevice = (await parentRow.locator('[col-id="device"]').innerText()).trim()
    const expectedDevice = `${parentDevice}.${createVlanQosData.vlanId}`

    await test.step(`verify ${createVlanQosData.interfaceName} is not already present`, async () => {
      const interfaceNameExists = (await rowsFor(initialGrid, createVlanQosData.interfaceName).count()) > 0
      const vlanIdExists = (await rowsFor(initialGrid, expectedDevice).count()) > 0

      if (interfaceNameExists || vlanIdExists) {
        const conflicts = [
          interfaceNameExists ? `interface name "${createVlanQosData.interfaceName}"` : '',
          vlanIdExists ? `VLAN ID "${createVlanQosData.vlanId}"` : '',
        ]
          .filter(Boolean)
          .join(' or ')

        test.skip(true, `Interface with ${conflicts} already exists`)
        return
      }
    })

    await test.step('click Add Interface and select VLAN', async () => {
      await page.getByRole('button', { name: /add interface/i }).click()
      await page.getByText('VLAN', { exact: true }).click()
      await expect(page).toHaveURL(/settings\/network\/interfaces\/add\/vlan(?:$|[?#])/, {
        timeout: 30_000,
      })
      await expect(page.getByRole('heading', { name: /add .*vlan/i })).toBeVisible({ timeout: 30_000 })
    })

    await test.step('enter VLAN details', async () => {
      await page.getByLabel('Interface Name', { exact: true }).fill(createVlanQosData.interfaceName)

      const configTypeButton = page.getByRole('button', { name: /config type/i })
      await configTypeButton.click()
      await visibleMenu(page).getByRole('option', { name: createVlanQosData.configType, exact: true }).click()
      await expect(configTypeButton).toContainText(createVlanQosData.configType)

      const parentButton = page.getByRole('button', { name: /^Parent Interface$/ })
      await parentButton.click()
      const parentMenu = visibleMenu(page)
      await expect(
        parentMenu.getByRole('option', { name: createVlanQosData.parentInterface, exact: true }),
      ).toBeVisible()
      await parentMenu.getByRole('option', { name: createVlanQosData.parentInterface, exact: true }).click()

      const vlanIdField = page.getByLabel('VLAN ID', { exact: true })
      await vlanIdField.fill(String(createVlanQosData.vlanId))
      await vlanIdField.press('Tab')
      await expect(vlanIdField).toHaveValue(String(createVlanQosData.vlanId))
    })

    await test.step('enable WAN and NAT', async () => {
      const wanSwitch = page.getByLabel('WAN Interface', { exact: true })
      await expect(wanSwitch).toBeEnabled({ timeout: uiReadyTimeout })
      await setLabeledControl(wanSwitch, createVlanQosData.wanInterface)

      const natCheckbox = page.getByLabel('NAT traffic exiting this interface (and bridged peers)', { exact: true })
      await setLabeledControl(natCheckbox, createVlanQosData.natTraffic)
    })

    await test.step('select IPv4 and IPv6 configuration', async () => {
      await page.getByRole('button', { name: 'IPv4', exact: true }).click()
      await setLabeledControl(page.getByRole('radio', { name: createVlanQosData.ipv4ConfigType, exact: true }), true)

      await page.getByRole('button', { name: 'IPv6', exact: true }).click()
      await setLabeledControl(page.getByRole('radio', { name: createVlanQosData.ipv6ConfigType, exact: true }), true)
    })

    await test.step('enable QoS and configure bandwidth', async () => {
      const qosTab = page.getByRole('button', { name: /^qos$/i })
      await expect(qosTab).toBeVisible({ timeout: uiReadyTimeout })
      await qosTab.click()

      const qosEnabled = page.getByLabel('QoS Enabled', { exact: true })
      await setLabeledControl(qosEnabled, createVlanQosData.qosEnabled)

      const uploadBandwidth = page.getByLabel('Upload', { exact: true })
      const downloadBandwidth = page.getByLabel('Download', { exact: true })
      await expect(uploadBandwidth).toBeEnabled({ timeout: uiReadyTimeout })
      await expect(downloadBandwidth).toBeEnabled({ timeout: uiReadyTimeout })
      await uploadBandwidth.fill(String(createVlanQosData.uplinkBandwidth))
      await downloadBandwidth.fill(String(createVlanQosData.downlinkBandwidth))
      await expect(uploadBandwidth).toHaveValue(String(createVlanQosData.uplinkBandwidth))
      await expect(downloadBandwidth).toHaveValue(String(createVlanQosData.downlinkBandwidth))
    })

    await test.step('save the VLAN and verify it appears in the grid', async () => {
      const saveButton = page.getByRole('button', { name: /^save$/i })
      await expect(saveButton).toBeEnabled({ timeout: uiReadyTimeout })
      saveClicked = true
      await saveButton.click()
      await expect(page).toHaveURL(/settings\/network\/interfaces(?:$|[?#])/, {
        timeout: createSaveNavigationTimeout,
      })

      const savedGrid = page.locator('#appliance-interfaces')
      await waitForInterfacesReady(page, savedGrid)
      const savedRow = firstRowFor(savedGrid, createVlanQosData.interfaceName)
      await expect(savedRow).toBeVisible({ timeout: uiReadyTimeout })
      await expect(savedRow.locator('[col-id="device"]')).toHaveText(expectedDevice)
      await expect(savedRow.locator('[col-id="description"]')).toHaveText(createVlanQosData.interfaceName)
      await expect(savedRow.locator('[col-id="config"]')).toHaveText(createVlanQosData.configType)
    })
  } finally {
    if (saveClicked) await deleteTemporaryInterface(page, createVlanQosData.interfaceName)
  }
})

test('create-vlan-pppoe: creates a VLAN on Internal with PPPoE', async ({ page }) => {
  test.setTimeout(180_000)
  let saveClicked = false
  let createdInterfaceName = createVlanPppoeData.interfaceName

  try {
    const initialGrid = await openInterfaces(page)
    const parentRow = firstRowFor(initialGrid, createVlanPppoeData.parentInterface)
    await expect(parentRow).toBeVisible({ timeout: uiReadyTimeout })
    await expect(parentRow.locator('[col-id="description"]')).toHaveText(createVlanPppoeData.parentInterface)
    const parentDevice = (await parentRow.locator('[col-id="device"]').innerText()).trim()
    const availableVlan = await findAvailableVlan(
      initialGrid,
      parentDevice,
      Number(createVlanPppoeData.vlanId),
      createVlanPppoeData.interfaceName,
    )
    createdInterfaceName = availableVlan.interfaceName

    await test.step(`use available interface ${availableVlan.interfaceName} and VLAN ID ${availableVlan.vlanId}`, async () => {
      // Start with the JSON name/ID, then advance both values until neither the
      // name nor the parent VLAN device is already present on the appliance.
      await expect(rowsFor(initialGrid, availableVlan.interfaceName)).toHaveCount(0)
      await expect(rowsFor(initialGrid, availableVlan.vlanDevice)).toHaveCount(0)
    })

    await test.step('click Add Interface and select VLAN', async () => {
      await page.getByRole('button', { name: /add interface/i }).click()
      await page.getByText('VLAN', { exact: true }).click()
      await expect(page).toHaveURL(/settings\/network\/interfaces\/add\/vlan(?:$|[?#])/, {
        timeout: 30_000,
      })
      await expect(page.getByRole('heading', { name: /add .*vlan/i })).toBeVisible({ timeout: 30_000 })
    })

    await test.step('enter VLAN details and select Addressed', async () => {
      await page.getByLabel('Interface Name', { exact: true }).fill(availableVlan.interfaceName)

      const configTypeButton = page.getByRole('button', { name: /config type/i })
      await configTypeButton.click()
      await visibleMenu(page).getByRole('option', { name: createVlanPppoeData.configType, exact: true }).click()
      await expect(configTypeButton).toContainText(createVlanPppoeData.configType)

      const parentButton = page.getByRole('button', { name: /^Parent Interface$/ })
      await parentButton.click()
      const parentMenu = visibleMenu(page)
      await expect(
        parentMenu.getByRole('option', { name: createVlanPppoeData.parentInterface, exact: true }),
      ).toBeVisible()
      await parentMenu.getByRole('option', { name: createVlanPppoeData.parentInterface, exact: true }).click()

      const vlanIdField = page.getByLabel('VLAN ID', { exact: true })
      await vlanIdField.fill(availableVlan.vlanId)
      await vlanIdField.press('Tab')
      await expect(vlanIdField).toHaveValue(availableVlan.vlanId)
    })

    await test.step('enable WAN and NAT', async () => {
      const wanSwitch = page.getByLabel('WAN Interface', { exact: true })
      await expect(wanSwitch).toBeEnabled({ timeout: uiReadyTimeout })
      await setLabeledControl(wanSwitch, createVlanPppoeData.wanInterface)

      const natCheckbox = page.getByLabel('NAT traffic exiting this interface (and bridged peers)', { exact: true })
      await setLabeledControl(natCheckbox, createVlanPppoeData.natTraffic)
    })

    await test.step('select PPPoE and enter credentials on the IPv4 tab', async () => {
      await page.getByRole('button', { name: 'IPv4', exact: true }).click()
      await setLabeledControl(page.getByRole('radio', { name: createVlanPppoeData.ipv4ConfigType, exact: true }), true)

      const usernameField = page.getByLabel('Username', { exact: true })
      const passwordField = page.getByLabel('Password', { exact: true })
      await expect(usernameField).toBeVisible({ timeout: uiReadyTimeout })
      await expect(passwordField).toBeVisible({ timeout: uiReadyTimeout })
      await usernameField.fill(createVlanPppoeData.pppoeUsername)
      await passwordField.fill(createVlanPppoeData.pppoePassword)
      await expect(usernameField).toHaveValue(createVlanPppoeData.pppoeUsername)
      await expect(passwordField).toHaveValue(createVlanPppoeData.pppoePassword)
    })

    await test.step('select Disabled on the IPv6 tab', async () => {
      await page.getByRole('button', { name: 'IPv6', exact: true }).click()
      await setLabeledControl(page.getByRole('radio', { name: createVlanPppoeData.ipv6ConfigType, exact: true }), true)
    })

    await test.step('save the PPPoE VLAN and verify it appears in the grid', async () => {
      const saveButton = page.getByRole('button', { name: /^save$/i })
      await expect(saveButton).toBeEnabled({ timeout: uiReadyTimeout })
      saveClicked = true
      await saveButton.click()

      try {
        await expect(page).toHaveURL(/settings\/network\/interfaces(?:$|[?#])/, {
          timeout: createSaveNavigationTimeout,
        })
      } catch {
        // A WAN PPPoE save can temporarily interrupt the original RPC callback
        // while the appliance applies network settings. Re-open the authenticated
        // console and verify durable grid state instead of treating that callback
        // delay as proof that the save failed.
        await openInterfaces(page)
      }

      const savedGrid = page.locator('#appliance-interfaces')
      await waitForInterfacesReady(page, savedGrid)
      const savedRow = firstRowFor(savedGrid, availableVlan.interfaceName)
      await expect(savedRow).toBeVisible({ timeout: uiReadyTimeout })
      // PPPoE exposes its logical PPP device in the grid (for example ppp0),
      // rather than the underlying VLAN device (for example eth0.2).
      const savedDevice = (await savedRow.locator('[col-id="device"]').innerText()).trim()
      expect(savedDevice).toMatch(/^ppp\d+$/)
      await expect(savedRow.locator('[col-id="description"]')).toHaveText(availableVlan.interfaceName)
      await expect(savedRow.locator('[col-id="config"]')).toHaveText('Addressed')
    })
  } finally {
    if (saveClicked) await deleteTemporaryInterface(page, createdInterfaceName)
  }
})
