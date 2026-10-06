// A port of ExerlyCore's EnergyBalance: trend weight and expenditure from
// weigh-ins and logged intake, by a Kalman filter and Rauch–Tung–Striebel
// smoother over weight without water (W), expenditure in logged kcal (E) and
// the water deviation (A). It follows the Swift code step for step, and
// tests/nutrition.golden.test.js holds it to docs/api/golden/nutrition-v1.json,
// which ExerlyCore writes. See docs/design/007-nutrition.md.

const PARAMETERS = {
  energyDensity: 7700,
  expenditureDrift: 15,
  expenditurePerKilogram: 22,
  weightDrift: 0.01,
  water: 0.5,
  waterPersistence: 0.8,
  scale: 0.15,
  unloggedIntake: 600,
};

// Small fixed-size linear algebra, in the Swift code's order of operations.
const add = (l, r) => l.map((row, i) => row.map((value, j) => value + r[i][j]));
const subtract = (l, r) => l.map((row, i) => row.map((value, j) => value - r[i][j]));
const scale = (m, s) => m.map((row) => row.map((value) => value * s));
const multiply = (l, r) =>
  [0, 1, 2].map((i) =>
    [0, 1, 2].map((j) => [0, 1, 2].reduce((sum, k) => sum + l[i][k] * r[k][j], 0))
  );
const apply = (m, v) => [0, 1, 2].map((i) => [0, 1, 2].reduce((sum, k) => sum + m[i][k] * v[k], 0));
const transpose = (m) => [0, 1, 2].map((j) => [0, 1, 2].map((i) => m[i][j]));
const diagonal = (a, b, c) => [
  [a, 0, 0],
  [0, b, 0],
  [0, 0, c],
];
const outer = (a, b) => a.map((x) => b.map((y) => x * y));
const IDENTITY = diagonal(1, 1, 1);

function inverse(m) {
  const det =
    m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
    m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
    m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
  const c = [
    [
      m[1][1] * m[2][2] - m[1][2] * m[2][1],
      m[0][2] * m[2][1] - m[0][1] * m[2][2],
      m[0][1] * m[1][2] - m[0][2] * m[1][1],
    ],
    [
      m[1][2] * m[2][0] - m[1][0] * m[2][2],
      m[0][0] * m[2][2] - m[0][2] * m[2][0],
      m[0][2] * m[1][0] - m[0][0] * m[1][2],
    ],
    [
      m[1][0] * m[2][1] - m[1][1] * m[2][0],
      m[0][1] * m[2][0] - m[0][0] * m[2][1],
      m[0][0] * m[1][1] - m[0][1] * m[1][0],
    ],
  ];
  return scale(c, 1 / det);
}

const mean = (values) =>
  values.length ? values.reduce((sum, value) => sum + value, 0) / values.length : null;

function nextDate(date) {
  const day = new Date(`${date}T00:00:00Z`);
  day.setUTCDate(day.getUTCDate() + 1);
  return day.toISOString().slice(0, 10);
}

/**
 * Smoothed estimates for every day from the first weigh-in on. Each day is
 * { date: 'YYYY-MM-DD', intake: kcal or null when not complete, weights: [kg] }.
 * `prior` is { mean, error } for expenditure; without one it starts at
 * 31 kcal per kilogram, ±600.
 */
function estimate(days, { prior = null, parameters = {} } = {}) {
  const p = { ...PARAMETERS, ...parameters };
  const sorted = [...days].sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0));
  const firstIndex = sorted.findIndex((day) => day.weights.length > 0);
  if (firstIndex < 0) return [];
  // Fill gaps so every calendar day is a step.
  const series = [];
  for (const day of sorted.slice(firstIndex)) {
    while (series.length && nextDate(series.at(-1).date) < day.date) {
      series.push({ date: nextDate(series.at(-1).date), intake: null, weights: [] });
    }
    const last = series.at(-1);
    if (last?.date === day.date) {
      last.weights = [...last.weights, ...day.weights];
      if (day.intake != null) last.intake = day.intake;
    } else {
      series.push({ date: day.date, intake: day.intake ?? null, weights: [...day.weights] });
    }
  }
  const firstWeight = mean(series[0].weights);
  const start = prior ?? { mean: 31 * firstWeight, error: 600 };
  let x = [firstWeight, start.mean, 0];
  let P = diagonal(p.water * p.water, start.error * start.error, p.water * p.water);
  const coupling = p.expenditurePerKilogram / p.energyDensity;
  const F = [
    [1, -1 / p.energyDensity, 0],
    [0, 1 - coupling, 0],
    [0, 0, p.waterPersistence],
  ];
  const intakeEffect = [1 / p.energyDensity, coupling, 0];
  const waterNoise = p.water * p.water * (1 - p.waterPersistence * p.waterPersistence);

  const filtered = [];
  const predicted = [];
  let recentIntake = [];
  series.forEach((day, index) => {
    if (index > 0) {
      const previous = series[index - 1];
      let intake;
      let intakeVariance = 0;
      if (previous.intake != null) {
        intake = previous.intake;
        recentIntake = [...recentIntake, previous.intake].slice(-7);
      } else {
        intake = mean(recentIntake) ?? x[1];
        intakeVariance = p.unloggedIntake * p.unloggedIntake;
      }
      const moved = apply(F, x);
      x = moved.map((value, i) => value + intakeEffect[i] * intake);
      P = add(
        add(
          multiply(multiply(F, P), transpose(F)),
          diagonal(
            p.weightDrift * p.weightDrift,
            p.expenditureDrift * p.expenditureDrift,
            waterNoise
          )
        ),
        scale(outer(intakeEffect, intakeEffect), intakeVariance)
      );
    }
    predicted.push({ x, P });
    const reading = mean(day.weights);
    if (reading != null) {
      // y = W + A, with the scale's error shrinking over several readings.
      const r = (p.scale * p.scale) / day.weights.length;
      const innovation = reading - (x[0] + x[2]);
      const s = P[0][0] + 2 * P[0][2] + P[2][2] + r;
      const gain = [P[0][0] + P[0][2], P[1][0] + P[1][2], P[2][0] + P[2][2]].map((g) => g / s);
      x = x.map((value, i) => value + gain[i] * innovation);
      P = multiply(subtract(IDENTITY, outer(gain, [1, 0, 1])), P);
      P = scale(add(P, transpose(P)), 0.5);
    }
    filtered.push({ x, P });
  });

  // Rauch–Tung–Striebel smoothing, backwards.
  const smoothed = [...filtered];
  for (let index = series.length - 2; index >= 0; index--) {
    const { x: xf, P: Pf } = filtered[index];
    const { x: xp, P: Pp } = predicted[index + 1];
    const gain = multiply(multiply(Pf, transpose(F)), inverse(Pp));
    const difference = smoothed[index + 1].x.map((value, i) => value - xp[i]);
    const correction = apply(gain, difference);
    const xs = xf.map((value, i) => value + correction[i]);
    const Ps = add(
      Pf,
      multiply(multiply(gain, subtract(smoothed[index + 1].P, Pp)), transpose(gain))
    );
    smoothed[index] = { x: xs, P: scale(add(Ps, transpose(Ps)), 0.5) };
  }
  return series.map((day, index) => {
    const { x: state, P: covariance } = smoothed[index];
    return {
      date: day.date,
      trend: state[0],
      trendError: Math.sqrt(Math.max(0, covariance[0][0])),
      expenditure: state[1],
      expenditureError: Math.sqrt(Math.max(0, covariance[1][1])),
      weight: mean(day.weights),
      intake: day.intake,
    };
  });
}

module.exports = { PARAMETERS, estimate };
