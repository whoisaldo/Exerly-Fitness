import API_CONFIG from '../config';
import { api, ApiError, getSessionScope } from './api';
import { operationID } from './ids';
import { isCalendarDay } from './dates';
import {
  normalizeFood,
  newFoodDraft,
  perServing,
  snapshot,
  type FoodDraft,
  type FoodEntry,
  type FoodInput,
} from './food';

const DATABASE = 'exerly-food-v1';
const STORE = 'accounts';
const CHANGED = 'exerly-food-changed';
export const FOOD_SYNCED = 'exerly-food-synced';
export interface FoodOwner {
  account: string;
  scope: string;
}
interface Wire {
  method: 'POST' | 'PUT' | 'DELETE';
  path: string;
  body: Record<string, unknown>;
}
export interface FoodOperation {
  id: string;
  kind: 'save' | 'delete' | 'restore' | 'batch';
  entity: string;
  serverID: string;
  base: number | null;
  after?: string;
  input?: FoodInput;
  copies: FoodEntry[];
  wire?: Wire;
  error?: string;
  attention?: boolean;
  status?: number;
  conflict?: FoodEntry;
}
export interface FoodDocument {
  version: 1;
  account: string;
  entries: Record<string, FoodEntry>;
  operations: FoodOperation[];
  drafts: Record<string, FoodDraft>;
  days: Record<string, number>;
  receipts: Record<string, FoodEntry[]>;
}
const keyFor = (account: string) => `${API_CONFIG.BASE_URL.replace(/\/+$/, '')}\n${account}`;
const failedStorage = () =>
  new Error(
    'Food changes could not be saved on this browser. Your existing copies are preserved. Allow site storage or free some space, then retry.'
  );
const unreadable = () =>
  new Error(
    'Saved food data could not be read. The original copy is still stored in this browser.'
  );
const message = (error: unknown) =>
  error instanceof Error
    ? error.message
    : 'Could not sync food. Your saved changes are still here.';
let opening: Promise<IDBDatabase> | null = null;
const channel = typeof BroadcastChannel === 'undefined' ? null : new BroadcastChannel(CHANGED);
channel?.addEventListener('message', (event) =>
  window.dispatchEvent(new CustomEvent(CHANGED, { detail: event.data }))
);
function notify(account: string) {
  window.dispatchEvent(new CustomEvent(CHANGED, { detail: account }));
  channel?.postMessage(account);
}
export function subscribeFoods(account: string, listener: () => void) {
  const changed = (event: Event) => {
    if ((event as CustomEvent).detail === account) listener();
  };
  window.addEventListener(CHANGED, changed);
  return () => window.removeEventListener(CHANGED, changed);
}
function open(): Promise<IDBDatabase> {
  if (opening) return opening;
  const promise = new Promise<IDBDatabase>((resolve, reject) => {
    const request = indexedDB.open(DATABASE, 1);
    let finished = false;
    const fail = () => {
      if (!finished) {
        finished = true;
        clearTimeout(timer);
        reject(failedStorage());
      }
    };
    const timer = window.setTimeout(fail, 3000);
    request.onblocked = fail;
    request.onerror = fail;
    request.onupgradeneeded = () => request.result.createObjectStore(STORE);
    request.onsuccess = () => {
      clearTimeout(timer);
      if (finished) {
        request.result.close();
        return;
      }
      finished = true;
      const db = request.result;
      db.onversionchange = () => {
        db.close();
        opening = null;
      };
      resolve(db);
    };
  });
  opening = promise;
  void promise.catch(() => {
    if (opening === promise) opening = null;
  });
  return promise;
}
export function emptyFoods(account: string): FoodDocument {
  return { version: 1, account, entries: {}, operations: [], drafts: {}, days: {}, receipts: {} };
}
function validate(value: FoodDocument | undefined, account: string): FoodDocument {
  if (value === undefined) return emptyFoods(account);
  if (
    !value ||
    value.version !== 1 ||
    value.account !== account ||
    !value.entries ||
    !value.drafts ||
    !value.days ||
    !value.receipts ||
    !Array.isArray(value.operations)
  )
    throw unreadable();
  for (const map of [value.entries, value.drafts, value.days, value.receipts])
    if (typeof map !== 'object' || Array.isArray(map)) throw unreadable();
  Object.values(value.entries).forEach(normalizeFood);
  for (const receipt of Object.values(value.receipts)) {
    if (!Array.isArray(receipt)) throw unreadable();
    receipt.forEach(normalizeFood);
  }
  const previousOperations = new Set<string>();
  for (const op of value.operations) {
    if (
      !op ||
      typeof op.id !== 'string' ||
      !op.entity ||
      !['save', 'delete', 'restore', 'batch'].includes(op.kind) ||
      !Array.isArray(op.copies) ||
      !op.copies.length ||
      (op.base !== null && (!Number.isInteger(op.base) || op.base < 0)) ||
      (op.wire &&
        (!['POST', 'PUT', 'DELETE'].includes(op.wire.method) ||
          !/^\/api\/food(?:\/|$)/.test(op.wire.path) ||
          !op.wire.body))
    )
      throw unreadable();
    op.copies.forEach(normalizeFood);
    if (previousOperations.has(op.id) || (op.after && !previousOperations.has(op.after)))
      throw unreadable();
    previousOperations.add(op.id);
  }
  for (const draft of Object.values(value.drafts)) {
    if (
      !draft?.id ||
      !draft.entity ||
      !draft.fields ||
      Object.values(draft.fields).some((field) => typeof field !== 'string')
    )
      throw unreadable();
  }
  return value;
}
// Each edit, its optimistic copy and its replay operation commit together. IDB
// serializes these read-modify-write transactions across browser tabs.
async function transaction<T>(
  account: string,
  edit: ((doc: FoodDocument) => T) | null
): Promise<T | FoodDocument> {
  const db = await open();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, edit ? 'readwrite' : 'readonly');
    const store = tx.objectStore(STORE);
    let result: T | FoodDocument;
    let error: unknown;
    const request = store.get(keyFor(account));
    request.onsuccess = () => {
      try {
        const doc = validate(request.result, account);
        result = edit ? edit(doc) : doc;
        if (edit) store.put(doc, keyFor(account));
      } catch (caught) {
        error = caught;
        tx.abort();
      }
    };
    tx.oncomplete = () => {
      if (edit) notify(account);
      resolve(result);
    };
    tx.onabort = tx.onerror = () => reject(error || failedStorage());
  });
}
export const readFoods = (account: string) =>
  transaction<never>(account, null) as Promise<FoodDocument>;
