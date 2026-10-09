import {
  test,
  expect,
  activeWindow,
  appPath,
  clickDialogAction,
  clickSave,
  expectInvalid,
  expectRejected,
  expectValid,
  hasValidationError,
  open,
  visibleError,
} from '../../fixtures/network-validation'
import type { Page } from '@playwright/test'

const invalidPortValues = [
  { title: 'zero', value: '0' },
  { title: 'above the maximum', value: '65536' },
  { title: 'decimal', value: '80.5' },
]

const invalidLeaseValues = [
  { title: 'zero', value: '0' },
  { title: 'above 99999', value: '100000' },
  { title: 'decimal', value: '1.5' },
  { title: 'non numeric text', value: 'leases' },
]

async function openSystem(page: Parameters<typeof open>[0]) {
  await open(page, '/settings/system/settings', 'Host Name')
}

async function openServices(page: Parameters<typeof open>[0]) {
  await openSystem(page)
  await page.getByRole('tab', { name: /services/i }).click()
  await expect(page.getByLabel('Web Admin Port (HTTP)', { exact: true })).toBeVisible()
}

async function openDhcp(page: Parameters<typeof open>[0]) {
  await open(page, '/settings/network/dhcp', 'Maximum Leases')
}

async function openAdvancedTab(page: Parameters<typeof open>[0], tab: RegExp) {
  await open(page, '/settings/network/advanced', 'Advanced')
  await page.getByRole('button', { name: tab }).click()
}

async function openDynamicRoutes(page: Parameters<typeof open>[0]) {
  await open(page, '/settings/routing/dynamicRoutes', 'Dynamic Routes')
  await waitForUiSettled(page)
}

async function waitForUiSettled(page: Parameters<typeof open>[0]) {
  // The heading renders before the initial network settings/status requests
  // finish. The same applies when changing a routing sub-tab.
  await page.waitForLoadState('networkidle')
  await expect(page.locator('.v-progress-circular:visible')).toHaveCount(0)
}

async function interfaceRowDevice(page: Parameters<typeof open>[0], predicate: RegExp = /addressed/i) {
  await open(page, '/settings/network/interfaces', 'Interfaces')
  const grid = page.locator('#appliance-interfaces')
  const row = grid.locator('.ag-row').filter({ hasText: predicate }).first()
  await expect(row, `an interface row matching ${predicate} is required`).toBeVisible()
  const device = await row.getAttribute('row-id')
  expect(device, 'the interface grid must expose the device row id').toBeTruthy()
  return device as string
}

async function otherInterfaceIpv4(page: Parameters<typeof open>[0], currentDevice: string) {
  await open(page, '/settings/network/interfaces', 'Interfaces')
  const rows = page.locator('#appliance-interfaces .ag-row')
  for (let index = 0; index < await rows.count(); index += 1) {
    const row = rows.nth(index)
    if ((await row.getAttribute('row-id')) === currentDevice) continue
    const value = await row.innerText()
    const address = value.match(/\b(?:\d{1,3}\.){3}\d{1,3}\b/)?.[0]
    if (address && address !== '0.0.0.0') return address
  }
  return undefined
}

async function otherInterfaceName(page: Parameters<typeof open>[0], currentDevice: string) {
  await open(page, '/settings/network/interfaces', 'Interfaces')
  const rows = page.locator('#appliance-interfaces .ag-row')
  for (let index = 0; index < await rows.count(); index += 1) {
    const row = rows.nth(index)
    if ((await row.getAttribute('row-id')) === currentDevice) continue
    const cell = row.locator('.ag-cell[col-id="description"]')
    if (!(await cell.count())) continue
    const name = (await cell.innerText()).trim()
    if (name) return name
  }
  return undefined
}

async function openInterface(page: Parameters<typeof open>[0], predicate: RegExp = /addressed/i) {
  const device = await interfaceRowDevice(page, predicate)
  await page.goto(appPath(`/settings/network/interfaces/${encodeURIComponent(device)}`))
  await expect(page.getByLabel('Interface Name', { exact: true })).toBeVisible()
}

async function expectSelectRequired(field: ReturnType<Page['getByLabel']>, page: Page) {
  await field.click()
  await page.keyboard.press('Escape')
  await field.blur()
  // Some USelect instances do not mark the provider touched on blur. Submit
  // the owning form when needed, then assert the rendered required message.
  try {
    await expect(visibleError(field)).not.toHaveCount(0, { timeout: 1000 })
    return
  } catch {
    const dialog = page.getByRole('dialog')
    if (await dialog.count() && await dialog.isVisible()) {
      const action = dialog.getByRole('button', { name: /^(add|update|ok)$/i }).last()
      if (await action.count()) await action.click()
    } else {
      const save = page.getByRole('button', { name: /^save$/i }).last()
      if (await save.count()) await save.click()
    }
  }
  let matched = false
  try {
    await expect.poll(() => hasValidationError(field)).toBe(true)
    matched = true
  } catch {
    // Preserve the matrix's soft-failure behavior after the submit attempt.
  }
  await expect.soft(matched).toBe(true)
}

async function expectSelectOptional(field: ReturnType<Page['getByLabel']>, page: Page) {
  await field.click()
  await page.keyboard.press('Escape')
  await field.blur()
  await expect.soft(visibleError(field)).toHaveCount(0)
}

async function chooseOption(field: ReturnType<Page['getByLabel']>, page: Page, option: RegExp) {
  await field.click()
  await page.getByRole('option', { name: option }).last().click()
}

async function choosePrefix24(field: ReturnType<Page['getByLabel']>, page: Page) {
  // The prefix autocomplete virtualizes its menu, so /24 is not in the
  // initial DOM window. Typing the exact prefix filters the rendered option.
  await field.click()
  await field.fill('24')
  await page.getByRole('option', { name: /\b24\b/ }).last().click()
}

async function checkCheckbox(field: ReturnType<Page['getByRole']>) {
  if (!(await field.isChecked())) {
    await field.click({ force: true })
    await expect(field).toBeChecked()
  }
}

async function setCheckboxState(field: ReturnType<Page['getByRole']>, checked: boolean) {
  if ((await field.isChecked()) !== checked) {
    await field.click({ force: true })
    await expect(field).toHaveJSProperty('checked', checked)
  }
}

async function openWanInterface(page: Parameters<typeof open>[0]) {
  await open(page, '/settings/network/interfaces', 'Interfaces')
  const grid = page.locator('#appliance-interfaces')
  const rows = grid.locator('.ag-row')
  const count = await rows.count()
  for (let index = 0; index < count; index += 1) {
    const row = rows.nth(index)
    const device = await row.getAttribute('row-id')
    if (!device) continue
    await page.goto(appPath(`/settings/network/interfaces/${encodeURIComponent(device)}`))
    await expect(page.getByLabel('Interface Name', { exact: true })).toBeVisible()
    const wan = page.getByRole('checkbox', { name: /NAT traffic exiting this interface/i })
    if ((await wan.count()) && (await wan.isChecked())) {
      await expect(page.getByLabel('Interface Name', { exact: true })).toBeVisible()
      return true
    }
    await page.goto(appPath('/settings/network/interfaces'))
    await expect(page.getByText('Interfaces', { exact: true })).toBeVisible()
  }
  return false
}

