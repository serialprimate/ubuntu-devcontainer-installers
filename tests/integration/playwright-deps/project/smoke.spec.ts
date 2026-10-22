// Exercise Playwright's built-in TypeScript transform without adding a type-checker dependency.
import { test, expect } from '@playwright/test';

test('TypeScript test renders and interacts as non-root', async ({ page }) => {
    const expected: string = 'Done';
    expect(process.getuid!()).not.toBe(0);
    await page.setContent('<button onclick="this.textContent = \'Done\'">Run</button>');
    await page.getByRole('button').click();
    await expect(page.getByRole('button')).toHaveText(expected);
});
