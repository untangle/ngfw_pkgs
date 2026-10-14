import { defineConfig, devices } from '@playwright/test'

const baseURL =
  process.env.NGFW_UI_URL || 'http://127.0.0.1:4173'

const storageState =
  process.env.NGFW_STORAGE_STATE || 'playwright/.auth/admin.json'

const isCI = process.env.CI === 'true'

export default defineConfig({
  testDir: './tests',
  timeout: 60_000,
  expect: {
    timeout: 8_000,
  },
  fullyParallel: false,
  workers: 1,
  forbidOnly: isCI,
  retries: isCI ? 1 : 0,
  reporter: 'list',

  use: {
    baseURL,
    ignoreHTTPSErrors: true,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    headless: isCI,
  },

  projects: [
    // Authentication setup
    {
      name: 'setup-auth',
      testMatch: /auth[.]setup[.]ts/,
      use: {
        ...devices['Desktop Chrome'],
      },
    },

    // General Chromium tests
    {
      name: 'chromium',
      dependencies: ['setup-auth'],
      use: {
        ...devices['Desktop Chrome'],
        storageState,
      },
    },

    // Interface tests
    {
      name: 'interfaces',
      dependencies: ['setup-auth'],
      testMatch: /interfaces[.]spec[.]ts/,
      use: {
        ...devices['Desktop Chrome'],
        storageState,
      },
    },

    // All VLAN CRUD tests
    {
      name: 'interfaces-crud',
      dependencies: ['setup-auth'],
      testMatch: /crud[\\/]interfaces-vlan[.]spec[.]ts/,
      use: {
        ...devices['Desktop Chrome'],
        storageState,
      },
    },

    // Individual VLAN test projects
    {
      name: 'create-vlan',
      dependencies: ['setup-auth'],
      testMatch: /crud[\\/]interfaces-vlan[.]spec[.]ts/,
      grep: /VLAN create: creates vlan1 on External and displays connected interface status/,
      use: {
        ...devices['Desktop Chrome'],
        storageState,
      },
    },

    {
      name: 'create-vlan-auto',
      dependencies: ['setup-auth'],
      testMatch: /crud[\\/]interfaces-vlan[.]spec[.]ts/,
      grep: /create-vlan-auto: creates vlan2 on External with Auto DHCP/,
      use: {
        ...devices['Desktop Chrome'],
        storageState,
      },
    },

    {
      name: 'create-vlan-dhcp',
      dependencies: ['setup-auth'],
      testMatch: /crud[\\/]interfaces-vlan[.]spec[.]ts/,
      grep: /create-vlan-dhcp: creates a VLAN with Auto DHCP/,
      use: {
        ...devices['Desktop Chrome'],
        storageState,
      },
    },

    {
      name: 'create-vlan-pppoe',
      dependencies: ['setup-auth'],
      testMatch: /crud[\\/]interfaces-vlan[.]spec[.]ts/,
      grep: /create-vlan-pppoe: creates a VLAN on Internal with PPPoE/,
      use: {
        ...devices['Desktop Chrome'],
        storageState,
      },
    },

    {
      name: 'create-vlan-qos',
      dependencies: ['setup-auth'],
      testMatch: /crud[\\/]interfaces-vlan[.]spec[.]ts/,
      grep: /create-vlan-qos: creates a VLAN with QoS bandwidth/,
      use: {
        ...devices['Desktop Chrome'],
        storageState,
      },
    },

    {
      name: 'create-vlan-vrrp',
      dependencies: ['setup-auth'],
      testMatch: /crud[\\/]interfaces-vlan[.]spec[.]ts/,
      grep: /create-vlan-vrrp: creates a VLAN with VRRP/,
      use: {
        ...devices['Desktop Chrome'],
        storageState,
      },
    },
  ],
})