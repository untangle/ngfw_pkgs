import { defineConfig, devices } from '@playwright/test'

const baseURL = process.env.NGFW_UI_URL || 'http://localhost:9090/console/'
const authFile = process.env.NGFW_STORAGE_STATE || 'playwright/.auth/admin.json'
const isCI = process.env.CI === 'true'

export default defineConfig({
  testDir: './tests',
  fullyParallel: false,
  forbidOnly: isCI,
  retries: isCI ? 1 : 0,
  workers: 1,
  reporter: 'list',
  use: {
    baseURL,
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
    headless: isCI,
    ignoreHTTPSErrors: true,
  },
  projects: [
    {
      name: 'setup-auth',
      testMatch: /auth[.]setup[.]ts/,
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'interfaces',
      dependencies: ['setup-auth'],
      testMatch: /interfaces[.]spec[.]ts/,
      use: {
        ...devices['Desktop Chrome'],
        storageState: authFile,
      },
    },
    {
      name: 'interfaces-crud',
      dependencies: ['setup-auth'],
      testMatch: /crud[\\/]interfaces-vlan[.]spec[.]ts/,
      use: {
        ...devices['Desktop Chrome'],
        storageState: authFile,
      },
    },
    {
      name: 'create-vlan',
      dependencies: ['setup-auth'],
      testMatch: /crud[\\/]interfaces-vlan[.]spec[.]ts/,
      grep: /VLAN create: creates vlan1 on External and displays connected interface status/,
      use: {
        ...devices['Desktop Chrome'],
        storageState: authFile,
      },
    },
    {
      name: 'create-vlan-auto',
      dependencies: ['setup-auth'],
      testMatch: /crud[\\/]interfaces-vlan[.]spec[.]ts/,
      grep: /create-vlan-auto: creates vlan2 on External with Auto DHCP/,
      use: {
        ...devices['Desktop Chrome'],
        storageState: authFile,
      },
    },
    {
      name: 'create-vlan-pppoe',
      dependencies: ['setup-auth'],
      testMatch: /crud[\\/]interfaces-vlan[.]spec[.]ts/,
      grep: /create-vlan-pppoe: creates a VLAN on Internal with PPPoE/,
      use: {
        ...devices['Desktop Chrome'],
        storageState: authFile,
      },
    },
    {
      name: 'create-vlan-qos',
      dependencies: ['setup-auth'],
      testMatch: /crud[\\/]interfaces-vlan[.]spec[.]ts/,
      grep: /create-vlan-qos: creates a VLAN with QoS bandwidth/,
      use: {
        ...devices['Desktop Chrome'],
        storageState: authFile,
      },
    },
  ],
})
