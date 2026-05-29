import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/playwright',
  timeout: 45_000,
  workers: 1,
  expect: { timeout: 10_000 },
  reporter: [['list']],
  use: {
    baseURL: 'http://127.0.0.1:8099',
    channel: 'chrome',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'off',
  },
  webServer: {
    command: 'npx serve -s build/web -l tcp://127.0.0.1:8099',
    url: 'http://127.0.0.1:8099',
    reuseExistingServer: !process.env.CI,
    timeout: 60_000,
  },
  projects: [
    {
      name: 'chrome-desktop',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'chrome-mobile',
      use: { ...devices['Pixel 7'] },
    },
  ],
});
