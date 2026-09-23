const { defineConfig } = require('@playwright/test');
const external = process.env.PLAYWRIGHT_BASE_URL;
const browserName = process.env.PLAYWRIGHT_BROWSER || 'chromium';
module.exports = defineConfig({
  testDir: './apps/web/e2e',
  timeout: 90000,
  workers: 1,
  retries: 0,
  reporter: 'list',
  outputDir: 'artifacts/web-tests',
  use: {
    baseURL: external || 'http://127.0.0.1:3301',
    browserName,
    channel: browserName === 'chromium' ? process.env.PLAYWRIGHT_CHANNEL || 'chrome' : undefined,
    viewport: { width: 1280, height: 900 },
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  webServer: external
    ? undefined
    : [
        {
          command: 'node scripts/ios-fixture-api.cjs',
          env: { EXERLY_FIXTURE_PORT: '39002', EXTRA_CORS_ORIGINS: 'http://127.0.0.1:3301' },
          url: 'http://127.0.0.1:39002/__test/ready',
          reuseExistingServer: false,
        },
        {
          command: 'npm run dev -w apps/web -- --host 0.0.0.0 --port 3301 --strictPort',
          env: { VITE_API_URL: 'http://127.0.0.1:39002' },
          url: 'http://127.0.0.1:3301',
          reuseExistingServer: false,
        },
      ],
});
