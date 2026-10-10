// A program day counts as done, and the program moves on, once at least half
// its planned working sets are done, as ExerlyCore's ProgramSchedule decides.

const test = require('node:test');
const assert = require('node:assert/strict');
const progression = require('../lib/training/progression');

const target = (sets) => ({ sets, minReps: 6, maxReps: 10, rir: 2, kind: 'standard' });
const program = {
  id: 'P',
  name: 'Synthetic split',
  cycles: 2,
  days: ['Push', 'Pull', 'Legs'].map((name, i) => ({
    id: `D${i}`,
    name,
    slots: [
      { id: `S${i}a`, exerciseID: 'bench-press', target: target(4), cycleTargets: {} },
      { id: `S${i}b`, exerciseID: 'back-squat', target: target(4), cycleTargets: {} },
    ],
  })),
};

/** A session of a day with `done` working sets and a warm-up, all completed. */
function session(day, done, startedAt) {
  const sets = Array.from({ length: done }, () => ({ kind: 'standard', completedAt: startedAt }));
  return {
    id: `${day}-${startedAt}`,
    startedAt,
    program: { programID: 'P', dayID: `D${day}`, cycle: 0 },
    exercises: [{ sets: [{ kind: 'warmUp', completedAt: startedAt }, ...sets] }],
  };
}

test('a workout cut short leaves its day next; half the sets moves the program on', () => {
  const push = session(0, 8, '2026-10-05T17:00:00.000Z');
  assert.equal(progression.nextPosition(program, [push]).day.name, 'Pull');

  const shortPull = session(1, 2, '2026-10-07T17:00:00.000Z');
  assert.equal(
    progression.completes(program, shortPull),
    false,
    '2 of 8; the warm-up does not count'
  );
  assert.equal(progression.nextPosition(program, [push, shortPull]).day.name, 'Pull');

  const halfPull = session(1, 4, '2026-10-08T17:00:00.000Z');
  assert.equal(progression.completes(program, halfPull), true);
  assert.equal(progression.nextPosition(program, [push, shortPull, halfPull]).day.name, 'Legs');

  const removed = {
    ...session(1, 1, '2026-10-09T17:00:00.000Z'),
    program: { programID: 'P', dayID: 'gone', cycle: 0 },
  };
  assert.equal(progression.completes(program, removed), true, 'A day since removed counts');
  assert.equal(progression.completes(program, { ...push, program: undefined }), false);
});
