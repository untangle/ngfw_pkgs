import { test, expect, Page, Route } from '@playwright/test'

const config = {
  account: 'inbox@example.invalid',
  companyName: 'Example',
  quarantineDays: 14,
  timeZoneOffset: 2 * 60 * 60 * 1000,
}
const token = 'test+token/='
const date = Date.UTC(2026, 9, 6, 13, 5, 9)
const messages = [
  {
    mailID: 'older',
    internDate: date - 1000,
    mailSummary: {
      sender: 'Sender@example.invalid',
      attachmentCount: 0,
      quarantineDetail: 0,
      subject: '<img src=x onerror="window.mailScriptRan=true"> [literal].*',
      quarantineSize: 2048,
    },
  },
  {
    mailID: 'newer',
    internDate: date,
    mailSummary: {
      sender: 'Sender@example.invalid',
      attachmentCount: 2,
      quarantineDetail: 'Virus detected',
      subject: 'Newest message',
      quarantineSize: 607,
    },
  },
  {
    mailID: 'mixed-case',
    internDate: date - 2000,
    mailSummary: { sender: 'sender@example.invalid', subject: 'Another message', quarantineSize: 0 },
  },
]
type Call = { method: string; params: any[] }
type Reply = {
  httpStatus?: number
  result?: any
  error?: { code: number; msg: string; trace?: string }
}
type Handler = (call: Call, route: Route) => Reply | Promise<Reply>

async function publicRpc(page: Page, handler: Handler = () => ({})) {
  const calls: Call[] = []
  const adminCalls: string[] = []
  page.on('request', request => {
    if (request.url().includes('/admin/JSON-RPC')) adminCalls.push(request.url())
  })
  await page.route('**/quarantine/JSON-RPC', async route => {
    const request = route.request().postDataJSON()
    const call = { method: request.method, params: request.params }
    calls.push(call)
    let response: Reply
    if (call.method === 'system.listMethods') {
      response = {
        result: [
          'getUserQuarantineConfigV2',
          'getInboxRecords',
          'releaseMessages',
          'purgeMessages',
          'safelist',
          'getCompanyName',
          'requestDigest',
        ].map(name => `Quarantine.${name}`),
      }
    } else {
      response = await handler(call, route)
      if (!('result' in response) && !response.error && !response.httpStatus) {
        response = {
          result: call.method.endsWith('getUserQuarantineConfigV2')
            ? config
            : call.method.endsWith('getInboxRecords')
            ? { list: messages }
            : 'Example',
        }
      }
    }
    await route.fulfill({
      status: response.httpStatus || 200,
      contentType: 'application/json',
      body: JSON.stringify({ id: request.id, ...response }),
    })
  })
  return { calls, adminCalls }
}
async function openConsoleRoute(page: Page, route: string) {
  // Load the console index while setting its initial browser location before
  // Vue Router starts. This exercises the public route without booting the
  // default admin route first.
  await page.addInitScript(path => window.history.replaceState({}, '', path), route)
  await page.goto('')
}
async function openDigest(page: Page, value = token) {
  await openConsoleRoute(page, `/console/quarantine/manageuser?tkn=${encodeURIComponent(value)}`)
  await expect(page.getByText(`Quarantine Digest for: ${config.account}`, { exact: true })).toBeVisible()
}
const grid = (page: Page) => page.locator('#quarantine_digest_messages')
const rows = (page: Page) => grid(page).locator('.ag-center-cols-container .ag-row')
// AG Grid's selection column is separate from its center row container.
const rowCheckbox = (page: Page, id: string) =>
  grid(page).locator(`.ag-pinned-left-cols-container [row-id="${id}"] .ag-selection-checkbox`)
const release = (page: Page) => page.getByRole('button', { name: 'Release to Inbox', exact: true })
const safelist = (page: Page) =>
  page.getByRole('button', { name: 'Release to Inbox & Add Senders to Safe List', exact: true })
const remove = (page: Page) => page.getByRole('button', { name: 'Delete', exact: true })

test.use({ timezoneId: 'America/Los_Angeles' })