async function requireWanInterface(page: Parameters<typeof open>[0]) {
  const found = await openWanInterface(page)
  test.skip(!found, 'The appliance has no existing WAN interface; skipping WAN-only validation without changing interface state')
}

async function clickVisibleAlias(page: Parameters<typeof open>[0]) {
  // VRRP is eagerly mounted, so its hidden Add Alias chip shares the same
  // text. The first rendered chip is the alias control for the active tab.
  const aliases = page.getByText('Add Alias', { exact: true })
  for (let index = 0; index < await aliases.count(); index += 1) {
    const alias = aliases.nth(index)
    if (await alias.isVisible()) {
      await alias.click({ force: true })
      return
    }
  }
  throw new Error('The active interface tab did not render an Add Alias control')
}

async function openLanInterface(page: Parameters<typeof open>[0]) {
  await open(page, '/settings/network/interfaces', 'Interfaces')
  const grid = page.locator('#appliance-interfaces')
  const rows = grid.locator('.ag-row')
  const count = await rows.count()
  for (let index = 0; index < count; index += 1) {
    const row = rows.nth(index)
    const device = await row.getAttribute('row-id')
    if (!device) continue
    await page.goto(appPath(`/settings/network/interfaces/${encodeURIComponent(device)}`))
    await expect(page.getByLabel('Interface Name', { exact: true })).toBeVisible()
    const incomingNat = page.getByRole('checkbox', { name: /NAT traffic coming from this interface/i })
    const outgoingNat = page.getByRole('checkbox', { name: /NAT traffic exiting this interface/i })
    if (await incomingNat.count()) {
      await expect(page.getByLabel('Interface Name', { exact: true })).toBeVisible()
      return true
    }
    if ((await outgoingNat.count()) && !(await outgoingNat.isChecked())) {
      await expect(page.getByLabel('Interface Name', { exact: true })).toBeVisible()
      return true
    }
    await page.goto(appPath('/settings/network/interfaces'))
    await expect(page.getByText('Interfaces', { exact: true })).toBeVisible()
  }
  return false
}

async function requireLanInterface(page: Parameters<typeof open>[0]) {
  const found = await openLanInterface(page)
  test.skip(!found, 'The appliance has no existing non-WAN interface; skipping LAN-only validation without changing interface state')
}

test.describe('System → Settings / System → Services / Network → DHCP / Network → Advanced: primary-save ExtJS field rules', () => {
  test('hostname is required and accepts only letters, numbers, and hyphens', async ({ page, mutationGuard }) => {
    await openSystem(page)
    const field = page.getByLabel('Host Name', { exact: true })

    await expectInvalid(field, '')
    await expectRejected(field, 'bad host!')
    await expectValid(field, 'valid-host-01')

    await field.fill('bad host!')
    await clickSave(page)
    mutationGuard.expectNoAttempt()
  })

  test('domain is required, rejects a leading period, and accepts the ExtJS domain grammar', async ({ page }) => {
    await openSystem(page)
    const field = page.getByLabel('Domain Name', { exact: true })

    await expectInvalid(field, '')
    await expectInvalid(field, '.example.local')
    await expectInvalid(field, 'example local')
    await expectValid(field, 'fw-01.example.local')
    await expectValid(field, 'fw_01.example.local')
  })

  for (const { title, value } of invalidPortValues) {
    test(`HTTP port rejects ${title}`, async ({ page }) => {
      await openServices(page)
      await expectInvalid(page.getByLabel('Web Admin Port (HTTP)', { exact: true }), value)
    })

    test(`HTTPS port rejects ${title}`, async ({ page }) => {
      await openServices(page)
      await expectInvalid(page.getByLabel('Web Admin Port (HTTPS)', { exact: true }), value)
    })
  }

  test('HTTP and HTTPS ports accept both ExtJS range boundaries', async ({ page }) => {
    await openServices(page)
    const http = page.getByLabel('Web Admin Port (HTTP)', { exact: true })
    const https = page.getByLabel('Web Admin Port (HTTPS)', { exact: true })
    await expectInvalid(http, '')
    await expectInvalid(https, '')
    await expectValid(http, '1')
    await expectValid(page.getByLabel('Web Admin Port (HTTP)', { exact: true }), '65535')
    await expectValid(page.getByLabel('Web Admin Port (HTTPS)', { exact: true }), '1')
    await expectValid(page.getByLabel('Web Admin Port (HTTPS)', { exact: true }), '65535')
  })

  for (const { title, value } of invalidLeaseValues) {
    test(`maximum leases rejects ${title}`, async ({ page }) => {
      await openDhcp(page)
      await expectInvalid(page.getByLabel('Maximum Leases', { exact: true }), value)
    })
  }

  test('maximum leases accepts 1 and 99999', async ({ page }) => {
    await openDhcp(page)
    const field = page.getByLabel('Maximum Leases', { exact: true })
    await expectInvalid(field, '')
    await expectValid(field, '1')
    await expectValid(field, '99999')
  })

  test('manual public address makes both address and port required', async ({ page, mutationGuard }) => {
    await openSystem(page)
    // Vuetify's ripple element covers the native radio input in this build.
    await page.getByRole('radio', { name: /manually specified address/i }).check({ force: true })
    const address = page.getByLabel('IP/Hostname', { exact: true })
    const port = page.getByLabel('Port', { exact: true })
    await expect(address).toBeEnabled()
    await expect(port).toBeEnabled()

    await expectInvalid(address, '')
    await expectInvalid(port, '')
    await expectInvalid(port, '0')
    await expectInvalid(port, '65536')
    await expectInvalid(port, '80.5')
    await expectValid(address, 'public.example.test')
    await expectValid(address, 'not-an-ip-but-nonblank')
    await expectValid(port, '65535')

    await address.fill('')
    await clickSave(page)
    mutationGuard.expectNoAttempt()
  })

  test('public address fields are skipped when the manual-address flag is off', async ({ page }) => {
    await openSystem(page)
    await page.getByRole('radio', { name: /use ip address from external interface/i }).check({ force: true })
    const address = page.getByLabel('IP/Hostname', { exact: true })
    const port = page.getByLabel('Port', { exact: true })
    await expect(address).toBeDisabled()
    await expect(port).toBeDisabled()
    await expect(visibleError(address)).toHaveCount(0)
    await expect(visibleError(port)).toHaveCount(0)
  })

  test('Netflow port is validated only when Netflow is enabled', async ({ page }) => {
    await openAdvancedTab(page, /netflow/i)
    const enabled = page.getByRole('checkbox', { name: /netflow enabled/i })
    const port = page.getByLabel('Port', { exact: true })
    await expect(enabled).not.toBeChecked()
    await expect(port).toBeDisabled()
    await expect(visibleError(port)).toHaveCount(0)

    await checkCheckbox(enabled)
    await expect(port).toBeEnabled()
    await expectInvalid(port, '')
    await expectInvalid(port, '0')
    await expectInvalid(port, '65536')
    await expectValid(port, '1')
    await expectValid(port, '65535')
  })
})

