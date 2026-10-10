// Data that can leave and come back. CSV files for spreadsheets, one per kind
// of data, and an import that restores an Exerly JSON export (/api/export)
// into an account. PARITY I14; see docs/design/022-export-import.md.

const store = require('../data');
const docs = require('./documents');
const { NUTRIENTS, NUTRIENT_UNITS } = require('./nutrition/validate');

const round = (value) => (value == null ? null : Math.round(value * 10000) / 10000);

/** One CSV cell. Text that a spreadsheet would run as a formula is quoted with a leading apostrophe. */
function cell(value) {
  if (value == null) return '';
  let text = typeof value === 'object' ? JSON.stringify(value) : String(value);
  if (typeof value === 'string' && /^[=+\-@\t\r]/.test(text)) text = `'${text}`;
  return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

function csv(header, rows) {
  return [header, ...rows].map((row) => row.map(cell).join(',')).join('\r\n') + '\r\n';
}

const nutrientHeader = NUTRIENTS.map((n) => `${n}_${NUTRIENT_UNITS[n]}`);
// Unknown stays empty: a food that doesn't report a nutrient isn't zero.
const nutrientCells = (amounts, scale = 1) =>
  NUTRIENTS.map((n) => (amounts?.[n] == null ? null : round(amounts[n] * scale)));

const mass = (m) => (m ? [m.value, m.unit] : [null, null]);

/** For each CSV file: the documents it reads, its columns, and its rows for one document. */
const FILES = {
  food_entries: {
    kind: 'food_entry',
    header: [
      'id',
      'revision',
      'updated_at',
      'date',
      'meal',
      'logged_at',
      'food_id',
      'food_name',
      'brand',
      'source',
      'grams',
      'serving',
      'serving_grams',
      'quantity',
      'density_g_per_ml',
      'density_assumed',
      ...nutrientHeader,
    ],
    rows: (p, d) => [
      [
        d.document_id,
        d.revision,
        d.updated_at,
        p.date,
        p.meal,
        p.loggedAt,
        p.food?.foodID,
        p.food?.name,
        p.food?.brand,
        p.food?.source,
        // An unweighed portion's 100 g is nominal: its weight is unknown.
        p.food?.unweighed ? null : p.grams,
        p.serving?.name,
        p.serving?.grams,
        p.quantity,
        p.food?.volume?.density,
        p.food?.volume?.assumed,
        ...nutrientCells(p.food?.per100g, (p.grams ?? 0) / 100),
      ],
    ],
    order: (p) => `${p.date} ${p.loggedAt}`,
  },
  saved_foods: {
    kind: 'saved_food',
    header: [
      'id',
      'revision',
      'updated_at',
      'name',
      'brand',
      'source',
      'barcode',
      'favorite',
      'archived_at',
      'servings',
      'density_g_per_ml',
      'yield_grams',
      'serving_count',
      'ingredients',
      'preparation',
      ...nutrientHeader.map((h) => `${h}_per_100g`),
    ],
    rows: (p, d) => [
      [
        d.document_id,
        d.revision,
        d.updated_at,
        p.name,
        p.brand,
        p.source,
        p.barcode,
        p.favorite,
        p.archivedAt,
        (p.servings ?? []).map((s) => `${s.name} = ${s.grams} g`).join('; '),
        p.volume?.density,
        p.yieldGrams,
        p.servingCount,
        (p.ingredients ?? []).map((i) => `${i.food?.name} = ${round(i.grams)} g`).join('; '),
        p.preparation,
        ...nutrientCells(p.per100g),
      ],
    ],
    order: (p) => p.name?.toLowerCase() ?? '',
  },
  weigh_ins: {
    kind: 'weight_entry',
    header: [
      'id',
      'revision',
      'updated_at',
      'at',
      'date',
      'weight',
      'unit',
      'body_fat_percent',
      'source',
    ],
    rows: (p, d) => [
      [
        d.document_id,
        d.revision,
        d.updated_at,
        p.at,
        p.date,
        ...mass(p.weight),
        p.bodyFat,
        p.source,
      ],
    ],
    order: (p) => p.at ?? '',
  },
  days: {
    kind: 'nutrition_day',
    header: ['date', 'revision', 'updated_at', 'status', 'notes', 'tags'],
    rows: (p, d) => [
      [p.date, d.revision, d.updated_at, p.status, p.notes, (p.tags ?? []).join('; ')],
    ],
    order: (p) => p.date ?? '',
  },
  sets: {
    kind: 'workout_session',
    header: [
      'session_id',
      'revision',
      'updated_at',
      'session',
      'started_at',
      'ended_at',
      'time_zone',
      'exercise_position',
      'exercise_id',
      'superset_id',
      'set_position',
      'set_id',
      'kind',
      'side',
      'effort',
      'reps',
      'load',
      'load_unit',
      'duration_s',
      'distance_m',
      'rir',
      'completed_at',
      'bodyweight',
      'bodyweight_unit',
      'program_id',
      'program_day_id',
      'program_cycle',
    ],
    rows: (p, d) =>
      (p.exercises ?? []).flatMap((exercise, e) =>
        (exercise.sets ?? []).flatMap((set, s) =>
          (set.efforts ?? []).map((effort, f) => [
            d.document_id,
            d.revision,
            d.updated_at,
            p.name,
            p.startedAt,
            p.endedAt,
            p.timeZoneID,
            e + 1,
            exercise.exerciseID,
            exercise.supersetID,
            s + 1,
            set.id,
            set.kind,
            set.side,
            f + 1,
            effort.reps,
            ...mass(effort.load),
            effort.duration,
            effort.distance,
            set.rir,
            set.completedAt,
            ...mass(p.bodyweight),
            p.program?.programID,
            p.program?.dayID,
            p.program?.cycle,
          ])
        )
      ),
    order: (p) => p.startedAt ?? '',
  },
  metric_values: {
    kind: 'metric_entry',
    header: ['id', 'revision', 'updated_at', 'metric_id', 'date', 'value'],
    rows: (p, d) => [[d.document_id, d.revision, d.updated_at, p.metricID, p.date, p.value]],
    order: (p) => `${p.metricID} ${p.date}`,
  },
  metrics: {
    kind: 'custom_metric',
    header: [
      'id',
      'revision',
      'updated_at',
      'name',
      'unit',
      'kind',
      'minimum',
      'maximum',
      'archived',
    ],
    rows: (p, d) => [
      [
        d.document_id,
        d.revision,
        d.updated_at,
        p.name,
        p.unit,
        p.kind,
        p.minimum,
        p.maximum,
        p.archived,
      ],
    ],
    order: (p) => p.name?.toLowerCase() ?? '',
  },
};

/** One CSV file of the account's live documents, or null for an unknown name. */
async function exportCSV(account, name) {
  const file = FILES[name];
  if (!file) return null;
  const rows = (await store.find('documents', { account_id: account.id, kind: file.kind }))
    .filter((d) => !d.deleted_at && d.payload)
    .map((d) => ({ ...d, updated_at: d.updated_at ? new Date(d.updated_at).toISOString() : null }))
    .sort((a, b) => file.order(a.payload).localeCompare(file.order(b.payload)));
  return csv(
    file.header,
    rows.flatMap((d) => file.rows(d.payload, d))
  );
}

/**
 * Restores the documents in an Exerly JSON export. A document the account
 * already has is kept as it is; the rest are checked as an API write would be
 * and added with their exported revisions. Legacy tables aren't imported.
 */
async function importExport(account, body, { now = new Date() } = {}) {
  if (!body || typeof body !== 'object' || !Array.isArray(body.documents)) {
    return { error: 'This is not an Exerly export: it has no documents.' };
  }
  const result = { imported: 0, kept: 0, skipped: [], ignored_tables: [] };
  result.ignored_tables = Object.keys(body).filter(
    (key) =>
      !['documents', 'account', 'exported_at', 'version'].includes(key) &&
      Array.isArray(body[key]) &&
      body[key].length
  );
  await store.transaction(async () => {
    for (const row of body.documents) {
      if (!row || row.deleted_at) continue;
      const kind = String(row.kind ?? '');
      const id = docs.canonicalID(String(row.document_id ?? ''));
      try {
        docs.readKind(kind);
        docs.readID(id);
        const payload = docs.readPayload(kind, id, row.payload);
        if (await docs.current(account, kind, id)) {
          result.kept += 1;
          continue;
        }
        const inserted = await store.insert('documents', {
          account_id: account.id,
          kind,
          document_id: id,
          revision: Number.isInteger(row.revision) && row.revision > 0 ? row.revision : 1,
          payload,
          deleted_at: null,
          created_at: now,
          updated_at: now,
        });
        await docs.record(account, inserted);
        result.imported += 1;
      } catch (error) {
        if (result.skipped.length < 50) result.skipped.push({ kind, id, reason: error.message });
      }
    }
    if (result.imported) {
      await docs.appendAudit(account, {
        action: 'directWrite',
        actor: { kind: 'builtIn', name: 'Exerly import' },
        targets: [],
        note: `Imported ${result.imported} documents from an export made ${body.exported_at ?? 'at an unknown time'}.`,
      });
    }
  });
  return result;
}

module.exports = { FILES, cell, exportCSV, importExport };