const browserErrors = new WeakMap<Page, string[]>()
test.beforeEach(async ({ page }, testInfo) => {
  const errors: string[] = []
  browserErrors.set(page, errors)
  page.on('pageerror', error => errors.push(error.message))
  page.on('console', message => {
    if (
      message.type() === 'error' &&
      !(
        testInfo.title.startsWith('HTTP 503 ') &&
        message.text() === 'Failed to load resource: the server responded with a status of 503 (Service Unavailable)'
      )
    )
      errors.push(message.text())
  })
})
test.afterEach(async ({ page }) => {
  expect(browserErrors.get(page)).toEqual([])
})

test('public digest renders nested records, safe text, six fields, ordering and appliance time', async ({ page }) => {
  const { calls, adminCalls } = await publicRpc(page)
  await openDigest(page)
  await expect(rows(page)).toHaveCount(3)
  await expect(page).toHaveTitle(`Example | Quarantine Digest for: ${config.account}`)
  await expect(page.getByRole('tab')).toHaveCount(1)
  await expect(grid(page).getByRole('columnheader')).toHaveCount(7)
  await expect(rows(page).first()).toHaveAttribute('row-id', 'newer')
  const old = rows(page).filter({ hasText: '[literal].*' })
  await expect(old.locator('[col-id="attachmentCount"]')).toHaveText('')
  await expect(old.locator('[col-id="quarantineDetail"]')).toHaveText('0')
  await expect(old.locator('[col-id="quarantineSize"]')).toHaveText('2 KB')
  await expect(rows(page).first().locator('[col-id="internDate"]')).toHaveText('2026-10-06 03:05:09 pm')
  await expect(old.locator('[col-id="subject"] img')).toHaveCount(0)
  expect(await page.evaluate(() => (window as any).mailScriptRan)).toBeUndefined()
  expect(calls.filter(call => call.method.endsWith('getInboxRecords'))[0].params).toEqual([token])
  expect(adminCalls).toEqual([])
  await expect(release(page)).toBeDisabled()
})

test('literal global filtering, case toggle and filtered select-all', async ({ page }) => {
  await publicRpc(page)
  await openDigest(page)
  await expect(rows(page)).toHaveCount(3)
  const search = page.getByPlaceholder('Filter ...', { exact: true })
  await search.fill('[literal].*')
  await expect(rows(page)).toHaveCount(1)
  await grid(page).locator('[col-id="sel-column"] .ag-header-select-all').click()
  await expect(release(page)).toBeEnabled()
  await search.fill('Sender@example.invalid')
  await expect(rows(page)).toHaveCount(3)
  await page.getByText('Case sensitive', { exact: true }).click()
  await expect(page.getByRole('checkbox', { name: 'Case sensitive', exact: true })).toBeChecked()
  await expect(rows(page)).toHaveCount(2)
  await search.fill('')
  await expect(rows(page)).toHaveCount(3)
})

for (const [label, query] of [
  ['missing', ''],
  ['empty', '?tkn='],
  ['duplicate', '?tkn=a&tkn=b'],
]) {
  test(`${label} token returns to request without loading an inbox`, async ({ page }) => {
    const { calls, adminCalls } = await publicRpc(page)
    await openConsoleRoute(page, `/console/quarantine/manageuser${query}`)
    await expect(page).toHaveURL(/\/console\/quarantine$/)
    await expect(page.getByRole('button', { name: 'Request', exact: true })).toBeVisible()
    expect(
      calls.some(call => call.method.endsWith('getInboxRecords') || call.method.endsWith('getUserQuarantineConfigV2')),
    ).toBe(false)
    expect(adminCalls).toEqual([])
  })
}

test('invalid token redirects and never displays raw exception text', async ({ page }) => {
  await publicRpc(page, call =>
    call.method.endsWith('getUserQuarantineConfigV2')
      ? {
          error: {
            code: 490,
            msg: 'SECRET_TOKEN',
            trace: 'com.untangle.app.smtp.quarantine.BadTokenException: SECRET_TOKEN',
          },
        }
      : {},
  )
  await openConsoleRoute(page, `/console/quarantine/manageuser?tkn=${encodeURIComponent(token)}`)
  await expect(page).toHaveURL(/\/console\/quarantine$/)
  await expect(page.getByText('SECRET_TOKEN')).toHaveCount(0)
})

