import { test, expect } from '@playwright/test';
import { apiURL, login, resetFixture, storedSession } from './helpers/session';

if (process.env.PLAYWRIGHT_NATIVE_ACCOUNT === '1') {
  test('browser reads native preferences and sends revised preferences back to the simulator', async ({
    page,
    request,
  }, testInfo) => {
    await resetFixture(request);
    const headers = { 'X-Test-Fixture': 'isolated-simulator' };
    const fixture = await request.get(`${apiURL}/__test/preferences-roundtrip`, { headers });
    expect(fixture.ok()).toBeTruthy();
    const { email, phase } = await fixture.json();
    expect(phase).toBe('native-saved');
    await login(page, email);
    await page.goto('/#/dashboard/profile');
    await expect(page.getByLabel('Name', { exact: true })).toHaveValue('Native Reviewed Taylor');
    await expect(page.getByLabel('Sleep goal (hours)', { exact: true })).toHaveValue('8.25');
    await expect(page.getByLabel('Diet preference', { exact: true })).toHaveValue('Pescatarian');
    await expect(page.getByLabel('Height (cm)', { exact: true })).toHaveValue('167.75');
    await expect(page.getByLabel('Allergies', { exact: true })).toHaveValue('sesame\nnuts');
    await expect(page.getByLabel('Available equipment', { exact: true })).toHaveValue('rings');
    await expect(page.getByLabel('Training experience', { exact: true })).toHaveValue('advanced');
    await page.getByLabel('Name', { exact: true }).fill('Browser Preference Taylor');
    await page.getByLabel('Sleep goal (hours)', { exact: true }).fill('7.75');
    await page.getByLabel('Preferred bedtime', { exact: true }).fill('22:15');
    await page.getByLabel('Sleep reminders', { exact: true }).check();
    await page.getByLabel('Sleep reminder time', { exact: true }).fill('22:00');
    await page.getByLabel('Workout reminder time', { exact: true }).fill('17:30');
    await page.getByRole('button', { name: 'Save preferences', exact: true }).click();
    await expect(page.getByRole('status').filter({ hasText: 'Preferences saved.' })).toBeVisible();
    await page.screenshot({
      path: testInfo.outputPath('preferences-native-to-browser.png'),
      fullPage: true,
    });
    const { token } = await storedSession(page);
    const exported = await (
      await request.get(`${apiURL}/api/export`, { headers: { Authorization: `Bearer ${token}` } })
    ).json();
    expect(exported.weights).toHaveLength(1);
    expect(exported.weights[0].weight_kg).toBe(72.25);
    expect(exported.account.profile).toMatchObject({
      allergies: ['sesame', 'nuts'],
      equipment: ['rings'],
      sleepGoalHours: 7.75,
      bedtime: '22:15',
      reminders: { sleep: true },
      reminderTimes: { sleep: '22:00', workout: '17:30' },
    });
    expect(
      (
        await request.post(`${apiURL}/__test/preferences-roundtrip`, {
          headers,
          data: { email, phase: 'browser-saved' },
        })
      ).ok()
    ).toBeTruthy();
  });
}
