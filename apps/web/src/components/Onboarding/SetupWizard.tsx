import {
  useEffect,
  useState,
  useSyncExternalStore,
  type InputHTMLAttributes,
  type ReactNode,
} from 'react';
import { useSession, useSessionScope, acceptSetupCompletion } from '../../hooks/useSession';
import { AppShell } from '../ui/AppShell';
import { ConfirmAction } from '../ui/ConfirmAction';
import { cn } from '../../lib/cn';
import { SetupStore } from './setupStore';
import {
  activityLevels,
  contentSignature,
  fitnessGoals,
  type SetupAnswers,
  type SetupStatus,
  type SetupTargets,
} from './setupTypes';
import type { SessionUser } from '../../hooks/useSession';

const input =
  'min-h-11 w-full rounded-lg border border-white/20 bg-surface-2 px-3 py-2 text-slate-100 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/40';
const secondary =
  'min-h-11 rounded-lg border border-white/20 px-4 text-sm text-slate-100 disabled:opacity-50';
const primary =
  'min-h-11 rounded-lg bg-violet-600 px-5 text-sm font-semibold text-white disabled:opacity-50';
const stepNames = ['Your name', 'Starting point', 'Your goals', 'Daily activity', 'Review targets'];

function Field({
  label,
  id,
  children,
  help,
}: {
  label: string;
  id: string;
  children: ReactNode;
  help?: string;
}) {
  return (
    <div className="space-y-2">
      <label htmlFor={id} className="block text-sm font-medium text-slate-200">
        {label}
      </label>
      {children}
      {help && (
        <p id={`${id}-help`} className="text-pretty text-sm text-slate-400">
          {help}
        </p>
      )}
    </div>
  );
}

function NumberField({
  label,
  id,
  value,
  onValue,
  ...props
}: Omit<InputHTMLAttributes<HTMLInputElement>, 'onChange' | 'value' | 'id'> & {
  label: string;
  id: string;
  value: number | null;
  onValue: (value: number) => void;
}) {
  return (
    <Field label={label} id={id}>
      <input
        step="any"
        {...props}
        id={id}
        className={cn(input, 'tabular-nums')}
        type="number"
        inputMode="decimal"
        value={value ?? ''}
        onChange={(event) => onValue(event.target.value === '' ? 0 : Number(event.target.value))}
      />
    </Field>
  );
}

function TargetList({ targets }: { targets: SetupTargets }) {
  return (
    <dl className="grid grid-cols-2 gap-4 tabular-nums sm:grid-cols-4">
      {(
        [
          ['Calories', targets.calories, 'kcal'],
          ['Protein', targets.protein_g, 'g'],
          ['Carbohydrate', targets.carbs_g, 'g'],
          ['Fat', targets.fat_g, 'g'],
        ] as const
      ).map(([label, value, unit]) => (
        <div key={label}>
          <dt className="text-sm text-slate-400">{label}</dt>
          <dd className="mt-1 text-xl font-semibold text-slate-100">
            {value.toLocaleString()}{' '}
            <span className="text-sm font-normal text-slate-400">{unit}</span>
          </dd>
        </div>
      ))}
    </dl>
  );
}

