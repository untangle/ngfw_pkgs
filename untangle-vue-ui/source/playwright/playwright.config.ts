import { defineConfig, devices } from '@playwright/test'

const storageState = process.env.NGFW_STORAGE_STATE || 'playwright/.auth/admin.json'

export default defineConfig({
  testDir: './tests',
  timeout: 60_000,
  expect: { timeout: 8_000 },
  fullyParallel: false,
  workers: 1,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: 'list',
  use: {
    baseURL: process.env.NGFW_UI_URL || 'http://127.0.0.1:4173',
    ignoreHTTPSErrors: true,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'setup-auth',
      testMatch: /auth\.setup\.ts/,
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'chromium',
      dependencies: ['setup-auth'],
      use: { ...devices['Desktop Chrome'], storageState },
    },
  ],
})
