import { test, expect } from '@playwright/test';
import { randomUUID } from 'node:crypto';
import { apiURL, password, resetFixture, storedSession } from './helpers/session';

const fixtureHeaders = { 'X-Test-Fixture': 'isolated-simulator' };

if (process.env.PLAYWRIGHT_SETUP_STAGE === 'seed') {
  test('browser draft starts the simulator setup round trip', async ({
    page,
    request,
  }, testInfo) => {
    await resetFixture(request);
    const email = `setup-cross-${randomUUID()}@exerly.test`;
    const signup = await request.post(`${apiURL}/signup`, {
      data: { email, password, name: 'Browser Taylor' },
    });
    expect(signup.ok()).toBeTruthy();
    const { token } = await signup.json();
    expect(
      (
        await request.put(`${apiURL}/api/onboarding/draft`, {
          headers: { Authorization: `Bearer ${token}`, 'Idempotency-Key': randomUUID() },
          data: {
            revision: 0,
            schema_version: 2,
            last_valid_step: 0,
            answers: {
              name: 'Browser Taylor',
              age: 34,
              gender: 'nonbinary',
              sex: null,
              height: 167.5,
              weight: 72.25,
              goal: 'gain_muscle',
              nutritionGoal: 'lose',
              targetWeight: 68.5,
              activityLevel: 'light',
              targetMode: 'manual',
              manualTargets: {
                calories: 2180,
                protein_g: 133,
                carbs_g: 246,
                fat_g: 66,
                fiber_g: 27,
              },
              timezone: 'America/New_York',
              unitSystem: 'metric',
              experienceLevel: 'intermediate',
              workoutDaysPerWeek: 4,
              equipmentAccess: 'bodyweight',
              equipment: ['bodyweight', 'rings'],
              activityTypes: ['hiking', 'rowing'],
              dietaryStyle: 'mediterranean',
              allergies: ['sesame', 'nuts'],
              mealsPerDay: 4,
              sleepGoalHours: 7.25,
              bedtime: '22:45',
              wakeTime: '06:15',
              workoutDays: ['monday', 'wednesday', 'friday', 'sunday'],
              timelineWeeks: 16,
              reminders: { meals: true, workouts: false, sleep: true },
              rateKgPerWeek: -0.2,
              dietType: 'balanced',
            },
          },
        })
      ).ok()
    ).toBeTruthy();
    await page.goto('/#/login');
    await page.getByRole('button', { name: 'Login', exact: true }).first().click();
    await page.getByLabel('Email address', { exact: true }).fill(email);
    await page.getByLabel('Password', { exact: true }).fill(password);
    await page.locator('button[type="submit"]').click();
    await expect(page.getByLabel('Name', { exact: true })).toHaveValue('Browser Taylor');
    await page.getByLabel('Name', { exact: true }).fill('Browser to Native Taylor');
    await page.getByRole('button', { name: 'Continue', exact: true }).click();
    await page.getByLabel('Daily calories (kcal)', { exact: true }).fill('2310');
    await page.getByRole('button', { name: 'Continue', exact: true }).click();
    await expect(page.getByLabel('Nutrition goal', { exact: true })).toHaveValue('lose');
    await page.getByRole('button', { name: 'Continue', exact: true }).click();
    await page.getByRole('button', { name: 'Continue', exact: true }).click();
    await expect(page.getByRole('button', { name: 'Finish setup', exact: true })).toBeEnabled();
    await page.screenshot({
      path: testInfo.outputPath('setup-browser-to-native.png'),
      fullPage: true,
    });
    expect(
      (
        await request.post(`${apiURL}/__test/setup-roundtrip`, {
          headers: fixtureHeaders,
          data: { email, phase: 'browser-draft' },
        })
      ).ok()
    ).toBeTruthy();
  });
}

if (process.env.PLAYWRIGHT_SETUP_STAGE === 'finish') {
  test('browser completes the edited native setup with the same targets and preferences', async ({
    page,
    request,
  }, testInfo) => {
    await resetFixture(request);
    const fixture = await request.get(`${apiURL}/__test/setup-roundtrip`, {
      headers: fixtureHeaders,
    });
    expect(fixture.ok()).toBeTruthy();
    const { email, phase } = await fixture.json();
    expect(phase).toBe('native-draft');
    await page.goto('/#/login');
    await page.getByRole('button', { name: 'Login', exact: true }).first().click();
    await page.getByLabel('Email address', { exact: true }).fill(email);
    await page.getByLabel('Password', { exact: true }).fill(password);
    await page.locator('button[type="submit"]').click();
    await expect(page.getByRole('heading', { name: 'Review targets', exact: true })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Finish setup', exact: true })).toBeEnabled();
    await expect(page.getByRole('form')).toContainText('General health');
    await expect(page.getByRole('form')).toContainText('Gain weight');
    await page.getByText('Saved preferences', { exact: true }).click();
    await expect(page.getByText('sesame, nuts', { exact: true })).toBeVisible();
    await expect(page.getByText('bodyweight, rings', { exact: true })).toBeVisible();
    await page.screenshot({
      path: testInfo.outputPath('setup-native-to-browser.png'),
      fullPage: true,
    });
    await page.getByRole('button', { name: 'Finish setup', exact: true }).click();
    await expect(page).toHaveURL(/\/#\/dashboard$/);
    const { token } = await storedSession(page);
    const exported = await (
      await request.get(`${apiURL}/api/export`, { headers: { Authorization: `Bearer ${token}` } })
    ).json();
    expect(exported.account.profile).toMatchObject({
      goal: 'general_health',
      nutritionGoal: 'gain',
      targetWeight: 75.25,
      allergies: ['sesame', 'nuts'],
      equipment: ['bodyweight', 'rings'],
      bedtime: '22:45',
      wakeTime: '06:15',
    });
    expect(exported.weights).toHaveLength(1);
    expect(exported.weights[0].weight_kg).toBe(72.25);
    expect(exported.program).toMatchObject({
      goal_type: 'gain',
      calories: 2310,
      protein_g: 133,
      carbs_g: 246,
      fat_g: 66,
    });
    expect(
      (
        await request.post(`${apiURL}/__test/setup-roundtrip`, {
          headers: fixtureHeaders,
          data: { email, phase: 'browser-complete' },
        })
      ).ok()
    ).toBeTruthy();
  });
}
