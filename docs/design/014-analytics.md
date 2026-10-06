# M7: custom metrics, tags, correlations and n=1 experiments

Owner: logic agent. Status: statistics built and measured; data model next, 2026-10-06. PARITY B08 and B09.

Optimizers want to know why their numbers move. Exerly answers with their own
data, and says honestly how little one person's data can show.

## Data (synced documents)

- **`custom_metric`**: a metric the person defines. It has a name, a unit, a
  kind (a number, a 1–5 scale, or yes/no), an optional range, and archived.
  Examples: sleep quality, soreness, steps typed in, mood.
- **`metric_entry`**: one value of a custom metric on a local date. A metric
  has at most one value per day, and the ID is derived from the metric and
  the date, so two devices logging the same day converge.
- **Tags**: free-text labels on a day ("travel", "late caffeine",
  "creatine"), stored on `nutrition_day` as `tags`. Tags are yes/no series.
- **`experiment`**: a question with a metric, a baseline phase and an
  intervention phase (dates), what's being changed, and a status.

## Daily series

`MetricSeries` builds one value per local date from:

- nutrition: energy, protein, any nutrient, on counted days only (design 013);
- body: trend weight and scale weight;
- training: the best e1RM per session for an exercise, and weekly fractional
  sets for a muscle;
- custom metrics and tags.

Missing days stay missing, never zero.

## Correlations (B09)

For two series, Spearman's rank correlation at lags of 0 to 3 days, over days
both have.

- At least 14 paired days, or the result is "not enough data".
- Days in a row aren't independent. Bartlett's effective sample size,
  n(1 − r₁ₓr₁ᵧ)/(1 + r₁ₓr₁ᵧ), sets both the t test and a Fisher-z interval.
  A moving-block bootstrap was tried first. It took minutes for a
  simulation, and it was too slow for a phone screen as well.
- When many pairs are tested at once, p-values are adjusted with
  Benjamini–Hochberg. A result is called clear only if the adjusted value is
  under 0.05 and the interval excludes zero.
- Every result says "n=1, observational: this shows association, not cause".

## Experiments (B08)

Compare the metric's mean in the intervention phase with the baseline.

- The effect is the difference of means, with a 95 % Welch interval. Each
  phase's variance is inflated for its lag-1 autocorrelation r, after
  correcting r's small-sample bias of about (1 + 3r)/n.
- Each phase needs at least 7 values.
- The verdict is "clear increase", "clear decrease", "no clear difference" or
  "not enough data".
- Caveats always include no blinding, possible trend over time, and anything
  else that changed (other tags that differ between the phases).

## Checked against simulated data

AR(1) noise with unit variance: 400 runs per row, seeded (2026-10-06).

Experiments, phases of equal length:

| Persistence | Days per phase | False "clear" | Finds 0.5 SD   | Finds 1 SD      |
| ----------- | -------------- | ------------- | -------------- | --------------- |
| 0           | 14 / 21 / 42   | 3 / 5 / 3 %   | 12 / 26 / 54 % | 53 / 79 / 100 % |
| 0.5         | 14 / 21 / 42   | 4 / 5 / 5 %   | 7 / 10 / 20 %  | 19 / 27 / 66 %  |
| 0.8         | 14 / 21 / 42   | 7 / 4 / 4 %   | 7 / 7 / 8 %    | 12 / 12 / 19 %  |

Correlations, persistence 0.6, any of four lags after adjustment:

| Days | False "clear" | Finds ρ ≈ 0.6 | Finds ρ ≈ 0.3 |
| ---- | ------------- | ------------- | ------------- |
| 30   | 3 %           | 50 %          | 8 %           |
| 60   | 4 %           | 87 %          | 22 %          |
| 90   | 3 %           | 98 %          | 31 %          |

- Ignoring autocorrelation, a plain t test calls 26 % of no-effect
  experiments clear. That is the trap these numbers avoid.
- An n=1 experiment on a persistent outcome needs about six weeks per phase
  to find an effect of one standard deviation two times in three. Exerly
  should say so when one is set up.
- The tests hold the 60-day correlation and 42-day experiment rates, and the
  two-week false rate, as bounds.
