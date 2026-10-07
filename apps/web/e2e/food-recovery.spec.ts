import { test, expect, type Page, type APIRequestContext } from '@playwright/test';
import { randomUUID } from 'node:crypto';
import { account, apiURL, login, resetFixture } from './helpers/session';
import { addDays } from '../src/lib/dates';

const headers = (token: string) => ({
  Authorization: `Bearer ${token}`,
  'Idempotency-Key': randomUUID(),
});
async function foods(request: APIRequestContext, token: string, day: string, deleted = false) {
  const response = await request.get(`${apiURL}/api/food?date=${day}&include_deleted=${deleted}`, {
    headers: headers(token),
  });
  expect(response.ok()).toBeTruthy();
  return response.json();
}
async function openDiary(page: Page, email: string) {
  await login(page, email);
  await page.goto('/#/dashboard/diary');
  await expect(page.getByRole('button', { name: 'Add', exact: true }).first()).toBeVisible();
  return page.getByLabel('Pick a date').inputValue();
}
async function quick(page: Page, name: string) {
  await page.getByRole('button', { name: 'Add', exact: true }).first().click();
  await page.getByRole('button', { name: 'Quick add', exact: true }).click();
  await page.getByRole('button', { name: 'Enter macros manually', exact: true }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByPlaceholder('What did you eat?').fill(name);
  await dialog.getByLabel('Calories / serving', { exact: true }).fill('99.5');
  return dialog;
}
async function seeded(request: APIRequestContext, token: string, day: string, name = 'Seed oats') {
  const input = {
    name,
    calories: 99.5,
    protein: 3.3333,
    sodium: 123.4567,
    saturated_fat: 0.5555,
    carbs: null,
    servings: 1.5,
    nutrition_basis: { amount: 100, unit: 'g' },
    meal_type: 'breakfast',
    entry_date: day,
    client_id: randomUUID(),
    base_revision: 0,
  };
  const response = await request.post(`${apiURL}/api/food`, {
    headers: headers(token),
    data: input,
  });
  expect(response.ok()).toBeTruthy();
  return { input, row: await response.json() };
}
test.beforeEach(async ({ request }) => resetFixture(request));

test('fractional servings and grams retain exact nutrition through editing and export', async ({
  page,
  request,
}) => {
  const user = await account(request);
  const day = await openDiary(page, user.email);
  const dialog = await quick(page, 'Precise oats');
  await dialog.getByLabel('Protein (g)', { exact: true }).fill('3.3333');
  await dialog.getByLabel('Sodium (mg)', { exact: true }).fill('123.4567');
  await dialog.getByLabel('Saturated fat (g)', { exact: true }).fill('0.5555');
  await dialog.getByLabel('Basis amount', { exact: true }).fill('100');
  await dialog.getByLabel('Basis unit', { exact: true }).selectOption('g');
  await dialog.getByLabel('Quantity', { exact: true }).fill('1 1/2');
  await expect(dialog.getByLabel('Food total')).toHaveText('149 kcal · 1.5 servings');
  await dialog.getByRole('button', { name: 'Log it', exact: true }).click();
  await expect.poll(async () => (await foods(request, user.token, day))[0]?.revision).toBe(1);
  await page.getByRole('button', { name: 'Edit Precise oats', exact: true }).click();
  await dialog.getByLabel('Quantity', { exact: true }).fill('3/4');
  await expect(dialog.getByLabel('Calories / serving', { exact: true })).toHaveValue('99.5');
  await expect(dialog.getByLabel('Food total')).toHaveText('75 kcal · 0.75 servings');
  await dialog.getByRole('button', { name: 'Save changes', exact: true }).click();
  await expect.poll(async () => (await foods(request, user.token, day))[0]?.revision).toBe(2);
  let row = (await foods(request, user.token, day))[0];
  expect(row).toMatchObject({ calories: 75, protein: 2.5, sodium: 92.59, carbs: null });
  await page.getByRole('button', { name: 'Edit Precise oats', exact: true }).click();
  await dialog.getByLabel('Quantity', { exact: true }).fill('35');
  await dialog.getByLabel('Quantity unit', { exact: true }).selectOption('g');
  await expect(dialog.getByLabel('Food total')).toHaveText('35 kcal · 0.35 servings');
  await dialog.getByRole('button', { name: 'Save changes', exact: true }).click();
  await expect.poll(async () => (await foods(request, user.token, day))[0]?.revision).toBe(3);
  row = (await foods(request, user.token, day))[0];
  expect(row).toMatchObject({
    calories: 35,
    protein: 1.17,
    sodium: 43.21,
    servings: 0.35,
    serving_unit: 'g',
    entered_quantity: { amount: 35, unit: 'g' },
    nutrition_snapshot: { calories: 99.5, protein: 3.3333, carbs: null },
  });
  const exported = await request.get(`${apiURL}/api/export`, { headers: headers(user.token) });
  expect((await exported.json()).food[0]).toMatchObject(row);
  await page.setViewportSize({ width: 390, height: 844 });
  await page.screenshot({
    path: test.info().outputPath('food-portions-phone.png'),
    fullPage: true,
  });
});

test('a lost create acknowledgement is replayed unchanged before a dependent offline edit', async ({
  page,
  request,
}) => {
  const user = await account(request);
  const day = await openDiary(page, user.email);
  const attempts: Array<{ id: string; body: string | null }> = [];
  let connected = false;
  await page.route(`${apiURL}/api/food`, async (route) => {
    if (route.request().method() !== 'POST') return route.continue();
    attempts.push({
      id: route.request().headers()['idempotency-key'],
      body: route.request().postData(),
    });
    if (attempts.length === 1) {
      const result = await route.fetch();
      expect(result.status()).toBe(201);
    }
    if (!connected) return route.abort('connectionreset');
    return route.continue();
  });
  const dialog = await quick(page, 'Recoverable food');
  await dialog.getByRole('button', { name: 'Log it', exact: true }).click();
  await expect.poll(() => attempts.length).toBe(1);
  await expect(page.getByRole('region', { name: 'Food diary' })).toContainText('waiting to sync');
  await page.getByRole('button', { name: 'Edit Recoverable food', exact: true }).click();
  await dialog.getByLabel('Quantity', { exact: true }).fill('0.75');
  await dialog.getByRole('button', { name: 'Save changes', exact: true }).click();
  await expect(dialog).toBeHidden();
  await page.reload();
  await expect(page.getByRole('region', { name: 'Food diary' })).toContainText(
    '2 food changes saved'
  );
  connected = true;
  await page.getByRole('button', { name: 'Retry food sync', exact: true }).click();
  await expect.poll(async () => (await foods(request, user.token, day))[0]?.revision).toBe(2);
  const final = await foods(request, user.token, day);
  expect(final).toHaveLength(1);
  expect(final[0]).toMatchObject({ servings: 0.75, calories: 75 });
  for (const attempt of attempts) expect(attempt).toEqual(attempts[0]);
  await expect(page.getByRole('region', { name: 'Food diary' })).toContainText('Food synced');
});

test('removed foods can be restored offline after their removal has synchronized', async ({
  page,
  request,
}) => {
  const user = await account(request);
  const day = await openDiary(page, user.email);
  const initial = await seeded(request, user.token, day, 'Undo oats');
  await page.reload();
  await page.getByRole('button', { name: 'Remove Undo oats', exact: true }).click();
  await expect.poll(async () => (await foods(request, user.token, day, true))[0]?.revision).toBe(2);
  await page.route(`${apiURL}/api/food/**`, (route) =>
    route.request().method() === 'POST' ? route.abort('failed') : route.continue()
  );
  await page.reload();
  await page.getByRole('button', { name: 'Undo removal of Undo oats', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Edit Undo oats', exact: true })).toBeVisible();
  await page.reload();
  await expect(page.getByRole('button', { name: 'Edit Undo oats', exact: true })).toBeVisible();
  await page.unroute(`${apiURL}/api/food/**`);
  await page.evaluate(() => window.dispatchEvent(new Event('online')));
  await expect.poll(async () => (await foods(request, user.token, day))[0]?.revision).toBe(3);
  const restored = (await foods(request, user.token, day))[0];
  expect(restored.id).toBe(initial.row.id);
  expect(restored.nutrition_snapshot).toEqual(initial.row.nutrition_snapshot);
});

test('a conflicting edit requires a current comparison and can explicitly restore a server deletion', async ({
  page,
  request,
}) => {
  const user = await account(request);
  const day = await openDiary(page, user.email);
  const initial = await seeded(request, user.token, day, 'Shared oats');
  await page.reload();
  await page.getByRole('button', { name: 'Edit Shared oats', exact: true }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByLabel('Quantity', { exact: true }).fill('0.75');
  expect(
    (
      await request.delete(`${apiURL}/api/food/${initial.row.id}`, {
        headers: headers(user.token),
        data: { base_revision: 1 },
      })
    ).ok()
  ).toBeTruthy();
  await dialog.getByRole('button', { name: 'Save changes', exact: true }).click();
  await page.getByRole('button', { name: 'Review food conflict', exact: true }).click();
  await expect(dialog).toContainText('Keeping your copy will restore');
  expect(
    (
      await request.post(`${apiURL}/api/food/${initial.row.id}/restore`, {
        headers: headers(user.token),
        data: { base_revision: 2 },
      })
    ).ok()
  ).toBeTruthy();
  await dialog.getByRole('button', { name: 'Keep my copy', exact: true }).click();
  await expect(dialog.getByRole('alert')).toContainText('changed again');
  await dialog.getByRole('button', { name: 'Refresh comparison', exact: true }).click();
  await expect(dialog.getByText('Keeping your copy will restore', { exact: false })).toHaveCount(0);
  await dialog.getByRole('button', { name: 'Keep my copy', exact: true }).click();
  await expect.poll(async () => (await foods(request, user.token, day))[0]?.revision).toBe(4);
  expect((await foods(request, user.token, day))[0].servings).toBe(0.75);
});

test('copy yesterday sends one recoverable batch and keeps nutrition snapshots', async ({
  page,
  request,
}) => {
  const user = await account(request);
  const day = await openDiary(page, user.email);
  const yesterday = addDays(day, -1);
  await seeded(request, user.token, yesterday, 'Yesterday oats');
  await seeded(request, user.token, yesterday, 'Yesterday milk');
  const requests: Array<{ id: string; body: string | null }> = [];
  let connected = false;
  await page.route(`${apiURL}/api/food/batch`, async (route) => {
    requests.push({
      id: route.request().headers()['idempotency-key'],
      body: route.request().postData(),
    });
    if (requests.length === 1) expect((await route.fetch()).status()).toBe(201);
    return connected ? route.continue() : route.abort('connectionreset');
  });
  await page.getByRole('button', { name: 'Copy yesterday', exact: true }).click();
  const dialog = page.getByRole('dialog');
  await expect(dialog.getByRole('checkbox')).toHaveCount(2);
  await dialog.getByLabel('Copy to meal', { exact: true }).selectOption('lunch');
  await dialog.getByRole('button', { name: 'Copy 2 foods', exact: true }).click();
  await expect.poll(async () => (await foods(request, user.token, day)).length).toBe(2);
  const beforeReload = requests.length;
  await page.reload();
  await expect.poll(() => requests.length).toBeGreaterThan(beforeReload);
  await expect(page.getByRole('region', { name: 'Food diary' }).getByRole('alert')).toContainText(
    'Could not connect'
  );
  connected = true;
  await page.getByRole('button', { name: 'Retry food sync', exact: true }).click();
  await expect(page.getByRole('region', { name: 'Food diary' })).toContainText('Food synced');
  const final = await foods(request, user.token, day);
  expect(final).toHaveLength(2);
  for (const row of final)
    expect(row).toMatchObject({
      calories: 149,
      servings: 1.5,
      meal_type: 'lunch',
      nutrition_snapshot: { calories: 99.5, protein: 3.3333 },
    });
  for (const attempt of requests) expect(attempt).toEqual(requests[0]);
});

test('an unfinished invalid food draft survives reload and stays isolated from another account', async ({
  page,
  request,
}) => {
  const user = await account(request);
  const other = await account(request);
  await openDiary(page, user.email);
  const dialog = await quick(page, 'Private draft');
  await dialog.getByLabel('Quantity', { exact: true }).fill('1/');
  await expect(dialog.getByRole('status')).toHaveText('Draft saved on this browser');
  await page.reload();
  await page.getByRole('button', { name: 'Resume draft', exact: true }).click();
  await expect(dialog.getByLabel('Quantity', { exact: true })).toHaveValue('1/');
  await dialog.getByRole('button', { name: 'Log it', exact: true }).click();
  await expect(dialog.getByRole('alert')).toContainText('number or fraction');
  await dialog.getByRole('button', { name: 'Close', exact: true }).click();
  await page.getByRole('button', { name: 'Sign out', exact: true }).click();
  await openDiary(page, other.email);
  await expect(page.getByText('Private draft', { exact: false })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Resume draft', exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: 'Sign out', exact: true }).click();
  await openDiary(page, user.email);
  await page.getByRole('button', { name: 'Resume draft', exact: true }).click();
  await expect(dialog.getByPlaceholder('What did you eat?')).toHaveValue('Private draft');
  await expect(dialog.getByLabel('Quantity', { exact: true })).toHaveValue('1/');
});

test('a late food acknowledgement stays with its original account after sign-out', async ({
  page,
  request,
}) => {
  const first = await account(request);
  const second = await account(request);
  const day = await openDiary(page, first.email);
  let release!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  let committed = false;
  let calls = 0;
  await page.route(`${apiURL}/api/food`, async (route) => {
    if (route.request().method() !== 'POST') return route.continue();
    calls++;
    const response = await route.fetch();
    expect(response.status()).toBe(201);
    committed = true;
    await gate;
    await route.fulfill({ response });
  });
  const dialog = await quick(page, 'Original account food');
  await dialog.getByRole('button', { name: 'Log it', exact: true }).click();
  await expect(dialog).toBeHidden();
  await expect.poll(() => committed).toBeTruthy();
  await page.getByRole('button', { name: 'Sign out', exact: true }).click();
  await openDiary(page, second.email);
  release();
  await expect(page.getByText('Original account food', { exact: true })).toHaveCount(0);
  expect(await foods(request, second.token, day)).toHaveLength(0);
  await page.getByRole('button', { name: 'Sign out', exact: true }).click();
  await openDiary(page, first.email);
  await expect(
    page.getByRole('button', { name: 'Edit Original account food', exact: true })
  ).toHaveCount(1);
  await expect(page.getByRole('region', { name: 'Food diary' })).toContainText('Food synced');
  expect(calls).toBe(1);
  expect(await foods(request, first.token, day)).toHaveLength(1);
});

test('two tabs keep independent drafts and review a stale food edit before discarding it', async ({
  page,
  context,
  request,
}) => {
  const user = await account(request);
  const day = await openDiary(page, user.email);
  await seeded(request, user.token, day, 'Two-tab oats');
  await page.reload();
  const other = await context.newPage();
  await other.goto(page.url());
  await page.getByRole('button', { name: 'Edit Two-tab oats', exact: true }).click();
  await other.getByRole('button', { name: 'Edit Two-tab oats', exact: true }).click();
  await page.getByRole('dialog').getByLabel('Quantity', { exact: true }).fill('0.75');
  await other.getByRole('dialog').getByLabel('Quantity', { exact: true }).fill('1.25');
  await page.getByRole('dialog').getByRole('button', { name: 'Save changes', exact: true }).click();
  await expect.poll(async () => (await foods(request, user.token, day))[0]?.revision).toBe(2);
  await other
    .getByRole('dialog')
    .getByRole('button', { name: 'Save changes', exact: true })
    .click();
  await other.getByRole('button', { name: 'Review food conflict', exact: true }).click();
  await expect(other.getByRole('dialog')).toContainText('1.25');
  await expect(other.getByRole('dialog')).toContainText('0.75');
  await other.getByRole('button', { name: 'Keep server copy', exact: true }).click();
  await expect(other.getByRole('dialog')).toBeHidden();
  await expect(page.getByRole('region', { name: 'Food diary' })).toContainText('Food synced');
  expect((await foods(request, user.token, day))[0]).toMatchObject({ revision: 2, servings: 0.75 });
  await other.close();
});

test('an unreadable food store is preserved and cannot be overwritten by background refresh', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await openDiary(page, user.email);
  const dialog = await quick(page, 'Preserve this draft');
  await expect(dialog.getByRole('status')).toHaveText('Draft saved on this browser');
  await dialog.getByRole('button', { name: 'Close', exact: true }).click();
  const original = await page.evaluate(
    async () =>
      new Promise<string>((resolve, reject) => {
        const opening = indexedDB.open('exerly-food-v1', 1);
        opening.onerror = () => reject(opening.error);
        opening.onsuccess = () => {
          const db = opening.result;
          const tx = db.transaction('accounts', 'readwrite');
          const cursor = tx.objectStore('accounts').openCursor();
          let encoded = '';
          cursor.onsuccess = () => {
            const row = cursor.result!;
            const value = { ...row.value, version: 999, preserve: 'future-store' };
            encoded = JSON.stringify(value);
            row.update(value);
          };
          tx.oncomplete = () => {
            db.close();
            resolve(encoded);
          };
          tx.onerror = () => reject(tx.error);
        };
      })
  );
  await page.reload();
  await expect(page.getByRole('alert')).toContainText('Saved food data could not be read');
  await expect(page.getByRole('button', { name: 'Add', exact: true })).toHaveCount(0);
  const preserved = await page.evaluate(
    async () =>
      new Promise<string>((resolve) => {
        const opening = indexedDB.open('exerly-food-v1', 1);
        opening.onsuccess = () => {
          const db = opening.result;
          const request = db.transaction('accounts').objectStore('accounts').getAll();
          request.onsuccess = () => {
            db.close();
            resolve(JSON.stringify(request.result[0]));
          };
        };
      })
  );
  expect(preserved).toBe(original);
});

test('a rejected queued food can be corrected without altering or replaying its failed payload', async ({
  page,
  request,
}) => {
  const user = await account(request);
  const day = await openDiary(page, user.email);
  const attempts: Array<{ id: string; body: Record<string, unknown> }> = [];
  await page.route(`${apiURL}/api/food`, async (route) => {
    if (route.request().method() !== 'POST') return route.continue();
    attempts.push({
      id: route.request().headers()['idempotency-key'],
      body: route.request().postDataJSON(),
    });
    if (attempts.length === 1)
      return route.fulfill({ status: 400, json: { message: 'Cannot log to a future date' } });
    return route.continue();
  });
  const dialog = await quick(page, 'Correctable oats');
  await dialog.getByRole('button', { name: 'Log it', exact: true }).click();
  await page.getByRole('button', { name: 'Correct queued food', exact: true }).click();
  await dialog.getByLabel('Food date', { exact: true }).fill(addDays(day, -1));
  await dialog.getByLabel('Quantity', { exact: true }).fill('0.75');
  await dialog.getByRole('button', { name: 'Log it', exact: true }).click();
  await expect(dialog).toBeHidden();
  await expect(page.getByRole('region', { name: 'Food diary' })).toContainText('Food synced');
  expect(attempts).toHaveLength(2);
  expect(attempts[0].id).not.toBe(attempts[1].id);
  expect(attempts[1].body.client_id).toBe(attempts[0].body.client_id);
  expect(await foods(request, user.token, day)).toHaveLength(0);
  const final = await foods(request, user.token, addDays(day, -1));
  expect(final).toHaveLength(1);
  expect(final[0]).toMatchObject({ servings: 0.75, calories: 75 });
});

test('a food moves between dates and meals without losing its identity or exact portion', async ({
  page,
  request,
}) => {
  const user = await account(request);
  const day = await openDiary(page, user.email);
  const initial = await seeded(request, user.token, day, 'Move oats');
  await page.reload();
  await page.getByRole('button', { name: 'Edit Move oats', exact: true }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByLabel('Food date', { exact: true }).fill(addDays(day, -1));
  await dialog.getByRole('combobox', { name: 'Meal', exact: true }).selectOption('dinner');
  await dialog.getByLabel('Quantity', { exact: true }).fill('35');
  await dialog.getByRole('combobox', { name: 'Quantity unit', exact: true }).selectOption('g');
  await dialog.getByRole('button', { name: 'Save changes', exact: true }).click();
  await expect(dialog).toBeHidden();
  await expect.poll(async () => (await foods(request, user.token, day)).length).toBe(0);
  await expect(page.getByRole('button', { name: 'Edit Move oats', exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: 'Previous day', exact: true }).click();
  await page.getByRole('button', { name: 'Edit Move oats', exact: true }).click();
  await expect(dialog.getByLabel('Quantity', { exact: true })).toHaveValue('35');
  await expect(dialog.getByRole('combobox', { name: 'Quantity unit', exact: true })).toHaveValue(
    'g'
  );
  await expect(dialog.getByRole('combobox', { name: 'Meal', exact: true })).toHaveValue('dinner');
  const final = (await foods(request, user.token, addDays(day, -1)))[0];
  expect(final.id).toBe(initial.row.id);
  expect(final.nutrition_snapshot).toEqual(initial.row.nutrition_snapshot);
});

test('a storage failure while saving the acknowledgement leaves the original food operation recoverable', async ({
  page,
  request,
}) => {
  const user = await account(request);
  const day = await openDiary(page, user.email);
  const attempts: Array<{ id: string; body: string | null }> = [];
  await page.route(`${apiURL}/api/food`, async (route) => {
    if (route.request().method() !== 'POST') return route.continue();
    attempts.push({
      id: route.request().headers()['idempotency-key'],
      body: route.request().postData(),
    });
    const response = await route.fetch();
    expect(response.status()).toBe(201);
    if (attempts.length === 1) {
      await page.evaluate(() => {
        const put = IDBObjectStore.prototype.put;
        IDBObjectStore.prototype.put = function (value, ...rest) {
          if (this.name === 'accounts' && Object.keys(value.receipts ?? {}).length)
            throw new DOMException('Receipt storage full', 'QuotaExceededError');
          return put.call(this, value, ...rest);
        };
      });
    }
    return route.fulfill({ response });
  });
  const dialog = await quick(page, 'Durable receipt oats');
  await dialog.getByRole('button', { name: 'Log it', exact: true }).click();
  await expect(dialog).toBeHidden();
  await expect(page.getByRole('region', { name: 'Food diary' }).getByRole('alert')).toContainText(
    'Receipt storage full'
  );
  expect(await foods(request, user.token, day)).toHaveLength(1);
  await page.reload();
  await expect(page.getByRole('region', { name: 'Food diary' })).toContainText('Food synced');
  expect(attempts).toHaveLength(2);
  expect(attempts[1]).toEqual(attempts[0]);
  expect(await foods(request, user.token, day)).toHaveLength(1);
});

test('portion calculations reject unbounded fractions and match native rounding at decimal boundaries', async () => {
  const { quantity, servingsFor, snapshot } = await import('../src/lib/food');
  expect(() => quantity(`${'9'.repeat(400)}/${'9'.repeat(400)}`)).toThrow('number or fraction');
  expect(() => servingsFor(35, 'ml', { amount: 100, unit: 'g' })).toThrow('weight or volume');
  expect(servingsFor(1, 'oz', { amount: 100, unit: 'g' })).toBeCloseTo(0.28349523125, 10);
  const food = snapshot(
    {
      name: 'Boundary',
      brand: null,
      barcode: null,
      source: 'custom',
      servings: 1,
      serving_size: null,
      nutrition_basis: null,
      meal_type: null,
      entry_date: '2026-09-22',
      calories: 100.5,
      protein: 2.675,
      carbs: 1.125,
      fat: null,
      fiber: null,
      sugar: null,
      sodium: null,
      saturated_fat: null,
    },
    randomUUID()
  );
  expect(food).toMatchObject({ calories: 101, protein: 2.68, carbs: 1.13, fat: null });
  expect(food.nutrition_snapshot?.protein).toBe(2.675);
});

test('adopting a legacy food identity does not duplicate its row or totals after acknowledgement', async ({
  page,
  request,
}) => {
  const user = await account(request);
  const day = await openDiary(page, user.email);
  await seeded(request, user.token, day, 'Legacy oats');
  // Model a migrated record whose original read did not yet have a client UUID.
  let legacy = true;
  await page.route(`${apiURL}/api/summary?*`, async (route) => {
    const response = await route.fetch();
    const body = await response.json();
    if (legacy)
      for (const meal of Object.values(body.meals) as Array<{
        entries: Array<{ client_id?: string }>;
      }>)
        for (const row of meal.entries) delete row.client_id;
    return route.fulfill({ response, json: body });
  });
  await page.route(`${apiURL}/api/food?*`, async (route) => {
    const response = await route.fetch();
    const rows = await response.json();
    if (legacy) for (const row of rows) delete row.client_id;
    return route.fulfill({ response, json: rows });
  });
  await page.route(`${apiURL}/api/food/*`, async (route) => {
    if (route.request().method() !== 'PUT') return route.continue();
    const response = await route.fetch();
    legacy = false;
    return route.fulfill({ response });
  });
  await page.reload();
  await page.getByRole('button', { name: 'Edit Legacy oats', exact: true }).click();
  await page.getByRole('dialog').getByLabel('Quantity', { exact: true }).fill('0.75');
  await page.getByRole('dialog').getByRole('button', { name: 'Save changes', exact: true }).click();
  await expect.poll(async () => (await foods(request, user.token, day))[0]?.revision).toBe(2);
  await expect(page.getByRole('region', { name: 'Food diary' })).toContainText('Food synced');
  await page.reload();
  await expect(page.getByRole('button', { name: 'Edit Legacy oats', exact: true })).toHaveCount(1);
  await expect(page.getByRole('region', { name: 'Food diary' })).toContainText('75 kcal');
  expect(await foods(request, user.token, day)).toHaveLength(1);
});
