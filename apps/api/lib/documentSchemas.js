// The shapes ExerlyCore decodes for agent documents (Agent.swift), so the
// server never stores a proposal or audit event a device can't read. Each
// function returns a list of problems, empty when the document is valid.
// Optional fields may be absent: Swift omits nil values when it encodes.

const UUID_RE = /^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$/;
const INSTANT_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,9})?(Z|[+-]\d{2}:\d{2})$/;

const AGENT_KINDS = ['builtIn', 'mcp', 'api'];
const EVIDENCE_LEVELS = ['humanRCT', 'observational', 'mechanism', 'anecdote', 'personalData'];
const CONFIDENCE = ['low', 'medium', 'high'];
const STATUSES = ['pending', 'accepted', 'rejected', 'undone', 'stale'];
const AUDIT_ACTIONS = [
  'proposalFiled',
  'proposalAccepted',
  'proposalRejected',
  'proposalUndone',
  'proposalStale',
  'directWrite',
  'tokenCreated',
  'tokenRevoked',
];

const isString = (v) => typeof v === 'string';
const isObject = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
const isInstant = (v) => isString(v) && INSTANT_RE.test(v) && !Number.isNaN(Date.parse(v));
const optional = (v, check) => v === undefined || v === null || check(v);

function identityProblems(identity, where) {
  if (!isObject(identity)) return [`${where} must be an object`];
  const problems = [];
  if (!AGENT_KINDS.includes(identity.kind))
    problems.push(`${where}.kind must be one of ${AGENT_KINDS}`);
  if (!isString(identity.name)) problems.push(`${where}.name must be a string`);
  if (!optional(identity.tokenID, isString)) problems.push(`${where}.tokenID must be a string`);
  return problems;
}

function refProblems(refs, where) {
  if (!Array.isArray(refs)) return [`${where} must be an array`];
  return refs.flatMap((ref, i) =>
    isObject(ref) && isString(ref.kind) && isString(ref.id)
      ? []
      : [`${where}[${i}] must be {"kind": string, "id": string}`]
  );
}

function evidenceProblems(item, where) {
  if (!isObject(item)) return [`${where} must be an object`];
  const problems = [];
  if (!isString(item.claim)) problems.push(`${where}.claim must be a string`);
  if (!EVIDENCE_LEVELS.includes(item.level))
    problems.push(`${where}.level must be one of ${EVIDENCE_LEVELS}`);
  if (!Array.isArray(item.caveats) || !item.caveats.every(isString))
    problems.push(`${where}.caveats must be an array of strings`);
  problems.push(...refProblems(item.dataRefs, `${where}.dataRefs`));
  if (!optional(item.source, isString)) problems.push(`${where}.source must be a string`);
  if (item.metric !== undefined && item.metric !== null) {
    const m = item.metric;
    const valid =
      isObject(m) &&
      isString(m.name) &&
      isObject(m.parameters) &&
      Object.values(m.parameters).every(isString) &&
      typeof m.claimed === 'number' &&
      Number.isFinite(m.claimed);
    if (!valid)
      problems.push(
        `${where}.metric must be {"name": string, "parameters": {string: string}, "claimed": number}`
      );
  }
  return problems;
}

/** Problems with a proposal payload. */
function proposalProblems(p) {
  if (!isObject(p)) return ['payload must be an object'];
  const problems = [];
  if (!UUID_RE.test(p.id ?? '')) problems.push('id must be a UUID');
  if (!isInstant(p.createdAt)) problems.push('createdAt must be an ISO 8601 instant');
  problems.push(...identityProblems(p.author, 'author'));
  if (!isString(p.title) || p.title.trim() === '') problems.push('title must not be empty');
  if (!isString(p.summary)) problems.push('summary must be a string');
  if (!isString(p.falsifier) || p.falsifier.trim() === '')
    problems.push('falsifier must say what would show the proposal is wrong');
  if (!CONFIDENCE.includes(p.confidence)) problems.push(`confidence must be one of ${CONFIDENCE}`);
  if (!STATUSES.includes(p.status)) problems.push(`status must be one of ${STATUSES}`);
  if (!optional(p.decidedAt, isInstant)) problems.push('decidedAt must be an ISO 8601 instant');
  if (!Array.isArray(p.evidence)) problems.push('evidence must be an array');
  else p.evidence.forEach((item, i) => problems.push(...evidenceProblems(item, `evidence[${i}]`)));
  if (!Array.isArray(p.changes) || p.changes.length === 0) {
    problems.push('changes must list at least one change');
  } else {
    const seen = new Set();
    p.changes.forEach((change, i) => {
      const where = `changes[${i}]`;
      if (!isObject(change) || !isString(change.kind) || !isString(change.id)) {
        problems.push(`${where} needs a kind and an id`);
        return;
      }
      const target = `${change.kind}/${change.id}`;
      if (seen.has(target)) problems.push(`${where} changes ${target} a second time`);
      seen.add(target);
      if ((change.before ?? null) === null && (change.after ?? null) === null)
        problems.push(`${where} needs a before or an after`);
    });
  }
  return problems;
}

/** Problems with an audit_event payload. */
function auditEventProblems(e) {
  if (!isObject(e)) return ['payload must be an object'];
  const problems = [];
  if (!UUID_RE.test(e.id ?? '')) problems.push('id must be a UUID');
  if (!isInstant(e.at)) problems.push('at must be an ISO 8601 instant');
  if (!AUDIT_ACTIONS.includes(e.action)) problems.push(`action must be one of ${AUDIT_ACTIONS}`);
  problems.push(...identityProblems(e.actor, 'actor'));
  if (!optional(e.proposalID, (v) => UUID_RE.test(v))) problems.push('proposalID must be a UUID');
  problems.push(...refProblems(e.targets, 'targets'));
  if (!optional(e.note, isString)) problems.push('note must be a string');
  return problems;
}

module.exports = { proposalProblems, auditEventProblems, EVIDENCE_LEVELS };