test.describe('Network → Interfaces: interface editor dependencies', () => {
  test('VLAN parent and tag are required only in the VLAN editor and tag is 1..4094', async ({ page }) => {
    await page.goto(appPath('/settings/network/interfaces/add/VLAN'))
    await expect(page.getByLabel('Interface Name', { exact: true })).toBeVisible()
    const parent = page.getByLabel('Parent Interface', { exact: true })
    const tag = page.getByLabel('VLAN ID', { exact: true })
    await expect(parent).toBeVisible()
    await expect(tag).toBeVisible()

    await expectInvalid(tag, '0')
    await expectInvalid(tag, '4095')
    await expectInvalid(tag, '1.5')
    await expectValid(tag, '1')
    await expectValid(tag, '4094')
    await expectSelectRequired(parent, page)
  })

  test('Bridged To is required only for a bridged interface', async ({ page }) => {
    await openInterface(page)
    await expect(page.getByLabel('Bridged To', { exact: true })).toHaveCount(0)

    await page.goto(appPath('/settings/network/interfaces/add/BRIDGE'))
    await expect(page.getByLabel('Interface Name', { exact: true })).toBeVisible()
    const bridgedTo = page.getByLabel('Bridged To', { exact: true })
    await expect(bridgedTo).toBeVisible()
    await expectSelectRequired(bridgedTo, page)
  })

  test('interface name rejects blank, whitespace-only, and ExtJS forbidden characters', async ({ page }) => {
    await openInterface(page)
    const field = page.getByLabel('Interface Name', { exact: true })
    await expectInvalid(field, '')
    await expectInvalid(field, '   ')
    await expectInvalid(field, 'bad!name')
    await expectInvalid(field, 'bad#name')
    await expectValid(field, 'lan-validation-01')
  })

  test('interface name rejects a name already used by another interface', async ({ page }) => {
    const currentDevice = await interfaceRowDevice(page)
    const duplicateName = await otherInterfaceName(page, currentDevice)
    test.skip(!duplicateName, 'The appliance has no second interface name for the ExtJS uniqueness rule')

    await page.goto(appPath(`/settings/network/interfaces/${encodeURIComponent(currentDevice)}`))
    await expect(page.getByLabel('Interface Name', { exact: true })).toBeVisible()
    await expectInvalid(page.getByLabel('Interface Name', { exact: true }), duplicateName as string)
  })

  test('static IPv4 address, gateway, and primary DNS enforce ExtJS IPv4 rules', async ({ page }) => {
    await requireWanInterface(page)
    await page.getByRole('button', { name: /^ipv4$/i }).click()
    await page.getByRole('radio', { name: /^static$/i }).check({ force: true })
    const tab = activeWindow(page)
    const address = tab.getByLabel('Address', { exact: true }).first()
    const prefix = tab.getByLabel('Prefix / Netmask', { exact: true }).first()
    const gateway = tab.getByLabel('Gateway', { exact: true })
    const primaryDns = tab.getByLabel('Primary DNS', { exact: true })
    const secondaryDns = tab.getByLabel('Secondary DNS', { exact: true })

    await expectInvalid(address, '300.1.1.1')
    await expectInvalid(address, '0.0.0.0')
    await expectInvalid(address, '')
    await expectInvalid(prefix, '')
    await expectInvalid(gateway, 'not-an-ip')
    await expectInvalid(gateway, '')
    await expectInvalid(primaryDns, '192.0.2.999')
    await expectInvalid(primaryDns, '')
    await expectInvalid(secondaryDns, '192.0.2.999')

    // The ExtJS custom validator rejects the network and broadcast addresses
    // for the selected prefix in addition to the ip4AddExcldDflt vtype.
    await choosePrefix24(prefix, page)
    await expectInvalid(address, '198.51.100.0')
    await expectInvalid(address, '198.51.100.255')
    await expectValid(address, '198.51.100.10')
    await expectValid(gateway, '192.0.2.1')
    await expectValid(primaryDns, '192.0.2.53')
    await expectValid(secondaryDns, '')
    await expectValid(secondaryDns, '192.0.2.54')
  })

  test('static IPv4 rejects an address already assigned to another interface', async ({ page }) => {
    const currentDevice = await interfaceRowDevice(page)
    const duplicateAddress = await otherInterfaceIpv4(page, currentDevice)
    test.skip(!duplicateAddress, 'The appliance has no second interface address for the ExtJS uniqueness rule')

    await page.goto(appPath(`/settings/network/interfaces/${encodeURIComponent(currentDevice)}`))
    await expect(page.getByLabel('Interface Name', { exact: true })).toBeVisible()
    await page.getByRole('button', { name: /^ipv4$/i }).click()
    await page.getByRole('radio', { name: /^static$/i }).check({ force: true })
    await expectInvalid(activeWindow(page).getByLabel('Address', { exact: true }).first(), duplicateAddress as string)
  })

  test('static IPv4 rejects network and broadcast addresses for the selected prefix', async ({ page }) => {
    await openInterface(page)
    await page.getByRole('button', { name: /^ipv4$/i }).click()
    await page.getByRole('radio', { name: /^static$/i }).check({ force: true })
    const tab = activeWindow(page)
    const address = tab.getByLabel('Address', { exact: true }).first()
    const prefix = tab.getByLabel('Prefix / Netmask', { exact: true }).first()
    await expectInvalid(prefix, '')
    await choosePrefix24(prefix, page)
    await expectInvalid(address, '198.51.100.0')
    await expectInvalid(address, '198.51.100.255')
    await expectValid(address, '198.51.100.10')
  })

  test('IPv4 aliases enforce address and prefix constraints when a row is added', async ({ page }) => {
    await openInterface(page)
    await page.getByRole('button', { name: /^ipv4$/i }).click()
    await clickVisibleAlias(page)
    const tab = activeWindow(page)
    const address = tab.getByLabel('Address', { exact: true }).last()
    const prefix = tab.getByLabel('Prefix / Netmask', { exact: true }).last()

    await expectInvalid(address, '300.1.1.1')
    await expectInvalid(address, '')
    await expectInvalid(prefix, '')
    // The prefix autocomplete exposes only the ExtJS range 1..32. Invalid
    // boundary values therefore have no selectable option.
    await prefix.click()
    await prefix.fill('0')
    await expect(page.getByRole('option', { name: /^\/\s*0(?:\s|$)/ })).toHaveCount(0)
    await prefix.fill('33')
    await expect(page.getByRole('option', { name: /^\/\s*33(?:\s|$)/ })).toHaveCount(0)
    await page.keyboard.press('Escape')
    await choosePrefix24(prefix, page)
    await expectInvalid(address, '198.51.100.0')
    await expectInvalid(address, '198.51.100.255')
    await expectValid(address, '192.0.2.30')
    await expectValid(prefix, '1')
    await expectValid(prefix, '32')
  })

  test('IPv4 DHCP override vtypes reject default route and malformed addresses', async ({ page }) => {
    await requireWanInterface(page)
    await page.getByRole('button', { name: /^ipv4$/i }).click()
    await page.getByRole('radio', { name: /auto.*dhcp/i }).check()
    await page.getByText(/dhcp overrides.*optional/i).click()
    const tab = activeWindow(page)
    await expectInvalid(tab.getByLabel('Address', { exact: true }).last(), '0.0.0.0')
    await expectInvalid(tab.getByLabel('Address', { exact: true }).last(), '192.0.2.999')
    await expectInvalid(tab.getByLabel('Gateway', { exact: true }).last(), 'not-an-ip')
    await expectInvalid(tab.getByLabel('Primary DNS', { exact: true }).last(), '192.0.2.999')
    await expectInvalid(tab.getByLabel('Secondary DNS', { exact: true }).last(), '192.0.2.999')
    await expectValid(tab.getByLabel('Address', { exact: true }).last(), '192.0.2.20')
    await expectValid(tab.getByLabel('Gateway', { exact: true }).last(), '192.0.2.1')
    await expectValid(tab.getByLabel('Primary DNS', { exact: true }).last(), '192.0.2.53')
    await expectValid(tab.getByLabel('Secondary DNS', { exact: true }).last(), '')
  })

  test('PPPoE username and password remain optional under the ExtJS rules', async ({ page }) => {
    await openInterface(page)
    await page.getByRole('button', { name: /^ipv4$/i }).click()
    const staticMode = page.getByRole('radio', { name: /^static$/i }).last()
    const autoMode = page.getByRole('radio', { name: /auto.*dhcp/i }).last()
    const pppoeMode = page.getByRole('radio', { name: /pppoe/i })
    const originalMode = (await staticMode.isChecked()) ? staticMode : (await autoMode.isChecked() ? autoMode : pppoeMode)

    try {
      await pppoeMode.check({ force: true })
      const tab = activeWindow(page)
      const username = tab.getByLabel('Username', { exact: true })
      const password = tab.getByLabel('Password', { exact: true })

      await expectValid(username, '')
      await expectValid(password, '')
      await expectValid(password, 'x')
    } finally {
      if (!page.isClosed()) await originalMode.check({ force: true })
    }
  })

  test('PPPoE DNS fields enforce their optional IP rules and peer-DNS dependency', async ({ page }) => {
    await openInterface(page)
    await page.getByRole('button', { name: /^ipv4$/i }).click()
    const staticMode = page.getByRole('radio', { name: /^static$/i }).last()
    const autoMode = page.getByRole('radio', { name: /auto.*dhcp/i }).last()
    const pppoeMode = page.getByRole('radio', { name: /pppoe/i })
    const originalMode = (await staticMode.isChecked()) ? staticMode : (await autoMode.isChecked() ? autoMode : pppoeMode)

    try {
      await pppoeMode.check({ force: true })
      const tab = activeWindow(page)
      const peerDns = tab.getByRole('checkbox', { name: /use peer dns/i })
      const primaryDns = tab.getByLabel('Primary DNS', { exact: true })
      const secondaryDns = tab.getByLabel('Secondary DNS', { exact: true })

      await peerDns.uncheck({ force: true })
      await expectInvalid(primaryDns, 'not-an-ip')
      await expectInvalid(secondaryDns, 'not-an-ip')
      await expectValid(primaryDns, '')
      await expectValid(secondaryDns, '')

      await expectInvalid(secondaryDns, 'not-an-ip')
      await peerDns.check({ force: true })
      await expect(primaryDns).toBeDisabled()
      await expect(secondaryDns).toBeDisabled()
      await expect(visibleError(secondaryDns)).toHaveCount(0)
    } finally {
      if (!page.isClosed()) await originalMode.check({ force: true })
    }
  })

  test('IPv6 static prefix is required and constrained to 1..128', async ({ page }) => {
    await requireWanInterface(page)
    await page.getByRole('button', { name: /^ipv6$/i }).click()
    await page.getByRole('radio', { name: /^static$/i }).last().check({ force: true })
    const tab = activeWindow(page)
    await expectInvalid(tab.getByLabel('Address', { exact: true }), 'not-an-ipv6-address')
    await expectValid(tab.getByLabel('Address', { exact: true }), '')
    await expectValid(tab.getByLabel('Address', { exact: true }), '2001:db8::10')
    const prefix = tab.getByLabel('Prefix Length', { exact: true })
    await expectInvalid(prefix, '0')
    await expectInvalid(prefix, '129')
    await expectValid(prefix, '1')
    await expectValid(prefix, '128')
    await expectInvalid(tab.getByLabel('Gateway', { exact: true }), 'not-an-ipv6-address')
    await expectInvalid(tab.getByLabel('Primary DNS', { exact: true }), 'not-an-ipv6-address')
    await expectInvalid(tab.getByLabel('Secondary DNS', { exact: true }), 'not-an-ipv6-address')
    // ExtJS marks the IPv6 gateway and DNS fields optional; only their
    // ip6Address validators apply when a value is present.
    await expectValid(tab.getByLabel('Gateway', { exact: true }), '')
    await expectValid(tab.getByLabel('Primary DNS', { exact: true }), '')
    await expectValid(tab.getByLabel('Secondary DNS', { exact: true }), '')
    await expectValid(tab.getByLabel('Gateway', { exact: true }), '2001:db8::1')
    await expectValid(tab.getByLabel('Primary DNS', { exact: true }), '2001:db8::53')
    await expectValid(tab.getByLabel('Secondary DNS', { exact: true }), '2001:db8::54')
  })

  test('IPv6 aliases enforce address and prefix constraints when a row is added', async ({ page }) => {
    await openInterface(page)
    await page.getByRole('button', { name: /^ipv6$/i }).click()
    await page.getByRole('radio', { name: /^static$/i }).last().check({ force: true })
    await clickVisibleAlias(page)
    const tab = activeWindow(page)
    const address = tab.getByLabel('Address', { exact: true }).last()
    const prefix = tab.getByLabel('Prefix', { exact: true }).last()

    await expectInvalid(address, 'not-an-ipv6-address')
    await expectInvalid(address, '')
    await expectInvalid(prefix, '')
    await prefix.click()
    await prefix.fill('0')
    await expect(page.getByRole('option', { name: /^\/\s*0(?:\s|$)/ })).toHaveCount(0)
    await prefix.fill('129')
    await expect(page.getByRole('option', { name: /^\/\s*129(?:\s|$)/ })).toHaveCount(0)
    await page.keyboard.press('Escape')
    await expectValid(address, '2001:db8::20')
    await expectValid(prefix, '1')
    await expectValid(prefix, '128')
  })

  test('IPv6 static validation is inactive when the IPv6 mode flag is disabled', async ({ page }) => {
    await openInterface(page)
    await page.getByRole('button', { name: /^ipv6$/i }).click()
    const disabled = page.getByRole('radio', { name: /^disabled$/i }).last()
    await disabled.check({ force: true })
    await expect(page.getByLabel('Prefix Length', { exact: true })).toHaveCount(0)
  })

  test('DHCP server validations apply only when DHCP serving is enabled', async ({ page }) => {
    await requireLanInterface(page)
    await page.getByRole('button', { name: /^dhcp$/i }).click()
    const serving = page.getByRole('checkbox', { name: /enable dhcp serving/i })
    const relay = page.getByRole('checkbox', { name: /enable dhcp relaying/i })
    await checkCheckbox(serving)
    await expect(relay).not.toBeChecked()

    const rangeStart = page.getByLabel('Range Start', { exact: true })
    const rangeEnd = page.getByLabel('Range End', { exact: true })
    const lease = page.getByLabel('Lease Duration', { exact: true })
    const dns = page.getByLabel('DNS Override', { exact: true })
    const gateway = page.getByLabel('Gateway Override', { exact: true })
    await expectInvalid(rangeStart, '300.1.1.1')
    await expectInvalid(rangeEnd, 'not-an-ip')
    await expectInvalid(rangeStart, '')
    await expectInvalid(rangeEnd, '')
    await expectValid(rangeStart, '192.0.2.20')
    await expectInvalid(rangeEnd, '192.0.2.10')
    await expectInvalid(lease, '')
    await expectInvalid(lease, '119')
    await expectInvalid(dns, '192.0.2.1,not-an-ip')
    await expectInvalid(gateway, '0.0.0.0')
    await expectInvalid(gateway, 'not-an-ip')
    await expectValid(gateway, '')
    await expectValid(rangeStart, '192.0.2.10')
    await expectValid(rangeEnd, '192.0.2.20')
    await expectValid(lease, '120')
    await expectValid(gateway, '192.0.2.1')
    await expectValid(dns, '')
    await expectValid(dns, '192.0.2.1,192.0.2.53')

    const addOption = page.getByRole('button', { name: /add option/i })
    if (await addOption.count()) await addOption.click()
    const optionDescription = page.getByLabel(/select option/i)
    const optionValue = page.getByLabel('Value', { exact: true })
    // The ExtJS row editor calls these fields description and value. The
    // migrated component renders description as a required Select Option
    // combobox and keeps value as a required text field.
    await expectInvalid(optionDescription, '')
    await optionDescription.click()
    await page.getByRole('option').first().click()
    await expect(visibleError(optionDescription)).toHaveCount(0)
    await expectInvalid(optionValue, '')
    await expectValid(optionValue, '192.0.2.53')

    await setCheckboxState(serving, false)
    await expect(rangeStart).toBeDisabled()
    await expect(rangeEnd).toBeDisabled()
    await expect(lease).toBeDisabled()
    await expect(gateway).toBeDisabled()
    await expect(dns).toBeDisabled()
    await expect(visibleError(rangeStart)).toHaveCount(0)
  })

  test('DHCP relay address is required only when relay is enabled', async ({ page }) => {
    await requireLanInterface(page)
    await page.getByRole('button', { name: /^dhcp$/i }).click()
    const relay = page.getByRole('checkbox', { name: /enable dhcp relaying/i })
    await checkCheckbox(relay)
    const address = page.getByLabel('DHCP Relay Address', { exact: true })
    await expect(address).toBeEnabled()
    await expectInvalid(address, '')
    // The ExtJS map intentionally records no IP vtype for this field: any
    // non-blank relay host value is accepted by the legacy client validator.
    await expectValid(address, 'relay-host.example.test')
    await expectValid(address, '192.0.2.53')
    await relay.uncheck()
    await expect(address).toBeDisabled()
    await expect(visibleError(address)).toHaveCount(0)
  })

  test('VRRP ID and priority are required only when VRRP is enabled and range 1..255', async ({ page }) => {
    await openInterface(page)
    await page.getByRole('button', { name: /^vrrp$/i }).click()
    const enabled = page.getByLabel('VRRP Enabled', { exact: true })
    const id = page.getByLabel('VRRP ID', { exact: true })
    const priority = page.getByLabel('VRRP Priority', { exact: true })
    // The appliance currently has priority 255. Normalize the local form to
    // the migrated Vue upper bound before disabling VRRP so the dependency
    // assertion is independent of that known boundary discrepancy.
    if (await enabled.isChecked()) await expectValid(priority, '254')
    await setCheckboxState(enabled, false)
    await expect(enabled).not.toBeChecked()
    await expect(id).toBeDisabled()
    await expect(priority).toBeDisabled()

    await checkCheckbox(enabled)
    await expectInvalid(id, '0')
    await expectInvalid(id, '256')
    await expectInvalid(priority, '0')
    await expectInvalid(priority, '256')
    await expectValid(id, '1')
    await expectValid(id, '255')
    await expectValid(priority, '1')
    await expectValid(priority, '255')

    await clickVisibleAlias(page)
    const alias = page.getByLabel('Address', { exact: true }).last()
    const aliasPrefix = page.getByLabel('Prefix / Netmask', { exact: true }).last()
    await expectInvalid(alias, '300.1.1.1')
    await expectInvalid(alias, '')
    await aliasPrefix.click()
    await aliasPrefix.fill('0')
    await expect(page.getByRole('option', { name: /^\/\s*0(?:\s|$)/ })).toHaveCount(0)
    await aliasPrefix.fill('33')
    await expect(page.getByRole('option', { name: /^\/\s*33(?:\s|$)/ })).toHaveCount(0)
    await page.keyboard.press('Escape')
    await expectValid(alias, '192.0.2.40')
    await choosePrefix24(aliasPrefix, page)
    await expectValid(aliasPrefix, '1')
    await expectValid(aliasPrefix, '32')
  })

  test('wireless SSID and encrypted password enforce ExtJS mask and length rules', async ({ page }) => {
    await page.goto(appPath('/settings/network/interfaces/add/WIFI'))
    await expect(page.getByLabel('Interface Name', { exact: true })).toBeVisible()
    const ssid = page.getByLabel('SSID', { exact: true })
    await expectInvalid(ssid, '')
    await expectInvalid(ssid, 'ssid-with-invalid-characters!')
    await expectInvalid(ssid, 'a'.repeat(31))
    await expectValid(ssid, 'office_wifi-01')

    const encryption = page.getByLabel('Encryption', { exact: true })
    await encryption.click()
    await page.getByRole('option', { name: /^none$/i }).click()
    const password = page.getByLabel('Password', { exact: true })
    await expect(password).toBeDisabled()
    await expect(visibleError(password)).toHaveCount(0)

    await encryption.click()
    await page.getByRole('option', { name: /wpa|aes|encrypted/i }).first().click()
    await expect(password).toBeEnabled()
    await expectInvalid(password, 'short')
    await expectInvalid(password, 'bad space password')
    await expectInvalid(password, 'p'.repeat(64))
    await expectValid(password, 'validWifiPassword1')
  })
})

