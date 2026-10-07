import { api } from '../../lib/api';
import { operationID } from '../../lib/ids';

export type LogKind = 'activity' | 'sleep';
export interface LogRecord {
  id: string;
  client_id: string;
  revision: number;
  entry_date: string;
  created_at?: string;
  deleted_at?: string | null;
  activity?: string;
  duration_min?: number;
  calories?: number | null;
  intensity?: string | null;
  type?: string | null;
  hours?: number;
  quality?: string | null;
  bedtime?: string | null;
  wake_time?: string | null;
}
export interface LogWrite {
  id: string;
  entity: string;
  method: 'POST' | 'PUT' | 'DELETE';
  intent: 'save' | 'delete' | 'restore';
  path: string;
  body: Record<string, unknown>;
  snapshot: LogRecord;
  replaces?: string;
}
export interface LogDraft {
  entity: string;
  original?: LogRecord;
  fields: Record<string, string>;
}
export const logsChanged = 'exerly-manual-logs';
export const logPath = (kind: LogKind) => (kind === 'activity' ? '/api/activities' : '/api/sleep');
const invalidStorage = () =>
  new Error('Saved entries could not be read. They are still stored in this browser.');

export function normalizeLog(input: LogRecord): LogRecord {
  const row = {
    ...input,
    id: String(input.id),
    client_id: input.client_id || `legacy-${input.id}`,
    revision: input.revision ?? 1,
  };
  if (
    !input.id ||
    !row.client_id ||
    !Number.isInteger(row.revision) ||
    !/^\d{4}-\d{2}-\d{2}$/.test(row.entry_date)
  )
    throw invalidStorage();
  return row;
}
function stored<T>(prefix: string, validate: (row: T) => boolean): T[] {
  const rows: T[] = [];
  for (let i = 0; i < localStorage.length; i++) {
    const key = localStorage.key(i);
    if (!key?.startsWith(prefix)) continue;
    const row = JSON.parse(localStorage.getItem(key) || 'null') as T;
    if (!row || !validate(row)) throw invalidStorage();
    rows.push(row);
  }
  return rows;
}
export function readLogs(prefix: string) {
  return stored<LogRecord>(`${prefix}entry:`, (row) => !!normalizeLog(row));
}
export function readWrites(prefix: string, kind: LogKind) {
  const path = logPath(kind);
  const rows = stored<LogWrite>(
    `${prefix}write:`,
    (row) =>
      typeof row.id === 'string' &&
      typeof row.entity === 'string' &&
      ['POST', 'PUT', 'DELETE'].includes(row.method) &&
      ['save', 'delete', 'restore'].includes(row.intent) &&
      !!row.body &&
      !!row.snapshot &&
      !!normalizeLog(row.snapshot) &&
      (row.path === path || row.path.startsWith(`${path}/`))
  );
  const replaced = new Set(rows.map((row) => row.replaces));
  return rows.filter((row) => !replaced.has(row.id));
}
export function readDraft(key: string): LogDraft | null {
  const row = JSON.parse(localStorage.getItem(key) || 'null') as LogDraft | null;
  if (
    row &&
    (typeof row.entity !== 'string' ||
      !row.fields ||
      Object.values(row.fields).some((value) => typeof value !== 'string'))
  )
    throw invalidStorage();
  return row;
}
export function changed() {
  window.dispatchEvent(new Event(logsChanged));
}
export function saveRecord(prefix: string, input: LogRecord) {
  const row = normalizeLog(input);
  const key = `${prefix}entry:${row.client_id}`;
  const previous = JSON.parse(localStorage.getItem(key) || 'null') as LogRecord | null;
  if (!previous || previous.revision <= row.revision)
    localStorage.setItem(key, JSON.stringify(row));
}
export function persistWrite(prefix: string, write: LogWrite) {
  localStorage.setItem(`${prefix}write:${write.id}`, JSON.stringify(write));
  // Persist the replacement first so interruption never removes the only copy.
  if (write.replaces) localStorage.removeItem(`${prefix}write:${write.replaces}`);
  changed();
}
export function removeWrite(prefix: string, id: string) {
  localStorage.removeItem(`${prefix}write:${id}`);
  changed();
}
export async function transmit(write: LogWrite, kind: LogKind): Promise<LogRecord> {
  const options = { operationID: write.id };
  if (write.method === 'DELETE') {
    const result = await api.del<Record<string, LogRecord>>(write.path, {
      ...options,
      body: write.body,
    });
    return normalizeLog(result[kind]);
  }
  return normalizeLog(
    await (write.method === 'PUT'
      ? api.put<LogRecord>(write.path, write.body, options)
      : api.post<LogRecord>(write.path, write.body, options))
  );
}
export function describeLog(row: LogRecord, kind: LogKind) {
  const number = (value: number | undefined) =>
    value?.toLocaleString(undefined, { maximumFractionDigits: 4 }) ?? '—';
  if (kind === 'activity')
    return `${row.activity} · ${number(row.duration_min)} min · ${row.calories == null ? 'Calories not recorded' : `${number(row.calories)} kcal`}`;
  return `${number(row.hours)} hours · ${row.quality || 'Quality not recorded'}${row.bedtime || row.wake_time ? ` · ${row.bedtime || '—'} – ${row.wake_time || '—'}` : ''}`;
}
export function newDraft(date: string): LogDraft {
  return {
    entity: operationID(),
    fields: {
      entry_date: date,
      activity: '',
      duration_min: '',
      calories: '',
      intensity: '',
      type: '',
      hours: '',
      quality: '',
      bedtime: '',
      wake_time: '',
    },
  };
}
export function editDraft(row: LogRecord): LogDraft {
  const draft = newDraft(row.entry_date);
  draft.entity = row.client_id;
  draft.original = row;
  for (const key of Object.keys(draft.fields))
    draft.fields[key] = String(row[key as keyof LogRecord] ?? '');
  return draft;
}