for (const shape of ['list', 'array', 'malformed', 'missing-inbox', 'config-outage']) {
  test(`${shape} response preserves empty versus failed load behavior`, async ({ page }) => {
    await publicRpc(page, call => {
      if (call.method.endsWith('getUserQuarantineConfigV2') && shape === 'config-outage')
        return { error: { code: 490, msg: 'SECRET_TOKEN', trace: 'java.lang.NullPointerException: SECRET_TOKEN' } }
      if (call.method.endsWith('getInboxRecords')) {
        if (shape === 'list') return { result: { list: [] } }
        if (shape === 'array') return { result: [] }
        if (shape === 'malformed') return { result: {} }
        return {
          error: {
            code: 490,
            msg: 'SECRET_TOKEN',
            trace: 'com.untangle.app.smtp.quarantine.NoSuchInboxException: SECRET_TOKEN',
          },
        }
      }
      return {}
    })
    await openConsoleRoute(page, `/console/quarantine/manageuser?tkn=${encodeURIComponent(token)}`)
    if (shape === 'list' || shape === 'array') {
      await expect(page.getByText('No Quarantined Messages found', { exact: true })).toBeVisible()
      await expect(
        page.getByText('The messages below were quarantined and will be deleted after 14 days.', { exact: true }),
      ).toBeVisible()
    } else {
      const error =
        shape === 'config-outage'
          ? 'Quarantine Service Error. Please try again later.'
          : 'Unable to load quarantined messages. Please try again later.'
      await expect(page.getByText(error).first()).toBeVisible()
      await expect(page.getByText('No Quarantined Messages found')).toHaveCount(0)
      await expect(page.getByText('SECRET_TOKEN')).toHaveCount(0)
    }
  })
}

for (const action of ['releaseMessages', 'purgeMessages', 'safelist']) {
  test(`${action} uses the public API once and refreshes actual rows`, async ({ page }) => {
    let mutated = false
    const { calls } = await publicRpc(page, call => {
      if (call.method.endsWith(action)) {
        mutated = true
        return {
          result: {
            totalRecords: 1,
            releaseCount: action === 'releaseMessages' ? 1 : 2,
            purgeCount: action === 'purgeMessages' ? 1 : 0,
            safelistCount: 0,
          },
        }
      }
      if (call.method.endsWith('getInboxRecords') && mutated)
        return { result: { list: messages.filter(row => row.mailID === 'mixed-case') } }
      return {}
    })
    await openDigest(page)
    await expect(rows(page)).toHaveCount(3)
    await rowCheckbox(page, 'newer').click()
    await expect(release(page)).toBeEnabled()
    await (action === 'releaseMessages'
      ? release(page)
      : action === 'purgeMessages'
      ? remove(page)
      : safelist(page)
    ).click()
    await expect(rows(page)).toHaveCount(1)
    await expect(release(page)).toBeDisabled()
    expect(calls.filter(call => call.method.endsWith(action))).toEqual([
      {
        method: `Quarantine.${action}`,
        params: [token, action === 'safelist' ? ['Sender@example.invalid'] : ['newer']],
      },
    ])
    expect(calls.filter(call => call.method.endsWith('getInboxRecords'))).toHaveLength(2)
    if (action === 'safelist') {
      expect(calls.some(call => call.method.endsWith('releaseMessages'))).toBe(false)
      await expect(page.getByText(/Safelisted \d+ Addresses/)).toHaveCount(0)
    }
  })
}

test('successful mutation followed by failed refresh reports the read failure separately', async ({ page }) => {
  let mutated = false
  await publicRpc(page, call => {
    if (call.method.endsWith('releaseMessages')) {
      mutated = true
      return { result: { releaseCount: 1 } }
    }
    if (call.method.endsWith('getInboxRecords') && mutated)
      return { error: { code: 490, msg: 'SECRET_TOKEN', trace: 'java.lang.RuntimeException: SECRET_TOKEN' } }
    return {}
  })
  await openDigest(page)
  await expect(rows(page)).toHaveCount(3)
  await rowCheckbox(page, 'newer').click()
  await release(page).click()
  await expect(page.getByText('Released 1 Messages', { exact: true })).toBeVisible()
  await expect(page.getByText('Unable to load quarantined messages. Please try again later.').first()).toBeVisible()
  await expect(page.getByText('Unable to complete the quarantine action. Please try again later.')).toHaveCount(0)
})