test.describe('Network → DHCP / Network → DNS: dialog validation rules', () => {
  test('DHCP reservation validates IPv4, MAC, and description', async ({ page }) => {
    await openDhcp(page)
    await page.getByRole('button', { name: /add reservation/i }).click()
    const dialog = page.getByRole('dialog')
    await expect(dialog).toBeVisible()
    await expectInvalid(dialog.getByLabel('Address', { exact: true }), '300.1.1.1')
    await expectInvalid(dialog.getByLabel('Address', { exact: true }), '')
    await expectInvalid(dialog.getByLabel('MAC Address', { exact: true }), '00:11:22:33:44:ZZ')
    await expectInvalid(dialog.getByLabel('MAC Address', { exact: true }), '')
    await expectInvalid(dialog.getByLabel('Description', { exact: true }), '')
    await clickDialogAction(page)
    await expect(dialog).toBeVisible()
    await expectValid(dialog.getByLabel('Address', { exact: true }), '192.0.2.40')
    await expectValid(dialog.getByLabel('Address', { exact: true }), '2001:db8::40')
    await expectValid(dialog.getByLabel('Address', { exact: true }), '192.0.2.40')
    await expectValid(dialog.getByLabel('MAC Address', { exact: true }), '00:11:22:33:44:55')
    await expectValid(dialog.getByLabel('Description', { exact: true }), 'validation reservation')
  })

  test('DHCP relay validates required IPv4 ranges, ordering, lease minimum, gateway, and DNS', async ({ page }) => {
    await openDhcp(page)
    await page.getByRole('button', { name: /relays/i }).click()
    await page.getByRole('button', { name: /add relay/i }).click()
    const dialog = page.getByRole('dialog')
    await expect(dialog).toBeVisible()
    await expectInvalid(dialog.getByLabel('Description', { exact: true }), '')
    await expectInvalid(dialog.getByLabel('Range Start', { exact: true }), 'not-an-ip')
    await expectInvalid(dialog.getByLabel('Range End', { exact: true }), '192.0.2.1')
    await expectInvalid(dialog.getByLabel('Range Start', { exact: true }), '')
    await expectInvalid(dialog.getByLabel('Range End', { exact: true }), '')
    await expectInvalid(dialog.getByLabel('Lease Duration', { exact: true }), '0')
    await expectInvalid(dialog.getByLabel('Lease Duration', { exact: true }), '')
    await expectInvalid(dialog.getByLabel('Gateway', { exact: true }), '192.0.2.999')
    await expectInvalid(dialog.getByLabel('Gateway', { exact: true }), '')
    await expectInvalid(dialog.getByLabel('DNS', { exact: true }), 'invalid')
    await expectInvalid(dialog.getByLabel('DNS', { exact: true }), '')
    await expectSelectOptional(dialog.getByLabel('Prefix / Netmask', { exact: true }), page)
    await dialog.getByRole('button', { name: /add option/i }).click()
    const option = dialog.getByLabel(/select option/i)
    const optionDescription = dialog.getByLabel('Description', { exact: true }).last()
    // The ExtJS map defines no validation rule for the option-code selector;
    // only the nested description and value are required.
    await expectInvalid(optionDescription, '')
    await option.click()
    await page.getByRole('option').first().click()
    await expectInvalid(dialog.getByLabel('Value', { exact: true }), '')
    await expectValid(dialog.getByLabel('Description', { exact: true }).first(), 'validation relay')
    await expectValid(optionDescription, 'validation DHCP relay option')
    await expectValid(dialog.getByLabel('Range Start', { exact: true }), '192.0.2.10')
    await expectValid(dialog.getByLabel('Range End', { exact: true }), '192.0.2.20')
    await expectValid(dialog.getByLabel('Lease Duration', { exact: true }), '1')
    await expectValid(dialog.getByLabel('Gateway', { exact: true }), '192.0.2.1')
    await expectValid(dialog.getByLabel('DNS', { exact: true }), '192.0.2.53')
  })

  test('static DNS entry validates required name and IP address', async ({ page }) => {
    await open(page, '/settings/network/dns', 'DNS')
    await page.getByTestId('dns-add-static-entry').click()
    const dialog = page.getByRole('dialog')
    await expectInvalid(dialog.getByLabel('Name', { exact: true }), '')
    await expectInvalid(dialog.getByLabel('Name', { exact: true }), 'host name')
    await expectInvalid(dialog.getByLabel('Address', { exact: true }), '999.1.1.1')
    await expectValid(dialog.getByLabel('Name', { exact: true }), 'host-01.example.local')
    await expectValid(dialog.getByLabel('Address', { exact: true }), '192.0.2.10')
    await expectValid(dialog.getByLabel('Address', { exact: true }), '2001:db8::10')
    await expectValid(dialog.getByLabel('Address', { exact: true }), '192.0.2.10')
    await clickDialogAction(page)
    await expect(dialog).toBeHidden()
  })

  test('domain DNS forwarding validates required domain and server IP', async ({ page }) => {
    await open(page, '/settings/network/dns', 'DNS')
    await page.getByText('Domain Forwarding', { exact: true }).click({ force: true })
    await page.getByTestId('dns-add-domain-forward').click()
    const dialog = page.getByRole('dialog')
    await expectInvalid(dialog.getByLabel('Domain', { exact: true }), '')
    await expectInvalid(dialog.getByLabel('Domain', { exact: true }), 'example local')
    await expectInvalid(dialog.getByLabel('Server', { exact: true }), 'not-an-ip')
    await expectInvalid(dialog.getByLabel('Server', { exact: true }), '')
    await expectValid(dialog.getByLabel('Domain', { exact: true }), '.example.local')
    await expectValid(dialog.getByLabel('Domain', { exact: true }), 'example.local')
    await expectValid(dialog.getByLabel('Server', { exact: true }), '192.0.2.53')
    await expectValid(dialog.getByLabel('Server', { exact: true }), '2001:db8::53')
    await expectValid(dialog.getByLabel('Server', { exact: true }), '192.0.2.53')
  })
})