const update = <T>(account: string, edit: (doc: FoodDocument) => T) =>
  transaction(account, edit) as Promise<T>;
function assertOwner(owner: FoodOwner) {
  if (getSessionScope() !== owner.scope)
    throw new Error('Your account changed. Reopen the diary to continue.');
}
function merge(doc: FoodDocument, raw: FoodEntry) {
  const row = normalizeFood(raw);
  if (row.account_id && String(row.account_id) !== doc.account) throw unreadable();
  const alias =
    Object.values(doc.entries).find((entry) => entry.id === row.id)?.client_id ?? row.client_id;
  const previous = doc.entries[alias];
  if (!previous || row.revision >= previous.revision)
    doc.entries[alias] = { ...row, client_id: alias };
}
export function visibleFoods(doc: FoodDocument): FoodEntry[] {
  const entries = { ...doc.entries };
  for (const operation of doc.operations)
    for (const row of operation.copies)
      entries[row.client_id] = { ...row, local_operation: operation.id };
  return Object.values(entries);
}
export async function cacheFoods(owner: FoodOwner, rows: FoodEntry[], day?: string) {
  assertOwner(owner);
  await update(owner.account, (doc) => {
    assertOwner(owner);
    rows.forEach((row) => merge(doc, row));
    if (day) doc.days[day] = Date.now();
  });
}
export async function refreshFoods(owner: FoodOwner, day: string): Promise<void> {
  assertOwner(owner);
  if (!isCalendarDay(day)) throw new Error('Choose a valid date.');
  const rows: FoodEntry[] = [];
  for (let page = 1; ; page++) {
    const next = await api.get<FoodEntry[]>(
      `/api/food?date=${day}&include_deleted=true&limit=100&page=${page}`
    );
    assertOwner(owner);
    if (!Array.isArray(next)) throw unreadable();
    rows.push(...next.map(normalizeFood));
    if (next.length < 100) break;
  }
  // Moved entries no longer appear on this day. Fetch their current revision
  // rather than treating absence as deletion or overwriting a pending edit.
  const local = await readFoods(owner.account);
  const ids = new Set(rows.map((row) => row.id));
  const missing = Object.values(local.entries).filter(
    (row) => row.entry_date === day && !ids.has(row.id)
  );
  for (const row of missing) {
    assertOwner(owner);
    rows.push(
      normalizeFood(
        await api.get<FoodEntry>(`/api/food/${encodeURIComponent(row.id)}?include_deleted=true`)
      )
    );
  }
  await cacheFoods(owner, rows, day);
}
export async function saveFoodDraft(owner: FoodOwner, draft: FoodDraft) {
  assertOwner(owner);
  await update(owner.account, (doc) => {
    assertOwner(owner);
    doc.drafts[draft.id] = structuredClone(draft);
  });
}
export async function discardFoodDraft(owner: FoodOwner, id: string) {
  assertOwner(owner);
  await update(owner.account, (doc) => {
    assertOwner(owner);
    delete doc.drafts[id];
  });
}
export async function resumeFoodDraft(owner: FoodOwner, id: string) {
  assertOwner(owner);
  return update(owner.account, (doc) => {
    assertOwner(owner);
    const saved = doc.drafts[id];
    if (!saved)
      throw new Error('This draft was opened in another tab. Refresh to see the current drafts.');
    const branch = { ...saved, id: operationID(), updatedAt: Date.now() };
    doc.drafts[branch.id] = branch;
    delete doc.drafts[id];
    return branch;
  });
}
function queue(
  doc: FoodDocument,
  kind: 'save' | 'delete' | 'restore',
  input: FoodInput | undefined,
  original: FoodEntry | null,
  entity: string
) {
  const previous = [...doc.operations]
    .reverse()
    .find((op) => op.copies.some((row) => row.client_id === entity));
  if (previous && original?.local_operation !== previous.id)
    throw new Error(
      'This food changed in another tab. Reopen the entry to review it before saving.'
    );
  if (
    doc.operations.some((op) => op.attention && op.copies.some((row) => row.client_id === entity))
  )
    throw new Error('Review this food’s sync issue before making another change.');
  if (!previous && original?.local_operation) {
    const receipt = doc.receipts[original.local_operation]?.find(
      (row) => row.client_id === entity || row.id === original!.id
    );
    if (!receipt)
      throw new Error(
        'This food changed while you were editing. Reopen it to review the saved version.'
      );
    original = { ...original, id: receipt.id, revision: receipt.revision };
  }
  const id = operationID();
  const copy = input ? snapshot(input, entity, original) : { ...original! };
  copy.deleted_at = kind === 'delete' ? new Date().toISOString() : null;
  const op: FoodOperation = {
    id,
    entity,
    kind,
    serverID: original?.id ?? '',
    base: previous ? null : (original?.revision ?? 0),
    after: previous?.id,
    input,
    copies: [copy],
  };
  doc.operations.push(op);
  return op;
}
export async function saveFood(owner: FoodOwner, draft: FoodDraft, input: FoodInput) {
  assertOwner(owner);
  await update(owner.account, (doc) => {
    assertOwner(owner);
    if (draft.replaces) {
      const rejected = doc.operations.find((op) => op.id === draft.replaces);
      if (!rejected?.attention || rejected.status !== 400 || rejected.kind !== 'save')
        throw new Error(
          'The queued change is no longer awaiting correction. Reopen the food to review it.'
        );
      const chain = new Set([rejected.id]);
      for (const row of doc.operations) if (row.after && chain.has(row.after)) chain.add(row.id);
      if (doc.operations.some((row) => row.id !== rejected.id && chain.has(row.id) && row.wire))
        throw unreadable();
      doc.operations = doc.operations.filter((row) => !chain.has(row.id));
    }
    queue(doc, 'save', input, draft.original, draft.entity);
    // A newer editor branch must never be removed by this submission.
    if (JSON.stringify(doc.drafts[draft.id]?.fields) === JSON.stringify(draft.fields))
      delete doc.drafts[draft.id];
  });
  void syncFoods(owner);
}
export async function correctFood(owner: FoodOwner, id: string): Promise<FoodDraft> {
  assertOwner(owner);
  return update(owner.account, (doc) => {
    assertOwner(owner);
    const rejected = doc.operations.find((op) => op.id === id);
    if (!rejected?.attention || rejected.status !== 400 || rejected.kind !== 'save')
      throw new Error('Reopen the food to review its current sync status.');
    const copy = [...doc.operations]
      .reverse()
      .find((op) => op.copies.some((row) => row.client_id === rejected.entity))!.copies[0];
    const draft = newFoodDraft(copy.entry_date, copy.meal_type ?? 'snack', copy);
    draft.original =
      rejected.base === 0
        ? null
        : { ...copy, id: rejected.serverID, revision: rejected.base!, local_operation: undefined };
    draft.replaces = id;
    doc.drafts[draft.id] = draft;
    return draft;
  });
}
export async function changeFood(
  owner: FoodOwner,
  original: FoodEntry,
  kind: 'delete' | 'restore'
) {
  assertOwner(owner);
  await update(owner.account, (doc) => {
    assertOwner(owner);
    queue(doc, kind, undefined, original, original.client_id);
  });
  void syncFoods(owner);
}
export async function copyFoods(owner: FoodOwner, inputs: FoodInput[]) {
  assertOwner(owner);
  if (!inputs.length || inputs.length > 50)
    throw new Error('Select between 1 and 50 foods to copy.');
  if (inputs.some((row) => row.entry_date !== inputs[0].entry_date))
    throw new Error('Choose one destination date.');
  await update(owner.account, (doc) => {
    assertOwner(owner);
    const copies = inputs.map((input) => snapshot(input, operationID()));
    const id = operationID();
    doc.operations.push({
      id,
      kind: 'batch',
      entity: id,
      serverID: '',
      base: 0,
      copies,
      wire: {
        method: 'POST',
        path: '/api/food/batch',
        body: {
          base_revision: 0,
          entry_date: inputs[0].entry_date,
          items: inputs.map((input, index) => ({ ...input, client_id: copies[index].client_id })),
        },
      },
    });
  });
  void syncFoods(owner);
}
function wireFor(op: FoodOperation): Wire {
  if (op.wire) return op.wire;
  if (op.base === null || op.after) throw unreadable();
  const base = { base_revision: op.base };
  if (op.kind === 'save' && op.base === 0)
    return {
      method: 'POST',
      path: '/api/food',
      body: { ...op.input, ...base, client_id: op.entity },
    };
  const path = `/api/food/${encodeURIComponent(op.serverID)}`;
  if (op.kind === 'save') return { method: 'PUT', path, body: { ...op.input, ...base } };
  if (op.kind === 'delete') return { method: 'DELETE', path, body: base };
  return { method: 'POST', path: `${path}/restore`, body: base };
}
const running = new Map<string, Promise<void>>();
export function syncFoods(owner: FoodOwner): Promise<void> {
  const key = keyFor(owner.account) + owner.scope;
  const current = running.get(key);
  if (current) return current.then(() => syncFoods(owner));
  const promise = drain(owner).finally(() => {
    if (running.get(key) === promise) running.delete(key);
  });
  running.set(key, promise);
  return promise;
}
async function drain(owner: FoodOwner) {
  const attempted = new Set<string>();
  while (getSessionScope() === owner.scope) {
    let op: FoodOperation | undefined;
    try {
      const doc = await readFoods(owner.account);
      op = doc.operations.find((row) => !row.after && !row.attention && !attempted.has(row.id));
      if (!op) return;
      attempted.add(op.id);
      const id = op.id;
      op = await update(owner.account, (stored) => {
        assertOwner(owner);
        const selected = stored.operations.find((row) => row.id === id);
        if (!selected || selected.after || selected.attention) return undefined;
        selected.wire ??= wireFor(selected);
        return structuredClone(selected);
      });
      if (!op) continue;
      assertOwner(owner);
      const wire = op.wire!;
      const options = { operationID: op.id };
      const response =
        wire.method === 'DELETE'
          ? await api.del<{ food: FoodEntry }>(wire.path, { ...options, body: wire.body })
          : await (wire.method === 'PUT'
              ? api.put<FoodEntry>(wire.path, wire.body, options)
              : api.post<FoodEntry | { created: FoodEntry[] }>(wire.path, wire.body, options));
      const rows =
        op.kind === 'batch'
          ? (response as { created: FoodEntry[] }).created
          : [
              wire.method === 'DELETE'
                ? (response as { food: FoodEntry }).food
                : (response as FoodEntry),
            ];
      if (!Array.isArray(rows) || rows.length !== op.copies.length) throw unreadable();
      rows.forEach(normalizeFood);
      if (
        rows.some(
          (row) =>
            !op!.copies.some((copy) => copy.client_id === row.client_id || copy.id === row.id)
        )
      )
        throw unreadable();
      const completed = op;
      // A response received after sign-out belongs to the original account.
      // Persist its acknowledgement there, without rendering it for the next one.
      await update(owner.account, (stored) => {
        rows.forEach((row) => merge(stored, row));
        stored.receipts[completed.id] = rows;
        stored.operations = stored.operations.filter((row) => row.id !== completed.id);
        for (const child of stored.operations.filter((row) => row.after === completed.id)) {
          const row = rows.find(
            (result) => result.client_id === child.entity || result.id === child.serverID
          );
          if (!row) throw unreadable();
          child.after = undefined;
          child.base = row.revision;
          child.serverID = row.id;
          child.copies = child.copies.map((copy) => ({
            ...copy,
            id: row.id,
            revision: row.revision,
          }));
        }
      });
      if (getSessionScope() === owner.scope)
        window.dispatchEvent(new CustomEvent(FOOD_SYNCED, { detail: owner.account }));
    } catch (error) {
      if (op) {
        const attention =
          error instanceof ApiError &&
          error.status >= 400 &&
          error.status < 500 &&
          ![401, 408, 429].includes(error.status);
        try {
          await update(owner.account, (doc) => {
            const saved = doc.operations.find((row) => row.id === op!.id);
            if (saved) {
              saved.error = message(error);
              saved.attention = attention;
              saved.status = error instanceof ApiError ? error.status : undefined;
            }
          });
        } catch {
          /* Do not discard an operation when acknowledging it fails. */
        }
        if (attention) continue;
      }
      return;
    }
  }
}
export async function retryFoods(owner: FoodOwner) {
  assertOwner(owner);
  await update(owner.account, (doc) => {
    assertOwner(owner);
    for (const op of doc.operations)
      if (!op.conflict) {
        op.attention = false;
        op.error = undefined;
      }
  });
  await syncFoods(owner);
}
export async function reviewFood(owner: FoodOwner, operation: FoodOperation): Promise<FoodEntry> {
  assertOwner(owner);
  if (!operation.serverID || operation.serverID.startsWith('local-'))
    throw new Error('This new entry needs a retry. Its saved request will be sent unchanged.');
  const remote = normalizeFood(
    await api.get<FoodEntry>(
      `/api/food/${encodeURIComponent(operation.serverID)}?include_deleted=true`
    )
  );
  assertOwner(owner);
  await update(owner.account, (doc) => {
    assertOwner(owner);
    const current = doc.operations.find((op) => op.id === operation.id);
    if (!current?.attention) throw new Error('This change has already been synchronized.');
    current.conflict = remote;
  });
  return remote;
}
export async function resolveFood(
  owner: FoodOwner,
  id: string,
  choice: 'server' | 'mine',
  reviewed: FoodEntry
) {
  assertOwner(owner);
  const remote = normalizeFood(
    await api.get<FoodEntry>(`/api/food/${encodeURIComponent(reviewed.id)}?include_deleted=true`)
  );
  assertOwner(owner);
  if (remote.revision !== reviewed.revision)
    throw new Error('This food changed again. Refresh the comparison before choosing a copy.');
  await update(owner.account, (doc) => {
    assertOwner(owner);
    const op = doc.operations.find((row) => row.id === id);
    if (!op?.attention || op.conflict?.revision !== reviewed.revision)
      throw new Error('Reopen the comparison before continuing.');
    // Resolving a conflict is an explicit decision about the full local chain.
    // Keep the latest locally edited snapshot, not just the first rejected edit.
    const chain = new Set([id]);
    for (const row of doc.operations) if (row.after && chain.has(row.after)) chain.add(row.id);
    const latest = [...doc.operations].reverse().find((row) => chain.has(row.id))!;
    const mine = latest.copies[0];
    doc.operations = doc.operations.filter((row) => !chain.has(row.id));
    merge(doc, remote);
    if (choice === 'server') return;
    const original = { ...remote, client_id: op.entity };
    if (mine.deleted_at) {
      if (!remote.deleted_at) queue(doc, 'delete', undefined, original, op.entity);
    } else {
      let base = original;
      if (remote.deleted_at) {
        const restore = queue(doc, 'restore', undefined, original, op.entity);
        base = { ...original, deleted_at: null, local_operation: restore.id };
      }
      // Snapshot values are per basis, while the visible row is already scaled.
      const values = mine.nutrition_snapshot;
      if (!values) throw unreadable();
      queue(doc, 'save', perServing(mine), base, op.entity);
    }
  });
  void syncFoods(owner);
}
