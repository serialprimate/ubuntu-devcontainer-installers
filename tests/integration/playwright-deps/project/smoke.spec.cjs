// Use in-memory HTML so browser qualification needs no website, web framework or display server.
const { test, expect } = require('@playwright/test');

test('non-root browser renders and interacts', async ({ page }) => {
    expect(process.getuid()).not.toBe(0);
    await page.setContent('<button onclick="this.textContent = \'Done\'">Run</button>');
    const button = page.getByRole('button');
    await expect(button).toHaveText('Run');
    await button.click();
    await expect(button).toHaveText('Done');
});
