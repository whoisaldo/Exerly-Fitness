// The MCP server: a person's own agent (Claude, ChatGPT or anything that
// speaks MCP) reads their training through Exerly's calculations and files
// proposals they decide on. Streamable HTTP, stateless, JSON responses, and
// authenticated with a personal access token. See docs/design/004-agent-core.md.

const express = require('express');
const { McpServer } = require('@modelcontextprotocol/sdk/server/mcp.js');
const {
  StreamableHTTPServerTransport,
} = require('@modelcontextprotocol/sdk/server/streamableHttp.js');
const { z } = require('zod');

const { authenticate } = require('../lib/auth');
const { asyncHandler, forbidden } = require('../lib/errors');
const { rateLimit } = require('../lib/ratelimit');
const { MUSCLES } = require('../lib/training/library');
const tools = require('../lib/agentTools');

const router = express.Router();
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'YYYY-MM-DD');
const muscle = z.enum(MUSCLES);
const readOnly = { readOnlyHint: true, openWorldHint: false };

const INSTRUCTIONS = `Exerly holds this person's training log. Every number these tools return
comes from Exerly's tested calculations, the same ones the app shows: quote them rather than
computing your own. Loads are kilograms and volume is kilogram-reps unless a field says
otherwise; get_profile says which units the person prefers. You can't change data directly.
To suggest a change (fix an entry, adjust a session, add a custom exercise), call propose: the
person reviews the diff, your evidence and your falsifier in Exerly and decides. Label evidence
honestly: personalData is n=1, and say when data is short or confounded. No medical claims.`;

function result(value) {
  return { content: [{ type: 'text', text: JSON.stringify(value, null, 2) }] };
}

/** Runs a tool against a fresh view of the account; expected errors become tool errors. */
function handler(account, run) {
  return async (input) => {
    try {
      return result(await run(await tools.workspace(account), input ?? {}));
    } catch (error) {
      if (!error.expected) throw error;
      return { isError: true, content: [{ type: 'text', text: error.message }] };
    }
  };
}

