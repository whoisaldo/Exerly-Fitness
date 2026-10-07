// Isolated production-shell fixture. Connection failures happen at the socket,
// so this also exercises engines without Playwright service-worker routing.
const express = require('express');
const path = require('node:path');
const app = express();
let disconnected = false;
app.use(express.json({ limit: '4kb' }));
app.post('/__test/connection', (req, res) => {
  if (req.get('X-Test-Fixture') !== 'isolated-simulator') return res.sendStatus(403);
  if (typeof req.body.disconnected !== 'boolean') return res.sendStatus(400);
  disconnected = req.body.disconnected;
  res.json({ disconnected });
});
app.use((req, _res, next) => {
  if (disconnected) return req.socket.destroy();
  next();
});
app.use(
  express.static(path.resolve(__dirname, '../artifacts/web-offline-dist'), {
    etag: false,
    lastModified: false,
    setHeaders: (res) => res.set('Cache-Control', 'no-store'),
  })
);
app.listen(3306, '0.0.0.0', () => process.stdout.write('Offline web fixture listening on 3306\n'));