test('message connection failure offers reload without administrator authentication', async ({ page }) => {
  const { adminCalls } = await publicRpc(page, call =>
    call.method.endsWith('getInboxRecords') ? { error: { code: 550, msg: 'SECRET_TOKEN' } } : {},
  )
  await openConsoleRoute(page, `/console/quarantine/manageuser?tkn=${encodeURIComponent(token)}`)
  await expect(
    page.getByText('The connection to the quarantine service was lost. Click OK to reload this page.', { exact: true }),
  ).toBeVisible()
  await expect(page.getByRole('button', { name: 'OK', exact: true })).toBeVisible()
  expect(adminCalls).toEqual([])
})

test('missing summaries and unidentifiable records render but cannot authorize actions', async ({ page }) => {
  await publicRpc(page, call =>
    call.method.endsWith('getInboxRecords')
      ? {
          result: {
            list: [
              { mailID: 'summary-missing', internDate: date },
              { internDate: date - 1000, mailSummary: { sender: 'unknown@example.invalid' } },
            ],
          },
        }
      : {},
  )
  await openDigest(page)
  await expect(rows(page)).toHaveCount(2)
  await expect(rows(page).first().locator('[col-id="sender"]')).toHaveText('')
  await grid(page).locator('[col-id="sel-column"] .ag-header-select-all').click()
  await expect(release(page)).toBeEnabled()
  await expect(safelist(page)).toBeDisabled()
})

test('sender safelisting deduplicates exact values without changing mixed case', async ({ page }) => {
  const { calls } = await publicRpc(page, call =>
    call.method.endsWith('safelist') ? { result: { safelistCount: 2, releaseCount: 3 } } : {},
  )
  await openDigest(page)
  await expect(rows(page)).toHaveCount(3)
  await grid(page).locator('[col-id="sel-column"] .ag-header-select-all').click()
  await safelist(page).click()
  await expect(page.getByText('Safelisted 2 Addresses', { exact: true })).toBeVisible()
  const selected = calls.find(call => call.method.endsWith('safelist'))
  expect(selected?.params[0]).toBe(token)
  expect(selected?.params[1].sort()).toEqual(['Sender@example.invalid', 'sender@example.invalid'])
  expect(calls.filter(call => call.method.endsWith('safelist'))).toHaveLength(1)
})

test('zero-count release refreshes without a positive success notification', async ({ page }) => {
  const { calls } = await publicRpc(page, call =>
    call.method.endsWith('releaseMessages') ? { result: { releaseCount: 0 } } : {},
  )
  await openDigest(page)
  await expect(rows(page)).toHaveCount(3)
  await rowCheckbox(page, 'newer').click()
  await release(page).click()
  await expect(rows(page)).toHaveCount(3)
  await expect(release(page)).toBeDisabled()
  expect(calls.filter(call => call.method.endsWith('getInboxRecords'))).toHaveLength(2)
  await expect(page.getByText(/Released [0-9]+ Messages/)).toHaveCount(0)
})

test('action exception stops busy, preserves rows and never redirects after initial config', async ({ page }) => {
  await publicRpc(page, call =>
    call.method.endsWith('releaseMessages')
      ? {
          error: {
            code: 490,
            msg: 'SECRET_TOKEN',
            trace: 'com.untangle.app.smtp.quarantine.BadTokenException: SECRET_TOKEN',
          },
        }
      : {},
  )
  await openDigest(page)
  await expect(rows(page)).toHaveCount(3)
  await rowCheckbox(page, 'newer').click()
  await release(page).click()
  await expect(
    page.getByText('Unable to complete the quarantine action. Please try again later.', { exact: true }),
  ).toBeVisible()
  await expect(rows(page)).toHaveCount(3)
  await expect(page).toHaveURL(/manageuser/)
  await expect(page.getByText('SECRET_TOKEN')).toHaveCount(0)
  await expect(page.getByPlaceholder('Filter ...', { exact: true })).toBeEnabled()
})

