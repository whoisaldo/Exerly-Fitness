// A throwaway PostgreSQL cluster for tests and fixtures.
//
// initdb into a temporary directory, listening on a Unix socket in that
// directory and on no TCP port, so it can't collide with anything else on the
// machine. stop() shuts it down and deletes the directory; it touches nothing
// it did not create.

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

function binary(name) {
  // Debian and Ubuntu keep server binaries in /usr/lib/postgresql/<major>/bin.
  const debian = fs.existsSync('/usr/lib/postgresql')
    ? fs
        .readdirSync('/usr/lib/postgresql')
        .sort((a, b) => Number(b) - Number(a))
        .map((major) => `/usr/lib/postgresql/${major}/bin`)
    : [];
  // Homebrew's versioned formulas are keg-only, so they aren't on the PATH.
  const kegs = ['/opt/homebrew/opt', '/usr/local/opt'].flatMap((prefix) =>
    fs.existsSync(prefix)
      ? fs
          .readdirSync(prefix)
          .filter((name) => /^postgresql(@\d+)?$/.test(name))
          .sort((a, b) => Number(b.split('@')[1] ?? 0) - Number(a.split('@')[1] ?? 0))
          .map((name) => `${prefix}/${name}/bin`)
      : []
  );
  const dirs = [process.env.PG_BIN, '/opt/homebrew/bin', '/usr/local/bin', ...kegs, ...debian];
  for (const dir of dirs.filter(Boolean)) {
    const candidate = path.join(dir, name);
    if (fs.existsSync(candidate)) return candidate;
  }
  return name;
}

// A cluster whose owning process was killed outlives it. Each records its
// owner; starting a new cluster stops those whose owner is gone.
function sweep() {
  for (const name of fs
    .readdirSync(os.tmpdir())
    .filter((entry) => entry.startsWith('exerly-pg-'))) {
    const root = path.join(os.tmpdir(), name);
    const file = path.join(root, 'owner.pid');
    const owner = fs.existsSync(file) ? Number(fs.readFileSync(file, 'utf8')) : 0;
    if (!owner) continue;
    try {
      process.kill(owner, 0);
      continue;
    } catch (error) {
      if (error.code !== 'ESRCH') continue;
    }
    try {
      execFileSync(
        binary('pg_ctl'),
        ['-D', path.join(root, 'data'), '-m', 'immediate', '-w', 'stop'],
        {
          stdio: 'ignore',
        }
      );
    } catch {
      // Already stopped.
    }
    fs.rmSync(root, { recursive: true, force: true });
  }
}

function start() {
  sweep();
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'exerly-pg-'));
  fs.writeFileSync(path.join(root, 'owner.pid'), String(process.pid));
  const data = path.join(root, 'data');
  // The postmaster refuses to start on macOS without a valid locale.
  const quiet = { stdio: ['ignore', 'ignore', 'pipe'], env: { ...process.env, LC_ALL: 'C' } };
  try {
    execFileSync(
      binary('initdb'),
      ['-D', data, '-U', 'exerly', '-A', 'trust', '-E', 'UTF8', '--no-locale'],
      quiet
    );
    execFileSync(
      binary('pg_ctl'),
      [
        '-D',
        data,
        '-l',
        path.join(root, 'server.log'),
        '-w',
        '-o',
        `-k ${root} -c listen_addresses= -F`,
        'start',
      ],
      quiet
    );
  } catch (error) {
    const log = fs.existsSync(path.join(root, 'server.log'))
      ? fs.readFileSync(path.join(root, 'server.log'), 'utf8')
      : '';
    fs.rmSync(root, { recursive: true, force: true });
    throw new Error(`Could not start a test PostgreSQL cluster: ${error.message}\n${log}`);
  }
  const url = `postgresql://exerly@localhost/postgres?host=${encodeURIComponent(root)}`;
  return {
    url,
    root,
    stop() {
      try {
        execFileSync(binary('pg_ctl'), ['-D', data, '-m', 'immediate', '-w', 'stop'], quiet);
      } finally {
        fs.rmSync(root, { recursive: true, force: true });
      }
    },
  };
}

module.exports = { start, binary };
