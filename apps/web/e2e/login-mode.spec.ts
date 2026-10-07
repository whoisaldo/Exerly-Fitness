import { test, expect } from '@playwright/test';
import { account, password, resetFixture } from './helpers/session';

test('switching from signup allows immediate login without an irrelevant name field', async ({
  page,
  request,
}) => {
  await resetFixture(request);
  const user = await account(request);
  await page.goto('/#/login');
  await page.getByLabel('Email address', { exact: true }).fill(user.email);
  await page.getByLabel('Password', { exact: true }).fill(password);
  await page.getByRole('button', { name: 'Login', exact: true }).first().click();
  // Submit immediately, as autofill or a fast Enter key does during the mode change.
  // Native validation must not retain signup-only requirements during an exit animation.
  await page.locator('form').evaluate((form: HTMLFormElement) => form.requestSubmit());
  await expect(page).toHaveURL(/dashboard/);
  await expect(
    page.getByRole('heading', { name: 'Welcome back, Session!', exact: true })
  ).toBeVisible();
});