function buildServer(account, pat) {
  const server = new McpServer(
    { name: 'exerly', title: 'Exerly', version: '1.0.0' },
    { instructions: INSTRUCTIONS }
  );
  const tool = (name, config, run) => server.registerTool(name, config, handler(account, run));

  tool(
    'get_profile',
    {
      title: 'Profile and units',
      description:
        "The person's time zone, today's date there, preferred units, how much training is logged and pending proposals. Call this first.",
      annotations: readOnly,
    },
    (ws) => tools.profile(ws)
  );

  tool(
    'list_workouts',
    {
      title: 'List workouts',
      description:
        'Workouts newest first, each with its local date, duration, exercises, working sets and volume. Dates are the local date the workout started on.',
      inputSchema: {
        from: date.optional().describe('First local date, inclusive'),
        through: date.optional().describe('Last local date, inclusive'),
        limit: z.number().int().min(1).max(100).optional(),
      },
      annotations: readOnly,
    },
    (ws, input) => tools.listWorkouts(ws, input)
  );

  tool(
    'get_workout',
    {
      title: 'Get a workout',
      description:
        'One workout set by set: loads as entered with kilograms, reps, RIR, set kinds, e1RM per set, volume per muscle and the personal records it set.',
      inputSchema: { id: z.string().describe('Workout ID from list_workouts') },
      annotations: readOnly,
    },
    (ws, input) => tools.getWorkout(ws, input)
  );

  tool(
    'exercise_history',
    {
      title: 'Exercise history',
      description:
        "An exercise's statistics (e1RM, 3RM and 10RM estimates, heaviest load, volume, reps, sets), its e1RM per workout, and recent sets. Accepts an exercise ID or name.",
      inputSchema: {
        exercise: z.string().describe('Exercise ID such as barbell-bench-press, or a name'),
        from: date.optional(),
        through: date.optional(),
        recent_sets: z.number().int().min(0).max(200).optional(),
      },
      annotations: readOnly,
    },
    (ws, input) => tools.exerciseHistory(ws, input)
  );

  tool(
    'weekly_volume',
    {
      title: 'Weekly volume per muscle',
      description:
        'Fractional hard sets and volume per muscle for recent weeks, newest first. A target muscle counts 1 per working set, a synergist 0.5.',
      inputSchema: {
        weeks: z.number().int().min(1).max(52).optional(),
        first_weekday: z.enum(['monday', 'sunday']).optional(),
        through: date.optional().describe('A date in the latest week; defaults to today'),
      },
      annotations: readOnly,
    },
    (ws, input) => tools.weeklyVolume(ws, input)
  );

  tool(
    'search_exercises',
    {
      title: 'Search exercises',
      description:
        "Exercises in Exerly's library and the person's custom ones, best match first, with muscles, equipment and how they are tracked.",
      inputSchema: {
        query: z.string().optional(),
        muscle: muscle.optional().describe('Keep exercises that target this muscle'),
        limit: z.number().int().min(1).max(50).optional(),
      },
      annotations: readOnly,
    },
    (ws, input) => tools.searchExercises(ws, input)
  );

  tool(
    'list_proposals',
    {
      title: 'List proposals',
      description:
        'Proposals filed by agents and their status: pending, accepted, rejected, undone, or stale (the data changed first).',
      inputSchema: {
        status: z.enum(['pending', 'accepted', 'rejected', 'undone', 'stale']).optional(),
        limit: z.number().int().min(1).max(100).optional(),
      },
      annotations: readOnly,
    },
    (ws, input) => tools.listProposals(ws, input)
  );

  tool(
    'list_programs',
    {
      title: 'List programs',
      description:
        "The person's training programs: which is active, cycles, deload placement, days and progress through them.",
      annotations: readOnly,
    },
    (ws) => tools.listPrograms(ws)
  );

  tool(
    'next_workout',
    {
      title: 'Next workout',
      description:
        "The next workout of the active program (or one you name): the day, cycle, whether it is a deload, and for each exercise the target and Exerly's recommended load, reps and RIR per set, with the reason (progress, hold, reduce, first session).",
      inputSchema: { program_id: z.string().optional() },
      annotations: readOnly,
    },
    (ws, input) => tools.nextWorkout(ws, input)
  );

  tool(
    'verify_metric',
    {
      title: 'Check a number',
      description:
        'Recomputes a number before you cite it. Metrics: exercise.e1rm.best and exercise.volume.total (parameters exercise, from, through), and muscle.sets.week (muscle, week, firstWeekday: 1 Sunday or 2 Monday). Exerly shows evidence whose number fails this as mismatched.',
      inputSchema: {
        name: z.enum(['exercise.e1rm.best', 'exercise.volume.total', 'muscle.sets.week']),
        parameters: z.record(z.string(), z.string()),
        claimed: z.number(),
      },
      annotations: readOnly,
    },
    (ws, input) => tools.verifyMetric(ws, input)
  );

  tool(
    'get_document',
    {
      title: 'Get a document',
      description:
        'The stored payload of a workout_session or custom_exercise, exactly as Exerly syncs it. Edit this to build the "after" of a proposal.',
      inputSchema: {
        kind: z.enum(['workout_session', 'custom_exercise', 'program']),
        id: z.string(),
      },
      annotations: readOnly,
    },
    (ws, input) => tools.getDocument(ws, input)
  );

  if (pat.scopes.includes('propose') || pat.scopes.includes('write')) {
    const metric = z.object({
      name: z.string(),
      parameters: z.record(z.string(), z.string()),
      claimed: z.number(),
    });
    tool(
      'propose',
      {
        title: 'Propose a change',
        description: `Files a change for the person to review in Exerly; nothing changes until they accept. Each change names a document (kind workout_session, custom_exercise or program, and its ID) and the full payload you propose as "after", or null to delete. To edit, read the payload with get_document, change it, and pass the whole document. Exerly fills in "before" from the stored document. Give evidence with an honest level, a confidence, and a falsifier: what would show the proposal is wrong. Cite numbers with a metric so Exerly can verify them.`,
        inputSchema: {
          title: z.string().min(1).max(120),
          summary: z.string().max(2000).optional(),
          confidence: z.enum(['low', 'medium', 'high']),
          falsifier: z.string().min(1).max(500),
          evidence: z
            .array(
              z.object({
                claim: z.string().min(1),
                level: z.enum(tools.EVIDENCE_LEVELS),
                caveats: z.array(z.string()).optional(),
                dataRefs: z.array(z.object({ kind: z.string(), id: z.string() })).optional(),
                metric: metric.optional(),
                source: z.string().optional(),
              })
            )
            .optional(),
          changes: z
            .array(
              z.object({
                kind: z.enum(['workout_session', 'custom_exercise', 'program']),
                id: z.string(),
                after: z.record(z.string(), z.unknown()).nullable(),
              })
            )
            .min(1)
            .max(20),
        },
        annotations: { readOnlyHint: false, destructiveHint: false, openWorldHint: false },
      },
      (ws, input) => tools.propose(ws, pat, input)
    );
  }
  return server;
}

router.use('/mcp', rateLimit({ name: 'mcp', max: 120, windowMs: 60 * 1000 }));

router.post(
  '/mcp',
  (req, _res, next) => {
    req.pat = { ...req.pat, via: 'mcp' };
    next();
  },
  authenticate,
  asyncHandler(
    async (req, res) => {
      if (!req.pat?.id) throw forbidden('MCP needs a personal access token (exr_…)');
      const server = buildServer(req.account, req.pat);
      const transport = new StreamableHTTPServerTransport({
        sessionIdGenerator: undefined,
        enableJsonResponse: true,
      });
      res.on('close', () => {
        transport.close();
        server.close();
      });
      await server.connect(transport);
      await transport.handleRequest(req, res, req.body);
    },
    { transactional: false }
  )
);

// Stateless: there is no stream to open and no session to end.
router.all('/mcp', (_req, res) => {
  res.set('Allow', 'POST').status(405).json({ message: 'Use POST for MCP requests' });
});

module.exports = router;