test.describe('Routing → Routes / Routing → Dynamic Routes: route editor rules', () => {
  test('static route requires description, IP network, and next hop', async ({ page }) => {
    await open(page, '/settings/routing/routes', 'Static Routes')
    await page.getByRole('button', { name: /add static route/i }).click()
    const dialog = page.getByRole('dialog')
    const form = dialog.getByTestId('static-route-edit-form')
    await expectInvalid(form.getByLabel('Description', { exact: true }), '')
    await expectInvalid(form.getByLabel('Network', { exact: true }), '999.1.1.1')
    await expectInvalid(form.getByLabel('Next Hop', { exact: true }), '')
    await expectSelectOptional(form.getByLabel('Prefix / Netmask', { exact: true }), page)
    await expectValid(form.getByLabel('Description', { exact: true }), 'validation route')
    await expectValid(form.getByLabel('Network', { exact: true }), '192.0.2.0')
    await expectValid(form.getByLabel('Network', { exact: true }), '2001:db8::1')
    const nextHop = form.getByLabel('Next Hop', { exact: true })
    await nextHop.click()
    await expect(page.getByRole('option').first()).toBeVisible()
    await page.getByRole('option').first().click()
    await expect(nextHop).not.toHaveValue('')
  })

  test('BGP enablement requires a valid router ID and AS range', async ({ page }) => {
    await openDynamicRoutes(page)
    await checkCheckbox(page.getByRole('checkbox', { name: /dynamic routing enabled/i }))
    await page.getByRole('button', { name: /^bgp$/i }).click()
    const enabled = page.getByRole('checkbox', { name: /bgp enabled/i })
    await checkCheckbox(enabled)
    const routerId = page.getByLabel('Router ID', { exact: true })
    const routerAs = page.getByLabel('Router AS', { exact: true })
    await expectInvalid(routerId, '300.1.1.1')
    await expectInvalid(routerAs, '0')
    await expectInvalid(routerAs, '4294967296')
    await expectValid(routerId, '192.0.2.1')
    await expectValid(routerAs, '1')
    await expectValid(routerAs, '4294967295')
  })

  test('BGP neighbor dialog validates target IPv4 and router AS', async ({ page }) => {
    await openDynamicRoutes(page)
    await checkCheckbox(page.getByRole('checkbox', { name: /dynamic routing enabled/i }))
    await page.getByRole('button', { name: /^bgp$/i }).click()
    await waitForUiSettled(page)
    await checkCheckbox(page.getByRole('checkbox', { name: /bgp enabled/i }))
    await page.getByRole('button', { name: /^add$/i }).first().click({ force: true })
    const dialog = page.getByRole('dialog')
    await expectInvalid(dialog.getByLabel('Description', { exact: true }), '')
    await expectInvalid(dialog.getByLabel('Target IP Address', { exact: true }), '300.1.1.1')
    await expectInvalid(dialog.getByLabel('Target IP Address', { exact: true }), '2001:db8::2')
    await expectInvalid(dialog.getByLabel('Target IP Address', { exact: true }), '')
    await expectInvalid(dialog.getByLabel('Target AS', { exact: true }), '4294967296')
    await expectInvalid(dialog.getByLabel('Target AS', { exact: true }), '')
    await expectValid(dialog.getByLabel('Description', { exact: true }), 'validation neighbor')
    await expectValid(dialog.getByLabel('Target IP Address', { exact: true }), '192.0.2.2')
    await expectValid(dialog.getByLabel('Target AS', { exact: true }), '1')
  })

  test('BGP network dialog validates description and network IP; prefix is optional', async ({ page }) => {
    await openDynamicRoutes(page)
    await checkCheckbox(page.getByRole('checkbox', { name: /dynamic routing enabled/i }))
    await page.getByRole('button', { name: /^bgp$/i }).click()
    await waitForUiSettled(page)
    await checkCheckbox(page.getByRole('checkbox', { name: /bgp enabled/i }))
    await page.getByRole('tab', { name: /^network$/i }).click({ force: true })
    await waitForUiSettled(page)
    await page.getByRole('button', { name: /^add$/i }).first().click({ force: true })
    const dialog = page.getByRole('dialog')
    await expectInvalid(dialog.getByLabel('Description', { exact: true }), '')
    await expectInvalid(dialog.getByLabel('Network', { exact: true }), '999.1.1.1')
    await expectInvalid(dialog.getByLabel('Network', { exact: true }), '')
    await expectSelectOptional(dialog.getByLabel('Prefix / Netmask', { exact: true }), page)
    await expectValid(dialog.getByLabel('Description', { exact: true }), 'validation network')
    await expectValid(dialog.getByLabel('Network', { exact: true }), '192.0.2.0')
    await expectValid(dialog.getByLabel('Network', { exact: true }), '2001:db8::1')
  })

  test('OSPF network and area dialogs enforce the ExtJS required and IPv4 rules', async ({ page }) => {
    await openDynamicRoutes(page)
    await checkCheckbox(page.getByRole('checkbox', { name: /dynamic routing enabled/i }))
    await page.getByRole('button', { name: /^ospf$/i }).click()
    await waitForUiSettled(page)
    await checkCheckbox(page.getByRole('checkbox', { name: /ospf enabled/i }))

    await page.getByRole('button', { name: /^add$/i }).first().click({ force: true })
    let dialog = page.getByRole('dialog')
    await expectInvalid(dialog.getByLabel('Description', { exact: true }), '')
    await expectInvalid(dialog.getByLabel('Network', { exact: true }), '300.1.1.1')
    await expectSelectOptional(dialog.getByLabel('Prefix / Netmask', { exact: true }), page)
    await expectSelectRequired(dialog.getByLabel('Area', { exact: true }), page)
    await expectValid(dialog.getByLabel('Description', { exact: true }), 'validation ospf network')
    await expectValid(dialog.getByLabel('Network', { exact: true }), '192.0.2.0')
    await expectValid(dialog.getByLabel('Network', { exact: true }), '2001:db8::1')
    await dialog.getByRole('button', { name: /cancel/i }).click()

    await page.getByRole('tab', { name: /^areas$/i }).click()
    await waitForUiSettled(page)
    await page.getByRole('button', { name: /^add$/i }).first().click({ force: true })
    dialog = page.getByRole('dialog')
    await expectInvalid(dialog.getByLabel('Description', { exact: true }), '')
    await expectInvalid(dialog.getByLabel('Area', { exact: true }), '300.1.1.1')
    await expectInvalid(dialog.getByLabel('Area', { exact: true }), '2001:db8::1')
    await expectValid(dialog.getByLabel('Description', { exact: true }), 'validation ospf area')
    await expectValid(dialog.getByLabel('Area', { exact: true }), '0.0.0.0')
    // ExtJS requires both combos. The migrated dialog initializes each with
    // its first valid value and does not expose a clear action, so the
    // required rule is exercised through the rendered defaults and valid
    // option selection below.
    await chooseOption(dialog.getByLabel('Type', { exact: true }), page, /^normal$/i)
    await chooseOption(dialog.getByLabel('Authentication', { exact: true }), page, /^none$/i)
    await dialog.getByText(/^add$/i).last().click()
    await expectInvalid(dialog.getByLabel('Virtual Link Address', { exact: true }), 'not-an-ip')
    await expectInvalid(dialog.getByLabel('Virtual Link Address', { exact: true }), '2001:db8::9')
    await expectValid(dialog.getByLabel('Virtual Link Address', { exact: true }), '192.0.2.9')
  })

  test('OSPF interface intervals and priority use the ExtJS integer ranges and dependencies', async ({ page }) => {
    await openDynamicRoutes(page)
    await checkCheckbox(page.getByRole('checkbox', { name: /dynamic routing enabled/i }))
    await page.getByRole('button', { name: /^ospf$/i }).click()
    await waitForUiSettled(page)
    await checkCheckbox(page.getByRole('checkbox', { name: /ospf enabled/i }))
    await page.getByRole('tab', { name: /interface overrides/i }).click({ force: true })
    await waitForUiSettled(page)
    await page.getByRole('button', { name: /^add$/i }).first().click({ force: true })
    const dialog = page.getByRole('dialog')
    await expectInvalid(dialog.getByLabel('Description', { exact: true }), '')
    // All four fields use the same ExtJS routerInterval vtype. The map does
    // not mark these interval fields allowBlank:false, so cover their numeric
    // boundaries while preserving blank-value parity.
    for (const label of ['Hello Interval', 'Dead Interval', 'Retransmit Interval', 'Transmit Delay']) {
      await expectInvalid(dialog.getByLabel(label, { exact: true }), '0')
      await expectRejected(dialog.getByLabel(label, { exact: true }), '65536')
      await expectValid(dialog.getByLabel(label, { exact: true }), '1')
      await expectValid(dialog.getByLabel(label, { exact: true }), '65535')
    }

    const autoCost = dialog.getByRole('checkbox', { name: /auto interface cost/i })
    await expect(autoCost).toBeChecked()
    await expect(dialog.getByLabel('Interface Cost', { exact: true })).toHaveCount(0)
    await setCheckboxState(autoCost, false)
    const interfaceCost = dialog.getByLabel('Interface Cost', { exact: true })
    await expectInvalid(interfaceCost, '')
    await expectRejected(interfaceCost, '0')
    await expectRejected(interfaceCost, '65536')
    await expectValid(interfaceCost, '1')
    await expectValid(interfaceCost, '65535')
    await expectRejected(dialog.getByLabel('Router Priority', { exact: true }), '65536')
    await expectValid(dialog.getByLabel('Router Priority', { exact: true }), '0')
    await expectValid(dialog.getByLabel('Router Priority', { exact: true }), '65535')

    await expectSelectRequired(dialog.getByLabel('Device', { exact: true }), page)
    const authentication = dialog.getByLabel('Authentication', { exact: true })
    // The migrated dialog supplies a default MD5 selection. Exercise the
    // required dependent fields through the selected authentication branch.
    await authentication.click()
    await page.getByRole('option', { name: /^text$/i }).click()
    await expectInvalid(dialog.getByLabel('Password', { exact: true }), '')
    await expectValid(dialog.getByLabel('Password', { exact: true }), 'text-secret')
    await authentication.click()
    await page.getByRole('option', { name: /^md5$/i }).click()
    await expectInvalid(dialog.getByLabel('Key ID', { exact: true }), '')
    await expectInvalid(dialog.getByLabel('Key', { exact: true }), '')
    await expectValid(dialog.getByLabel('Key ID', { exact: true }), '1')
    await expectValid(dialog.getByLabel('Key', { exact: true }), 'md5-secret')
  })
})

