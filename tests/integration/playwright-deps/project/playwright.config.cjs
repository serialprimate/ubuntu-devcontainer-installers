// Exercise the two Chromium executable paths without inheriting a channel into Headless Shell.
module.exports = {
    testMatch: ['smoke.spec.cjs', 'smoke.spec.ts'],
    workers: 1,
    retries: 0,
    timeout: 15000,
    reporter: 'line',
    use: { browserName: 'chromium', headless: true },
    projects: [
        { name: 'chromium-new-headless', use: { channel: 'chromium' } },
        { name: 'chromium-headless-shell' },
    ],
};
