// Runs the API tests against PostgreSQL.
//
// With EXERLY_TEST_DATABASE_URL set (CI provides a service container), the
// tests use that server. Otherwise this starts a throwaway local cluster and
// removes it afterwards. DATABASE_URL is never used for tests.

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.join(__dirname, '..');
const files = process.argv.slice(2).length
  ? process.argv.slice(2)
  : fs
      .readdirSync(path.join(root, 'tests'))
      .filter((f) => f.endsWith('.test.js'))
      .map((f) => path.join('tests', f));

let cluster = null;
if (!process.env.EXERLY_TEST_DATABASE_URL) {
  cluster = require('../tests/helpers/cluster').start();
  process.env.EXERLY_TEST_DATABASE_URL = cluster.url;
}
const cleanup = () => cluster?.stop();
process.on('SIGINT', () => {
  cleanup();
  process.exit(130);
});

let status = 1;
try {
  const result = spawnSync(process.execPath, ['--test', ...files], {
    cwd: root,
    stdio: 'inherit',
    env: { ...process.env, DATABASE_URL: '' },
  });
  status = result.status ?? 1;
} finally {
  cleanup();
}
process.exit(status);
