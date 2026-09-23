import { test, expect, type APIRequestContext } from '@playwright/test';
import { account, apiURL, login, resetFixture } from './helpers/session';
import { addDays, daysBetween, friendlyDate, isCalendarDay, todayString } from '../src/lib/dates';

async function changeZone(request: APIRequestContext, token: string, timezone: string) {
  const response = await request.put(`${apiURL}/api/settings`, {
    headers: { Authorization: `Bearer ${token}` },
    data: { timezone },
  });
  expect(response.ok()).toBeTruthy();
  const summary = await request.get(`${apiURL}/api/summary`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  expect(summary.ok()).toBeTruthy();
  return (await summary.json()).date as string;
}

test.beforeEach(async ({ request }) => resetFixture(request));

for (const [accountZone, browserZone] of [
  ['Etc/GMT+12', 'Pacific/Kiritimati'],
  ['Pacific/Kiritimati', 'Etc/GMT+12'],
]) {
  test.describe(`Account ${accountZone}, browser ${browserZone}`, () => {
    test.use({ timezoneId: browserZone, viewport: { width: 390, height: 844 } });
    test('Today and every logging form use the account calendar', async ({ page, request }) => {
      const user = await account(request);
      const today = await changeZone(request, user.token, accountZone);
      await login(page, user.email);
      await page.goto('/#/dashboard/diary');
      await expect(page.getByLabel('Pick a date')).toHaveValue(today);
      await expect(page.getByLabel('Pick a date')).toHaveAttribute('max', today);
      await expect(page.getByRole('button', { name: 'Next day', exact: true })).toBeDisabled();
      const water = page.getByRole('form', { name: 'Water logging' });
      await water.getByRole('button', { name: '+250 ml', exact: true }).click();
      await expect(water.getByLabel('Recorded water')).toHaveText('250 ml recorded');
      await page.screenshot({
        path: test.info().outputPath('account-calendar-water.png'),
        fullPage: true,
      });
      const exported = await request.get(`${apiURL}/api/export`, {
        headers: { Authorization: `Bearer ${user.token}` },
      });
      expect((await exported.json()).water).toEqual(
        expect.arrayContaining([expect.objectContaining({ entry_date: today, ml: 250 })])
      );
      const previous = addDays(today, -1);
      await page.getByRole('button', { name: 'Previous day', exact: true }).click();
      await expect(page.getByLabel('Pick a date')).toHaveValue(previous);
      await page
        .getByRole('link', { name: 'Activity Log movement for this day', exact: true })
        .click();
      await page.getByRole('button', { name: 'Log activity', exact: true }).click();
      await expect(page.getByLabel('Activity date', { exact: true })).toHaveValue(previous);
      await expect(page.getByLabel('Activity date', { exact: true })).toHaveAttribute('max', today);
      await page.goto('/#/dashboard/sleep');
      await page.getByRole('button', { name: 'Log sleep', exact: true }).click();
      await expect(page.getByLabel('Wake date', { exact: true })).toHaveValue(today);
      await expect(page.getByLabel('Wake date', { exact: true })).toHaveAttribute('max', today);
      await page.goto('/#/dashboard/weight');
      await expect(page.getByLabel('Pick a date')).toHaveValue(today);
      await expect(page.getByLabel('Measurement date', { exact: true })).toHaveValue(today);
      await expect(page.getByLabel('Measurement date', { exact: true })).toHaveAttribute(
        'max',
        today
      );
      const other = await account(request);
      const otherDay = await changeZone(request, other.token, browserZone);
      expect(otherDay).not.toBe(today);
      await page.getByRole('button', { name: 'Sign out', exact: true }).click();
      await login(page, other.email);
      await page.goto('/#/dashboard/diary');
      await expect(page.getByLabel('Pick a date')).toHaveValue(otherDay);
    });
  });
}

test('a timezone change preserves an explicitly selected day and its unsent water operation', async ({
  page,
  request,
}) => {
  const user = await account(request);
  const originalDay = await changeZone(request, user.token, 'Pacific/Kiritimati');
  await login(page, user.email);
  await page.goto('/#/dashboard/diary');
  const attempts: { id: string; body: string | null }[] = [];
  await page.route('**/api/water', async (route) => {
    if (route.request().method() !== 'POST') return route.continue();
    attempts.push({
      id: route.request().headers()['idempotency-key'],
      body: route.request().postData(),
    });
    if (attempts.length === 1) return route.abort('connectionreset');
    return route.continue();
  });
  const water = page.getByRole('form', { name: 'Water logging' });
  await water.getByRole('button', { name: '+250 ml', exact: true }).click();
  await expect(water.getByRole('status')).toContainText('250 ml waiting for confirmation');
  const shiftedToday = await changeZone(request, user.token, 'Etc/GMT+12');
  expect(shiftedToday < originalDay).toBeTruthy();
  await page.reload();
  await expect(page.getByLabel('Pick a date')).toHaveValue(originalDay);
  await expect(water.getByRole('status')).toContainText('250 ml waiting for confirmation');
  await expect(water.getByRole('button', { name: '+250 ml', exact: true })).toBeDisabled();
  await expect(
    page.getByText('Saved changes keep their original date.', { exact: false })
  ).toBeVisible();
  await water.getByRole('button', { name: 'Retry pending additions', exact: true }).click();
  await expect(water.getByRole('alert')).toContainText('Cannot log to a future date');
  expect(attempts[1]).toEqual(attempts[0]);
  await changeZone(request, user.token, 'Pacific/Kiritimati');
  await page.reload();
  await water.getByRole('button', { name: 'Retry pending additions', exact: true }).click();
  await expect(water.getByLabel('Recorded water')).toHaveText('250 ml recorded');
  await expect(water.getByRole('status')).toHaveText('Synced');
  expect(attempts).toHaveLength(3);
  expect(attempts[2]).toEqual(attempts[0]);
});

test('an open food flow keeps its calendar day when the account passes midnight', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await page.clock.install({ time: new Date('2026-03-08T04:59:45Z') });
  await login(page, user.email);
  await page.goto('/#/dashboard/diary');
  await expect(page.getByLabel('Pick a date')).toHaveValue('2026-03-07');
  await page.getByRole('button', { name: 'Add', exact: true }).first().click();
  await page.getByRole('button', { name: 'Quick add', exact: true }).click();
  await page.getByRole('button', { name: 'Enter macros manually', exact: true }).click();
  await page.getByPlaceholder('What did you eat?').fill('Midnight oats');
  await page.getByLabel('Calories / serving', { exact: true }).fill('220');
  await page.clock.fastForward(60_000);
  await expect(page.getByLabel('Pick a date')).toHaveAttribute('max', '2026-03-08');
  await expect(page.getByLabel('Pick a date')).toHaveValue('2026-03-07');
  const write = page.waitForRequest(
    (req) => req.url().endsWith('/api/food') && req.method() === 'POST'
  );
  await page.getByRole('button', { name: 'Log it', exact: true }).click();
  expect((await write).postDataJSON().entry_date).toBe('2026-03-07');
  await expect(page.getByText('Midnight oats', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Today', exact: true }).click();
  await expect(page.getByLabel('Pick a date')).toHaveValue('2026-03-08');
});

test('calendar days stay Gregorian across leap days, year changes, DST and skipped local dates', () => {
  expect(addDays('2024-02-28', 1)).toBe('2024-02-29');
  expect(addDays('2024-02-29', 1)).toBe('2024-03-01');
  expect(addDays('2025-12-31', 1)).toBe('2026-01-01');
  for (const invalid of ['2025-02-29', '2026-02-30', '2026-13-01', '2026-01-01T00:00:00Z']) {
    expect(isCalendarDay(invalid)).toBe(false);
    expect(() => addDays(invalid, 1)).toThrow();
  }
  expect(() => addDays('2026-01-01', 0.5)).toThrow();
  expect(daysBetween('2026-03-07', '2026-03-09')).toBe(2);
  expect(daysBetween('2026-10-31', '2026-11-02')).toBe(2);
  for (const instant of ['2026-03-08T06:59:59Z', '2026-03-08T07:00:00Z'])
    expect(todayString('America/New_York', new Date(instant))).toBe('2026-03-08');
  for (const instant of ['2026-11-01T05:59:59Z', '2026-11-01T06:00:00Z'])
    expect(todayString('America/New_York', new Date(instant))).toBe('2026-11-01');
  expect(todayString('Pacific/Apia', new Date('2011-12-30T09:59:59Z'))).toBe('2011-12-29');
  expect(todayString('Pacific/Apia', new Date('2011-12-30T10:00:00Z'))).toBe('2011-12-31');
  expect(addDays('2011-12-29', 1)).toBe('2011-12-30');
  expect(todayString('not-a-zone', new Date('2026-01-01T00:00:00Z'))).toBe('2026-01-01');
  expect(friendlyDate('2025-12-31', '2026-01-01')).toBe('Yesterday');
});
