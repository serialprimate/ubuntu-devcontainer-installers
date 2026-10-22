// Resolve project-local packages and browser storage independently of the caller's directory.
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const [storage, ...args] = process.argv.slice(2);
if (!['separate', 'package'].includes(storage) || args.length === 0) {
    console.error('Usage: node project-playwright.cjs <separate|package> <playwright arguments...>');
    process.exit(1);
}
const cli = path.join(path.dirname(require.resolve('@playwright/test/package.json')), 'cli.js');
const result = spawnSync(process.execPath, [cli, ...args], {
    cwd: __dirname,
    stdio: 'inherit',
    env: {
        ...process.env,
        PLAYWRIGHT_BROWSERS_PATH: storage === 'package' ? '0' : path.join(__dirname, 'ms-playwright'),
    },
});
if (result.error) console.error(result.error.message);
process.exit(result.status ?? 1);