async function changePublicRoute(page: Page, query: string) {
  // This matches the existing pilot's history/popstate navigation and exercises
  // the public route watcher without recreating the browser page.
  await page.evaluate(value => {
    window.history.pushState({}, '', `/console/quarantine/manageuser${value}`)
    window.dispatchEvent(new PopStateEvent('popstate'))
  }, query)
}

for (const delayedMethod of ['getUserQuarantineConfigV2', 'getInboxRecords', 'releaseMessages']) {
  test(`token change ignores a pending ${delayedMethod} response`, async ({ page }) => {
    let finishOld!: () => void
    const pending = new Promise<void>(resolve => {
      finishOld = resolve
    })
    let oldCalled = false
    const { calls } = await publicRpc(page, async call => {
      const newAccount = call.params[0] === 'second-token'
      if (call.method.endsWith(delayedMethod) && !newAccount && !oldCalled) {
        oldCalled = true
        await pending
      }
      if (call.method.endsWith('getUserQuarantineConfigV2'))
        return { result: { ...config, account: newAccount ? 'second@example.invalid' : config.account } }
      if (call.method.endsWith('getInboxRecords')) return { result: { list: newAccount ? [messages[2]] : messages } }
      if (call.method.endsWith('releaseMessages')) return { result: { releaseCount: 1 } }
      return {}
    })
    await openConsoleRoute(page, `/console/quarantine/manageuser?tkn=${encodeURIComponent(token)}`)
    if (delayedMethod === 'releaseMessages') {
      await expect(rows(page)).toHaveCount(3)
      await rowCheckbox(page, 'newer').click()
      await release(page).click()
    }
    await expect.poll(() => oldCalled).toBe(true)
    await changePublicRoute(page, '?tkn=second-token')
    await expect(page.getByText('Quarantine Digest for: second@example.invalid', { exact: true })).toBeVisible()
    await expect(rows(page)).toHaveCount(1)
    const oldResponse = page.waitForResponse(response => {
      if (!response.url().endsWith('/quarantine/JSON-RPC')) return false
      const request = response.request().postDataJSON()
      return request.method.endsWith(delayedMethod) && request.params[0] === token
    })
    finishOld()
    await oldResponse
    await expect(page.getByText(`Quarantine Digest for: ${config.account}`, { exact: true })).toHaveCount(0)
    await expect(rows(page)).toHaveCount(1)
    await expect(release(page)).toBeDisabled()
    if (delayedMethod === 'releaseMessages') {
      expect(calls.filter(call => call.method.endsWith('getInboxRecords') && call.params[0] === token)).toHaveLength(1)
      await expect(page.getByText('Released 1 Messages', { exact: true })).toHaveCount(0)
    }
  })
}

test('busy spans the mutation and refresh and suppresses repeated clicks', async ({ page }) => {
  let finishMutation!: () => void
  let finishRefresh!: () => void
  const mutationGate = new Promise<void>(resolve => {
    finishMutation = resolve
  })
  const refreshGate = new Promise<void>(resolve => {
    finishRefresh = resolve
  })
  let mutated = false
  const { calls } = await publicRpc(page, async call => {
    if (call.method.endsWith('releaseMessages')) {
      mutated = true
      await mutationGate
      return { result: { releaseCount: 1 } }
    }
    if (call.method.endsWith('getInboxRecords') && mutated) {
      await refreshGate
      return { result: { list: [] } }
    }
    return {}
  })
  await openDigest(page)
  await expect(rows(page)).toHaveCount(3)
  await rowCheckbox(page, 'newer').click()
  await release(page).click()
  await expect(release(page)).toBeDisabled()
  finishMutation()
  await expect(page.getByText('Released 1 Messages', { exact: true })).toBeVisible()
  await expect(release(page)).toBeDisabled()
  await expect(page.getByPlaceholder('Filter ...', { exact: true })).toBeDisabled()
  finishRefresh()
  await expect(page.getByText('No Quarantined Messages found', { exact: true })).toBeVisible()
  await expect(page.getByPlaceholder('Filter ...', { exact: true })).toBeEnabled()
  expect(calls.filter(call => call.method.endsWith('releaseMessages'))).toHaveLength(1)
})