function AnswerSummary({
  answers,
  details = false,
}: {
  answers: Partial<SetupAnswers>;
  details?: boolean;
}) {
  return (
    <>
      <dl className="grid grid-cols-2 gap-x-4 gap-y-2 text-sm tabular-nums">
        {[
          ['Name', answers.name || 'Not entered'],
          ['Age', answers.age || 'Not entered'],
          ['Gender identity', answers.gender || 'Not chosen'],
          ['Height', answers.height ? `${answers.height} cm` : 'Not entered'],
          ['Weight', answers.weight ? `${answers.weight} kg` : 'Not entered'],
          [
            'Fitness goal',
            fitnessGoals.find(([value]) => value === answers.goal)?.[1] ??
              answers.goal ??
              'Not chosen',
          ],
          [
            'Nutrition goal',
            (
              { lose: 'Lose weight', maintain: 'Maintain weight', gain: 'Gain weight' } as Record<
                string,
                string
              >
            )[answers.nutritionGoal ?? ''] ?? 'Not chosen',
          ],
          [
            'Target weight',
            answers.targetWeight == null ? 'Not set' : `${answers.targetWeight} kg`,
          ],
          [
            'Activity',
            activityLevels.find(([value]) => value === answers.activityLevel)?.[1] ??
              answers.activityLevel ??
              'Not chosen',
          ],
          [
            'Calculation',
            answers.targetMode === 'manual' ? 'Manual targets' : answers.sex || 'Not chosen',
          ],
        ].map(([label, value]) => (
          <div key={String(label)}>
            <dt className="text-slate-400">{label}</dt>
            <dd className="break-words text-slate-100">{value}</dd>
          </div>
        ))}
      </dl>
      {details && (
        <details className="mt-4 text-sm text-slate-300">
          <summary className="min-h-11 cursor-pointer py-3">Preferences and targets</summary>
          <dl className="space-y-3 tabular-nums">
            {[
              ['Time zone', answers.timezone ?? 'Not saved'],
              ['Display units', answers.unitSystem ?? 'Not saved'],
              ['Diet', answers.dietaryStyle ?? 'Not saved'],
              ['Allergies', answers.allergies?.join(', ') || 'None saved'],
              ['Equipment', answers.equipment?.join(', ') || 'None saved'],
              ['Equipment access', answers.equipmentAccess ?? 'Not saved'],
              ['Activities', answers.activityTypes?.join(', ') || 'None saved'],
              ['Experience', answers.experienceLevel ?? 'Not saved'],
              ['Workout days', answers.workoutDays?.join(', ') || 'None saved'],
              ['Workouts per week', answers.workoutDaysPerWeek ?? 'Not saved'],
              ['Meals per day', answers.mealsPerDay ?? 'Not saved'],
              [
                'Sleep goal',
                answers.sleepGoalHours == null ? 'Not saved' : `${answers.sleepGoalHours} hours`,
              ],
              ['Bedtime', answers.bedtime ?? 'Not saved'],
              ['Wake time', answers.wakeTime ?? 'Not saved'],
              [
                'Timeline',
                answers.timelineWeeks == null ? 'Not saved' : `${answers.timelineWeeks} weeks`,
              ],
              [
                'Reminders enabled',
                Object.entries(answers.reminders ?? {})
                  .filter(([, enabled]) => enabled)
                  .map(([name]) => name)
                  .join(', ') || 'None saved',
              ],
            ].map(([label, value]) => (
              <div key={String(label)}>
                <dt className="text-slate-400">{label}</dt>
                <dd className="break-words">{value}</dd>
              </div>
            ))}
          </dl>
          {answers.manualTargets && (
            <div className="mt-4">
              <p className="mb-3 text-pretty">Manual daily targets</p>
              <TargetList targets={answers.manualTargets} />
            </div>
          )}
        </details>
      )}
    </>
  );
}

export default function SetupWizard() {
  const { user, setup } = useSession();
  const scope = useSessionScope();
  if (!user?._id || !scope || !setup)
    return (
      <AppShell>
        <p role="status">Loading saved setup…</p>
      </AppShell>
    );
  return <OwnedSetup key={`${scope}:${user._id}`} user={user} scope={scope} status={setup} />;
}

