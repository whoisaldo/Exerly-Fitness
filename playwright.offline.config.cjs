const { defineConfig } = require('@playwright/test');
process.env.PLAYWRIGHT_API_URL = 'http://127.0.0.1:39006';
const browserName = process.env.PLAYWRIGHT_BROWSER || 'chromium';

module.exports = defineConfig({
  testDir: './apps/web',
  // Page-level network interception cannot control WebKit's service worker.
  // Its shell tests interrupt the actual fixture sockets instead.
  testMatch:
    browserName === 'chromium'
      ? ['offline-e2e/*.spec.ts', 'e2e/offline-startup.spec.ts']
      : ['offline-e2e/*.spec.ts'],
  timeout: 60000,
  workers: 1,
  retries: 0,
  reporter: 'list',
  outputDir: `artifacts/web-offline-${browserName}-tests`,
  use: {
    baseURL: 'http://127.0.0.1:3306',
    browserName,
    channel: browserName === 'chromium' ? process.env.PLAYWRIGHT_CHANNEL || 'chrome' : undefined,
    viewport: { width: 390, height: 844 },
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  webServer: [
    {
      command: 'node scripts/ios-fixture-api.cjs',
      env: { EXERLY_FIXTURE_PORT: '39006', EXTRA_CORS_ORIGINS: 'http://127.0.0.1:3306' },
      url: 'http://127.0.0.1:39006/__test/ready',
      reuseExistingServer: false,
    },
    {
      command:
        'npm exec -w apps/web -- vite build --outDir ../../artifacts/web-offline-dist --emptyOutDir && node scripts/offline-web-fixture.cjs',
      env: { VITE_API_URL: 'http://127.0.0.1:39006' },
      url: 'http://127.0.0.1:3306',
      timeout: 120000,
      reuseExistingServer: false,
    },
  ],
});
