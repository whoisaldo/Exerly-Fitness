// Program generation against the golden file ExerlyCore writes
// (apps/ios/ExerlyCore/Tests/ExerlyCoreTests/GenerationGoldenTests.swift), so
// a program an agent asks the API for is the one the app would build.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { ExerciseLibrary } = require('../lib/training/library');
const { generate } = require('../lib/training/generation');
const { programProblems } = require('../lib/training/validate');

const golden = JSON.parse(
  fs.readFileSync(
    path.join(__dirname, '..', '..', '..', 'docs/api/golden/program-generation-v1.json'),
    'utf8'
  )
);
const library = ExerciseLibrary.withCustom([]);

test('every generated program matches ExerlyCore', () => {
  assert.equal(golden.version, 1);
  assert.ok(golden.cases.length >= 280);
  for (const { request, gym, expected } of golden.cases) {
    const label = `${request.daysPerWeek} ${request.goal} ${request.experience} ${request.minutes} ${gym ? gym.equipment.length : 'any'}`;
    const result = generate(request, library, { gym });
    const { program } = result;
    assert.deepEqual(
      {
        name: program.name,
        cycles: program.cycles,
        deload: program.deload,
        days: program.days.map((day) => ({
          name: day.name,
          slots: day.slots.map((slot) => [
            slot.exerciseID,
            slot.target.sets,
            slot.target.minReps,
            slot.target.maxReps,
            slot.target.rir,
          ]),
        })),
        weeklySets: result.weeklySets,
        targets: result.targets,
        shortfalls: result.shortfalls,
      },
      expected,
      label
    );
    assert.deepEqual(programProblems(program, program.id, library), [], label);
  }
});

test('a request out of range says why, as ExerlyCore does', () => {
  assert.deepEqual(
    generate({ daysPerWeek: 7, goal: 'general', experience: 'beginner', minutes: 20 }, library),
    { problems: ['Choose 2 to 6 training days a week', 'Sessions must be 30 to 150 minutes'] }
  );
});
