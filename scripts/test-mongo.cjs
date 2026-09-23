// Isolated replica set: never use an application or production Mongo URI.
const { MongoMemoryReplSet } = require('mongodb-memory-server');
const { spawn } = require('node:child_process');
const { readdirSync } = require('node:fs');

(async () => {
  const mongo = await MongoMemoryReplSet.create({
    replSet: { count: 1 },
    binary: { version: '7.0.24' },
  });
  try {
    const files = readdirSync('apps/api/tests')
      .filter((name) => name.endsWith('.test.js'))
      .map((name) => `apps/api/tests/${name}`);
    const child = spawn(process.execPath, ['--test', ...files], {
      stdio: 'inherit',
      env: {
        ...process.env,
        EXERLY_TEST_DB: 'mongo',
        EXERLY_TEST_MONGODB_URI: mongo.getUri('exerly_test'),
      },
    });
    process.exitCode = await new Promise((resolve) => {
      child.on('exit', (code) => resolve(code ?? 1));
      child.on('error', (error) => {
        console.error(error.message);
        resolve(1);
      });
    });
  } finally {
    await mongo.stop();
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
