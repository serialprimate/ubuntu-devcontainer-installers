// Qualify local storage, both browser modes and a real embedded CLI session as the development user.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');

const [storage, expectation] = process.argv.slice(2);
assert(['separate', 'package'].includes(storage));
assert.notEqual(process.getuid(), 0, 'qualification must run as the development user');
const root = __dirname;
const wrapper = path.join(root, 'project-playwright.cjs');
const cli = path.join(path.dirname(require.resolve('@playwright/test/package.json')), 'cli.js');
const core = path.dirname(require.resolve('playwright-core/package.json'));
const browserRoot = storage === 'package' ? path.join(core, '.local-browsers') : path.join(root, 'ms-playwright');
assert.equal(require('playwright/package.json').version, '1.64.0');
assert.equal(require('@playwright/test/package.json').version, '1.64.0');
assert.equal(spawnSync('/bin/bash', ['-c', 'if command -v playwright >/dev/null; then exit 0; else exit 1; fi'], { encoding: 'utf8' }).status, 1,
    'a global Playwright command would invalidate local-resolution evidence');
const dpkgBefore = crypto.createHash('sha256').update(fs.readFileSync('/var/lib/dpkg/status')).digest('hex');
const globalRoot = spawnSync('npm', ['root', '--global'], { encoding: 'utf8' });
assert.equal(globalRoot.status, 0);
for (const name of ['playwright', 'playwright-core', '@playwright/test', '@playwright/cli']) {
    assert(!fs.existsSync(path.join(globalRoot.stdout.trim(), name)), `unexpected global package: ${name}`);
}

const env = { ...process.env, DEBUG: 'pw:browser', CI: '1', NO_UPDATE_NOTIFIER: '1' };
const logRoot = path.join(root, '.qualification');
fs.mkdirSync(logRoot, { recursive: true });
function run(name, args, options = {}) {
    const result = spawnSync(process.execPath, args, {
        cwd: root, env, encoding: 'utf8', timeout: 90000, maxBuffer: 10 * 1024 * 1024, ...options,
    });
    const output = (result.stdout || '') + (result.stderr || '');
    fs.writeFileSync(path.join(logRoot, `${name}.log`), output);
    return { ...result, output };
}
function succeed(name, args) {
    const result = run(name, [wrapper, storage, ...args]);
    assert.equal(result.status, 0, `${name}: ${result.error || ''}\n${result.output}`);
    return result.output;
}
function missing(name, args, options) {
    const result = run(name, args, options);
    assert.notEqual(result.status, 0, `${name} unexpectedly succeeded`);
    assert.match(result.output, /Executable doesn't exist/, result.output);
}

if (expectation === 'missing') {
    assert(!fs.existsSync(browserRoot));
    missing('missing-browsers', [wrapper, storage, 'test', '--project=chromium-new-headless']);
    assert(!fs.existsSync(browserRoot), 'a test run must not download missing browsers');
    console.log(`PASS ${storage}: missing browsers require the explicit installation step`);
} else {
    // Check every browser/package file, not just user-owned directories around root-owned executables.
    const owned = [browserRoot, path.join(root, 'node_modules')];
    while (owned.length) {
        const file = owned.pop();
        const stat = fs.lstatSync(file);
        assert.equal(stat.uid, process.getuid(), file);
        if (stat.isDirectory()) owned.push(...fs.readdirSync(file).map(entry => path.join(file, entry)));
    }
    for (const entry of fs.readdirSync(browserRoot)) {
        assert(!/^(firefox|webkit)-/.test(entry), 'only approved Chromium browsers may be downloaded');
    }
    const tests = succeed('browser-tests', ['test']);
    assert.match(tests, /4 passed/, tests);
    assert.match(tests, /<launching> .*\/chromium-\d+\/.* --headless/, tests);
    assert.match(tests, /<launching> .*\/chromium_headless_shell-\d+\/.* --headless/, tests);
    console.log(tests.split('\n').filter(line => line.includes('<launching>')).join('\n'));

    // The CLI starts a daemon; its supported browser diagnostics are written to its error log.
    const session = '-s=qualification';
    try {
        succeed('cli-open', ['cli', session, 'open', 'about:blank', '--config=playwright-cli.config.json']);
        const interact = async page => {
            await page.setContent('<button onclick="this.textContent = \'Done\'">Run</button>');
            await page.getByRole('button').click();
            return await page.getByRole('button').textContent();
        };
        const output = succeed('cli-interact', ['cli', session, 'run-code', interact.toString()]);
        assert.match(output, /(?:^|\n)### Result\n"Done"(?:\n|$)/, output);
        assert(!output.includes('### Error'), output);
        const daemonRoot = path.join(process.env.XDG_CACHE_HOME, 'ms-playwright', 'daemon');
        const logs = fs.readdirSync(daemonRoot, { recursive: true })
            .filter(file => file.endsWith('qualification.err'))
            .map(file => fs.readFileSync(path.join(daemonRoot, file), 'utf8')).join('\n');
        fs.writeFileSync(path.join(logRoot, 'cli-browser.log'), logs);
        assert.match(logs, /<launching> .*\/chromium-\d+\/.* --headless/, logs);
        assert(!logs.includes('/chromium_headless_shell-'), logs);
        console.log(logs.split('\n').filter(line => line.includes('<launching>')).join('\n'));
    } finally {
        succeed('cli-close', ['cli', session, 'close']);
    }

    // A wrong path must fail rather than fetch a browser or select an unrelated system browser.
    const absent = path.join(root, 'absent-browsers');
    missing('path-mismatch', [cli, 'test', '--project=chromium-new-headless'], {
        env: { ...env, PLAYWRIGHT_BROWSERS_PATH: absent },
    });
    assert(!fs.existsSync(absent));
    console.log(`PASS ${storage}: non-root browsers, both headless variants, embedded CLI and path failure`);
}
const dpkgAfter = crypto.createHash('sha256').update(fs.readFileSync('/var/lib/dpkg/status')).digest('hex');
assert.equal(dpkgAfter, dpkgBefore, 'project verification must not change Ubuntu package state');