function OwnedSetup({
  user,
  scope,
  status,
}: {
  user: SessionUser;
  scope: string;
  status: SetupStatus;
}) {
  const [store] = useState(() => new SetupStore(user._id!, scope, user, status));
  const state = useSyncExternalStore(store.subscribe, store.getSnapshot);
  const content = state.saved.content;
  const a = content.answers;
  const step = content.last_valid_step;
  const locked = state.submitting || !!state.saved.submission || !state.readable;
  const position = store.steps.indexOf(step);
  const signature = contentSignature(a);
  const preview = state.preview?.signature === signature ? state.preview : null;
  useEffect(() => {
    store.start();
    return () => store.stop();
  }, [store]);
  useEffect(() => {
    if (step === 4 && !state.saved.submission && !state.conflict) void store.preview();
  }, [store, step, signature, state.saved.submission, state.conflict]);
  useEffect(() => {
    if (state.complete) acceptSetupCompletion(scope, state.complete);
  }, [scope, state.complete]);
  const imperial = a.unitSystem === 'imperial';
  const weightUnit = imperial ? 'lb' : 'kg';
  const displayWeight = (kg: number | null) =>
    kg == null ? null : imperial ? Number((kg / 0.45359237).toFixed(8)) : kg;
  const weight = (display: number) => (imperial ? display * 0.45359237 : display);
  const updateTarget = (key: keyof SetupTargets, value: number) =>
    store.edit({
      manualTargets: {
        calories: 0,
        protein_g: 0,
        carbs_g: 0,
        fat_g: 0,
        fiber_g: 30,
        ...a.manualTargets,
        [key]: value,
      },
    });
  const otherDrafts = store.otherDrafts();

  return (
    <AppShell>
      <div className="mx-auto max-w-2xl">
        <header className="mb-6">
          <p className="text-sm text-slate-400">
            {store.repair ? 'Complete your saved account' : 'Set up your account'} · Step{' '}
            {position + 1} of {store.steps.length}
          </p>
          <h1 className="mt-2 text-balance text-3xl font-semibold text-slate-50">
            {stepNames[step]}
          </h1>
          <p className="mt-3 text-pretty text-sm text-slate-300">
            Your answers stay saved as you go. You can return to an earlier step before finishing.
          </p>
        </header>
        <div className="mb-5 flex flex-wrap items-center justify-between gap-3 border-b border-white/10 pb-4">
          <p role="status" className="text-pretty text-sm text-slate-400">
            {state.syncing ? 'Syncing saved answers…' : (state.message ?? 'Saved in this browser.')}
          </p>
          <button
            type="button"
            className={secondary}
            disabled={state.syncing || locked || !!state.conflict}
            onClick={() => {
              void store.sync();
            }}
          >
            Retry sync
          </button>
        </div>
        {state.error && (
          <div
            id="setup-error"
            role="alert"
            className="mb-5 rounded-xl border border-red-400/30 bg-red-950/30 p-4 text-pretty text-sm text-red-300"
          >
            {state.error}
            {!state.readable && (
              <button
                type="button"
                className={cn(secondary, 'mt-3 block')}
                onClick={() => window.location.reload()}
              >
                Reload saved setup
              </button>
            )}
          </div>
        )}
        {state.conflict && (
          <section
            aria-label="Setup conflict"
            className="mb-6 space-y-5 rounded-xl border border-amber-400/30 p-5"
          >
            <h2 className="text-balance text-lg font-semibold">Setup changed on another device</h2>
            <p className="text-pretty text-sm text-slate-300">
              Choose which answers to continue with. Neither version will be applied as your final
              setup until you review and finish.
            </p>
            <div className="grid gap-6 sm:grid-cols-2">
              <div>
                <h3 className="mb-3 font-medium">This browser</h3>
                <AnswerSummary answers={a} details />
              </div>
              <div>
                <h3 className="mb-3 font-medium">Saved on your account</h3>
                <AnswerSummary answers={state.conflict.answers} details />
              </div>
            </div>
            <div className="flex flex-wrap gap-3">
              <ConfirmAction
                trigger={
                  <button type="button" className={primary}>
                    Keep these browser answers
                  </button>
                }
                title="Continue with these browser answers?"
                description="This replaces the reviewed cloud draft. Your final setup is still saved only when you finish."
                action="Use browser answers"
                onConfirm={() => {
                  void store.resolve(false);
                }}
              />
              <ConfirmAction
                trigger={
                  <button type="button" className={secondary}>
                    Use saved account answers
                  </button>
                }
                title="Continue with the account draft?"
                description="This replaces the answers open in this browser with the reviewed account draft."
                action="Use account answers"
                onConfirm={() => {
                  void store.resolve(true);
                }}
              />
            </div>
          </section>
        )}
        <form
          aria-label="Account setup"
          aria-describedby={state.error ? 'setup-error' : undefined}
          onSubmit={(event) => {
            event.preventDefault();
            if (step === 4) void store.finish();
            else store.go(store.steps[position + 1] ?? 4);
          }}
          className="space-y-6 rounded-xl border border-white/10 bg-surface-1 p-5 sm:p-6"
        >
          <fieldset disabled={locked} className="space-y-5">
            {step === 0 && (
              <Field label="Name" id="setup-name">
                <input
                  id="setup-name"
                  className={input}
                  autoComplete="name"
                  maxLength={80}
                  required
                  value={a.name}
                  onChange={(event) => store.edit({ name: event.target.value })}
                />
              </Field>
            )}
            {step === 1 && (
              <>
                <div className="grid gap-5 sm:grid-cols-2">
                  <NumberField
                    id="setup-age"
                    label="Age"
                    value={a.age || null}
                    min={18}
                    max={120}
                    step={1}
                    required
                    onValue={(age) => store.edit({ age })}
                  />
                  <Field label="Gender identity" id="setup-gender">
                    <select
                      id="setup-gender"
                      className={input}
                      value={a.gender}
                      onChange={(event) => store.edit({ gender: event.target.value })}
                      required
                    >
                      <option value="">Choose an answer</option>
                      <option value="female">Female</option>
                      <option value="male">Male</option>
                      <option value="other">Another identity</option>
                      <option value="prefer_not_to_say">Prefer not to say</option>
                      {a.gender &&
                        !['female', 'male', 'other', 'prefer_not_to_say'].includes(a.gender) && (
                          <option value={a.gender}>{a.gender}</option>
                        )}
                    </select>
                  </Field>
                </div>
                <Field label="Display units" id="setup-units">
                  <select
                    id="setup-units"
                    className={input}
                    value={a.unitSystem}
                    onChange={(event) =>
                      store.edit({ unitSystem: event.target.value as 'metric' | 'imperial' })
                    }
                  >
                    <option value="metric">Metric, kg and cm</option>
                    <option value="imperial">Imperial, lb and inches</option>
                  </select>
                </Field>
                <div className="grid gap-5 sm:grid-cols-2">
                  <NumberField
                    id="setup-height"
                    label={`Height (${imperial ? 'in' : 'cm'})`}
                    value={
                      a.height ? (imperial ? Number((a.height / 2.54).toFixed(8)) : a.height) : null
                    }
                    required
                    min={imperial ? 50 / 2.54 : 50}
                    max={imperial ? 280 / 2.54 : 280}
                    onValue={(height) => store.edit({ height: imperial ? height * 2.54 : height })}
                  />
                  <NumberField
                    id="setup-weight"
                    label={`Weight (${weightUnit})`}
                    value={a.weight ? displayWeight(a.weight) : null}
                    required
                    min={displayWeight(20)!}
                    max={displayWeight(500)!}
                    onValue={(value) => store.edit({ weight: weight(value) })}
                  />
                </div>
                <Field label="Daily targets" id="setup-target-mode">
                  <select
                    id="setup-target-mode"
                    className={input}
                    value={a.targetMode}
                    onChange={(event) => store.edit({ targetMode: event.target.value })}
                  >
                    <option value="estimated">Review an estimate</option>
                    <option value="manual">Enter my own targets</option>
                  </select>
                </Field>
                {a.targetMode === 'manual' ? (
                  <div className="grid gap-5 sm:grid-cols-2">
                    <NumberField
                      id="manual-calories"
                      label="Daily calories (kcal)"
                      min={800}
                      max={10000}
                      required
                      value={a.manualTargets?.calories || null}
                      onValue={(value) => updateTarget('calories', value)}
                    />
                    <NumberField
                      id="manual-protein"
                      label="Protein (g)"
                      min={0}
                      max={500}
                      required
                      value={a.manualTargets?.protein_g ?? null}
                      onValue={(value) => updateTarget('protein_g', value)}
                    />
                    <NumberField
                      id="manual-carbs"
                      label="Carbohydrate (g)"
                      min={0}
                      max={1500}
                      required
                      value={a.manualTargets?.carbs_g ?? null}
                      onValue={(value) => updateTarget('carbs_g', value)}
                    />
                    <NumberField
                      id="manual-fat"
                      label="Fat (g)"
                      min={0}
                      max={500}
                      required
                      value={a.manualTargets?.fat_g ?? null}
                      onValue={(value) => updateTarget('fat_g', value)}
                    />
                  </div>
                ) : (
                  <Field
                    label="Calculation parameter"
                    id="setup-sex"
                    help="The energy estimate uses one of these physiological parameters. This is separate from gender identity. You can enter your own targets instead."
                  >
                    <select
                      id="setup-sex"
                      className={input}
                      aria-describedby="setup-sex-help"
                      value={a.sex ?? ''}
                      onChange={(event) => store.edit({ sex: event.target.value || null })}
                      required
                    >
                      <option value="">Choose a parameter</option>
                      <option value="female">Female parameter</option>
                      <option value="male">Male parameter</option>
                    </select>
                  </Field>
                )}
              </>
            )}
            {step === 2 && (
              <>
                <Field label="Fitness goal" id="setup-goal">
                  <select
                    id="setup-goal"
                    className={input}
                    value={a.goal}
                    required
                    onChange={(event) => {
                      const goal = event.target.value;
                      store.edit({
                        goal,
                        ...(!a.goal
                          ? {
                              nutritionGoal:
                                goal === 'lose_weight'
                                  ? 'lose'
                                  : goal === 'gain_muscle'
                                    ? 'gain'
                                    : 'maintain',
                            }
                          : {}),
                      });
                    }}
                  >
                    <option value="">Choose your goal</option>
                    {fitnessGoals.map(([value, label]) => (
                      <option key={value} value={value}>
                        {label}
                      </option>
                    ))}
                  </select>
                </Field>
                <Field
                  label="Nutrition goal"
                  id="setup-nutrition-goal"
                  help="Your nutrition goal can differ from your training goal."
                >
                  <select
                    id="setup-nutrition-goal"
                    className={input}
                    aria-describedby="setup-nutrition-goal-help"
                    value={a.nutritionGoal}
                    onChange={(event) =>
                      store.edit({
                        nutritionGoal: event.target.value,
                        ...(event.target.value === 'maintain' ? { targetWeight: null } : {}),
                      })
                    }
                  >
                    <option value="lose">Lose weight</option>
                    <option value="maintain">Maintain weight</option>
                    <option value="gain">Gain weight</option>
                  </select>
                </Field>
                {a.nutritionGoal !== 'maintain' && (
                  <NumberField
                    id="setup-target-weight"
                    label={`Target weight (${weightUnit})`}
                    required
                    min={displayWeight(20)!}
                    max={displayWeight(500)!}
                    value={displayWeight(a.targetWeight)}
                    onValue={(value) => store.edit({ targetWeight: weight(value) })}
                  />
                )}
              </>
            )}
            {step === 3 && (
              <>
                <Field
                  label="Usual activity level"
                  id="setup-activity"
                  help="Choose the level that describes your usual week. This helps set the initial estimate."
                >
                  <select
                    id="setup-activity"
                    className={input}
                    aria-describedby="setup-activity-help"
                    value={a.activityLevel}
                    required
                    onChange={(event) => store.edit({ activityLevel: event.target.value })}
                  >
                    <option value="">Choose your activity level</option>
                    {activityLevels.map(([value, label]) => (
                      <option key={value} value={value}>
                        {label}
                      </option>
                    ))}
                  </select>
                </Field>
                <Field
                  label="Time zone"
                  id="setup-timezone"
                  help="Your diary uses this time zone to assign entries to a calendar day."
                >
                  <input
                    id="setup-timezone"
                    className={input}
                    value={a.timezone}
                    aria-describedby="setup-timezone-help"
                    onChange={(event) => store.edit({ timezone: event.target.value })}
                    required
                  />
                </Field>
              </>
            )}
            {step === 4 && (
              <>
                <AnswerSummary answers={a} />
                <section
                  aria-label="Target preview"
                  className="space-y-4 border-y border-white/10 py-5"
                >
                  <h2 className="text-balance text-lg font-semibold">Daily targets</h2>
                  {preview ? (
                    <>
                      <TargetList targets={preview.targets} />
                      <p className="text-pretty text-sm text-slate-400">
                        {a.targetMode === 'manual'
                          ? 'These are the targets you entered.'
                          : 'This is the server calculation for the answers above.'}
                        {preview.maintenance != null && (
                          <>
                            {' '}
                            Estimated daily energy use: {preview.maintenance.toLocaleString()} kcal.
                          </>
                        )}
                      </p>
                    </>
                  ) : (
                    <p className="text-pretty text-sm text-slate-400">
                      {state.saved.submission
                        ? 'Your submission is saved. Retry to check whether setup finished.'
                        : 'Connect to load the current target preview before finishing.'}
                    </p>
                  )}
                  {!state.saved.submission && (
                    <button
                      type="button"
                      className={secondary}
                      disabled={state.syncing || !!state.conflict}
                      onClick={() => {
                        void store.preview();
                      }}
                    >
                      Refresh target preview
                    </button>
                  )}
                </section>
                <details className="text-sm text-slate-300">
                  <summary className="cursor-pointer py-3">Saved preferences</summary>
                  <p className="mt-3 text-pretty">
                    Existing preferences from your saved draft are kept when you finish.
                  </p>
                  <dl className="mt-3 space-y-2">
                    <div>
                      <dt>Diet</dt>
                      <dd>{a.dietaryStyle}</dd>
                    </div>
                    <div>
                      <dt>Allergies</dt>
                      <dd>{a.allergies.join(', ') || 'None saved'}</dd>
                    </div>
                    <div>
                      <dt>Equipment</dt>
                      <dd>{a.equipment.join(', ') || 'None saved'}</dd>
                    </div>
                    <div>
                      <dt>Sleep preference</dt>
                      <dd>
                        {a.sleepGoalHours} hours · {a.bedtime ?? 'No bedtime saved'} ·{' '}
                        {a.wakeTime ?? 'No wake time saved'}
                      </dd>
                    </div>
                  </dl>
                </details>
              </>
            )}
          </fieldset>
          <div className="flex flex-wrap items-center justify-between gap-3 border-t border-white/10 pt-5">
            <button
              type="button"
              className={secondary}
              disabled={position <= 0 || locked}
              onClick={() => store.go(store.steps[position - 1])}
            >
              Back
            </button>
            <button
              type="submit"
              className={primary}
              disabled={
                state.submitting ||
                !state.readable ||
                !!state.conflict ||
                (step === 4 && !preview && !state.saved.submission)
              }
            >
              {state.submitting
                ? 'Checking saved setup…'
                : step === 4
                  ? state.saved.submission
                    ? 'Retry finish'
                    : 'Finish setup'
                  : 'Continue'}
            </button>
          </div>
        </form>
        {otherDrafts.length > 0 && (
          <details className="mt-6 rounded-xl border border-white/10 p-4 text-sm">
            <summary className="cursor-pointer py-2 text-slate-300">
              Other saved browser drafts
            </summary>
            <p className="my-3 text-pretty text-slate-400">
              These answers remain on this browser. Resuming a draft keeps the account revision
              check.
            </p>
            <ul className="space-y-3">
              {otherDrafts.slice(0, 10).map(({ key, draft }) => (
                <li key={key}>
                  <ConfirmAction
                    trigger={
                      <button type="button" className={secondary} disabled={locked}>
                        Resume draft from {new Date(draft.updatedAt).toLocaleString()}
                      </button>
                    }
                    title="Resume these saved answers?"
                    description="This changes the answers open in this tab. You will review any cloud conflict before finishing."
                    action="Resume draft"
                    onConfirm={() => store.resumeDraft(key)}
                  />
                </li>
              ))}
            </ul>
          </details>
        )}
      </div>
    </AppShell>
  );
}