test('unrelated query change preserves the account header and request navigation resets it', async ({ page }) => {
  await publicRpc(page)
  await openDigest(page)
  await expect(rows(page)).toHaveCount(3)
  await changePublicRoute(page, `?tkn=${encodeURIComponent(token)}&extra=1`)
  await expect(page.getByText(`Quarantine Digest for: ${config.account}`, { exact: true })).toBeVisible()
  await changePublicRoute(page, '')
  await expect(page).toHaveURL(/\/console\/quarantine$/)
  await expect(page.getByRole('button', { name: 'Request', exact: true })).toBeVisible()
  await expect(page.getByText(`Quarantine Digest for: ${config.account}`, { exact: true })).toHaveCount(0)
  await expect(page).toHaveTitle('Example | Request Quarantine Digest')
})

test('numeric column filtering uses raw bytes and global search clears column filters', async ({ page }) => {
  await publicRpc(page)
  await openDigest(page)
  await expect(rows(page)).toHaveCount(3)
  const header = grid(page).getByRole('columnheader', { name: 'Size', exact: true })
  await header.hover()
  await header.locator('.ag-header-cell-menu-button').click()
  // AG Grid renders a second, hidden condition input; use the visible first condition.
  await page.getByRole('spinbutton', { name: 'Filter Value', exact: true }).first().fill('2048')
  await expect(rows(page)).toHaveCount(1)
  await page.getByRole('tab', { name: 'Quarantined Messages', exact: true }).click()
  await page.getByPlaceholder('Filter ...', { exact: true }).fill('Sender@example.invalid')
  await expect(rows(page)).toHaveCount(3)
  await page.getByPlaceholder('Filter ...', { exact: true }).fill('')
  const subject = grid(page).getByRole('columnheader', { name: 'Subject', exact: true })
  await subject.hover()
  await subject.locator('.ag-header-cell-menu-button').click()
  await page.getByRole('textbox', { name: 'Filter Value', exact: true }).first().fill('Newest')
  await expect(rows(page)).toHaveCount(1)
  await page.getByRole('tab', { name: 'Quarantined Messages', exact: true }).click()
  await page.getByPlaceholder('Filter ...', { exact: true }).fill('Another')
  await expect(rows(page)).toHaveCount(1)
  await expect(rows(page).first()).toHaveAttribute('row-id', 'mixed-case')
  await page.getByPlaceholder('Filter ...', { exact: true }).fill('')
  await expect(rows(page)).toHaveCount(3)
})

for (const failure of [
  { name: 'HTTP 503', reply: { httpStatus: 503 } },
  { name: 'Windows connection lost', reply: { error: { code: 12029, msg: 'SECRET_TOKEN' } } },
  { name: 'Windows invalid connection state', reply: { error: { code: 12019, msg: 'SECRET_TOKEN' } } },
  { name: 'method unavailable', reply: { error: { code: 591, msg: 'method not found SECRET_TOKEN' } } },
  {
    name: 'temporarily unavailable service',
    reply: { error: { code: 490, msg: 'Service Temporarily Unavailable SECRET_TOKEN' } },
  },
  {
    name: 'unavailable application',
    reply: { error: { code: 490, msg: 'This application is not currently available SECRET_TOKEN' } },
  },
]) {
  test(`${failure.name} offers the public reload recovery without exposing the exception`, async ({ page }) => {
    await publicRpc(page, call => (call.method.endsWith('getInboxRecords') ? failure.reply : {}))
    await openConsoleRoute(page, `/console/quarantine/manageuser?tkn=${encodeURIComponent(token)}`)
    await expect(
      page.getByText('The connection to the quarantine service was lost. Click OK to reload this page.', {
        exact: true,
      }),
    ).toBeVisible()
    await expect(page.getByRole('button', { name: 'OK', exact: true })).toBeVisible()
    await expect(page.getByText('SECRET_TOKEN')).toHaveCount(0)
  })
}