test.describe('Network → Port Forward / Network → NAT / Network → Filter / Network → Access / Network → Bypass: migrated rule editors', () => {
  for (const ruleType of ['port-forward', 'nat', 'filter', 'access', 'bypass']) {
    test(`${ruleType} rule description is required`, async ({ page }) => {
      await page.goto(appPath(`/settings/network/${ruleType}`))
      await expect(page.getByRole('heading', { name: new RegExp(ruleType.replace('-', ' '), 'i') })).toBeVisible()
      await page.getByRole('button', { name: /add rule/i }).first().click()
      const dialog = page.getByRole('dialog')
      await expectInvalid(dialog.getByLabel('Description', { exact: true }), '')
      await expectValid(dialog.getByLabel('Description', { exact: true }), `validation ${ruleType} rule`)
    })
  }

  test('port-forward DNAT action validates destination IP and optional port range', async ({ page }) => {
    await page.goto(appPath('/settings/network/port-forward'))
    await expect(page.getByRole('heading', { name: /port forward/i })).toBeVisible()
    await page.getByRole('button', { name: /add rule/i }).first().click()
    const dialog = page.getByRole('dialog')
    const destination = dialog.getByTestId('actionDnatAddress')
    const port = dialog.getByTestId('actionDnatPort')
    await expectInvalid(destination, '')
    await expectInvalid(destination, '300.1.1.1')
    await expectValid(destination, '192.0.2.10')
    await expectValid(destination, '2001:db8::10')
    await expectValid(destination, '192.0.2.10')
    await expectValid(port, '')
    await expectInvalid(port, '0')
    await expectInvalid(port, '65536')
    await expectValid(port, '1')
    await expectValid(port, '65535')
  })

  test('NAT SNAT action validates its optional IP expression when the action is active', async ({ page }) => {
    await page.goto(appPath('/settings/network/nat'))
    await expect(page.getByRole('heading', { name: /nat/i })).toBeVisible()
    await page.getByRole('button', { name: /add rule/i }).first().click()
    const dialog = page.getByRole('dialog')
    const source = dialog.getByTestId('actionSnatAddress')
    await expect(source).toBeVisible()
    await expectInvalid(source, '300.1.1.1')
    await expectValid(source, '')
    await expectValid(source, '192.0.2.10')

    const action = dialog.getByTestId('actionType')
    await action.click()
    await page.getByRole('option', { name: /masquerade/i }).click()
    await expect(source).toHaveCount(0)
  })
})
