import { defineConfig, type Plugin, type ResolvedConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';
import fs from 'node:fs';
import { createHash } from 'node:crypto';

function offlineShell(): Plugin {
  let config: ResolvedConfig;
  return {
    name: 'exerly-offline-shell',
    apply: 'build',
    configResolved(value) {
      config = value;
    },
    closeBundle() {
      const directory = path.resolve(config.root, config.build.outDir);
      const assets: string[] = ['/index.html'];
      const visit = (folder: string) => {
        for (const entry of fs.readdirSync(path.join(directory, folder), { withFileTypes: true })) {
          const relative = `${folder}/${entry.name}`;
          if (entry.isDirectory()) visit(relative);
          else if (/\.(?:js|css|woff2?|ttf|svg|png|jpe?g|webp)$/.test(entry.name))
            assets.push('/' + relative);
        }
      };
      visit('assets');
      visit('fonts');
      for (const name of ['ExerlyLogo.png', 'logo192.png', 'logo512.png', 'manifest.json']) {
        if (fs.existsSync(path.join(directory, name))) assets.push('/' + name);
      }
      assets.sort();
      const template = fs.readFileSync(path.resolve(__dirname, 'offline-worker.js'), 'utf8');
      const hash = createHash('sha256').update(template);
      for (const asset of assets)
        hash.update(asset).update(fs.readFileSync(path.join(directory, asset)));
      const version = hash.digest('hex').slice(0, 24);
      fs.writeFileSync(
        path.join(directory, 'offline-worker.js'),
        template
          .replace('__EXERLY_SHELL_MANIFEST__', JSON.stringify(assets))
          .replace('__EXERLY_SHELL_VERSION__', JSON.stringify(version))
      );
    },
  };
}

export default defineConfig({
  plugins: [react(), offlineShell()],
  base: '/',
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
    },
  },
  server: {
    port: 3000,
    // Bound to all interfaces so a phone on the same wifi, or another machine
    // on the tailnet, can open the dev server.
    host: '0.0.0.0',
    proxy: {
      '/api': 'http://localhost:3001',
      '/signup': 'http://localhost:3001',
      '/login': 'http://localhost:3001',
      '/ping': 'http://localhost:3001',
    },
  },
});
