import { useEffect, useState, useSyncExternalStore } from 'react';
import { Link } from 'react-router-dom';
import { acceptProfile, useSession, useSessionScope } from '../../hooks/useSession';
import { AppShell } from '../ui/AppShell';
import { ConfirmAction } from '../ui/ConfirmAction';
import { activityLevels } from '../Onboarding/setupTypes';
import { PreferencesStore } from './preferencesStore';
import { changesFor, describe, labels, type Value } from './preferences';

const control =
  'min-h-11 w-full rounded-lg border border-white/20 bg-surface-2 px-3 py-2 text-slate-100 focus:outline-none focus:ring-2 focus:ring-primary-bright';
const button = 'min-h-11 rounded-lg border border-white/20 px-4 text-sm disabled:opacity-50';
const primary =
  'min-h-11 rounded-lg bg-violet-600 px-5 font-semibold text-white disabled:opacity-50';
const weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
const capital = (value: string) => value.charAt(0).toUpperCase() + value.slice(1);

export default function ProfilePage() {
  const { user } = useSession();
  const scope = useSessionScope();
  return (
    <AppShell>
      {user?._id && scope ? (
        <Editor key={`${scope}:${user._id}`} accountID={user._id} scope={scope} />
      ) : (
        <p role="status">Loading account…</p>
      )}
    </AppShell>
  );
}
function Editor({ accountID, scope }: { accountID: string; scope: string }) {
  const [store] = useState(() => new PreferencesStore(accountID, scope));
  const state = useSyncExternalStore(store.subscribe, store.getSnapshot);
  const draft = state.draft;
  const fields = draft?.fields ?? {};
  const locked = state.saving || !!draft?.pending || !state.readable;
  useEffect(() => {
    store.start();
    return () => store.stop();
  }, [store]);
  useEffect(() => {
    if (state.accepted) acceptProfile(scope, state.accepted.user);
  }, [state.accepted, scope]);
  const edit = (key: string, value: string) => store.edit(key, value);
  function textField(
    key: string,
    options: {
      label?: string;
      numeric?: boolean;
      multiline?: boolean;
      help?: string;
      time?: boolean;
      required?: boolean;
    } = {}
  ) {
    const id = `preference-${key}`;
    const props = {
      id,
      className: control,
      value: fields[key] ?? '',
      onChange: (event: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) =>
        edit(key, event.target.value),
      'aria-describedby': options.help ? `${id}-help` : undefined,
    };
    return (
      <div key={key} className="space-y-2">
        <label htmlFor={id} className="block text-sm font-medium">
          {options.label ?? labels[key]}
        </label>
        {options.multiline ? (
          <textarea {...props} rows={3} />
        ) : (
          <input
            {...props}
            type={options.time ? 'time' : 'text'}
            inputMode={options.numeric ? 'decimal' : undefined}
            required={options.required}
            autoComplete={key === 'name' ? 'name' : 'off'}
          />
        )}
        {options.help && (
          <p id={`${id}-help`} className="text-pretty text-sm text-slate-400">
            {options.help}
          </p>
        )}
      </div>
    );
  }
  function select(key: string, options: readonly (readonly [string, string])[]) {
    const value = fields[key] ?? '';
    return (
      <div className="space-y-2">
        <label htmlFor={`preference-${key}`} className="block text-sm font-medium">
          {labels[key]}
        </label>
        <select
          id={`preference-${key}`}
          className={control}
          value={value}
          onChange={(event) => edit(key, event.target.value)}
        >
          <option value="">Not set</option>
          {options.map(([key, label]) => (
            <option key={key} value={key}>
              {label}
            </option>
          ))}
          {value && !options.some(([key]) => key === value) && (
            <option value={value}>{value}</option>
          )}
        </select>
      </div>
    );
  }
  let changed: Record<string, Value> = {};
  try {
    if (draft) changed = changesFor(draft.base, draft.fields, draft.heightCM);
  } catch {
    /* Validation is presented when saving. */
  }
  const otherDrafts = store.otherDrafts();
  return (
    <div className="mx-auto max-w-3xl">
      <header className="mb-6">
        <h1 className="text-balance text-3xl font-semibold">Profile and preferences</h1>
        <p className="mt-3 text-pretty text-slate-300">
          Keep your food, training and sleep preferences together. Changes apply after you save.
        </p>
      </header>
      <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
        <p role="status" className="text-pretty text-sm text-slate-400">
          {state.saving
            ? 'Saving preferences…'
            : state.loading
              ? 'Refreshing preferences…'
              : (state.message ?? 'Load your saved preferences to begin.')}
        </p>
        <button
          className={button}
          type="button"
          disabled={state.loading || state.saving || !state.readable}
          onClick={() => {
            void store.load();
          }}
        >
          Refresh preferences
        </button>
      </div>
      {state.error && (
        <p
          id="preferences-error"
          role="alert"
          className="mb-5 rounded-lg border border-red-400/30 p-4 text-pretty text-red-300"
        >
          {state.error}
        </p>
      )}
      {state.conflict && draft && (
        <section
          aria-label="Preference conflict"
          className="mb-6 space-y-4 rounded-xl border border-amber-400/30 p-5"
        >
          <h2 className="text-balance text-xl font-semibold">
            Preferences changed on another device
          </h2>
          <p className="text-pretty text-sm text-slate-300">
            Review your edits against the saved account. Saving your edits keeps any other account
            preferences.
          </p>
          <dl className="space-y-4 text-sm">
            {Object.entries(changed).map(([key, value]) => (
              <div key={key}>
                <dt className="font-semibold">{labels[key] ?? capital(key)}</dt>
                <dd className="mt-1 break-words text-slate-300">Your edit: {describe(value)}</dd>
                <dd className="mt-1 break-words text-slate-300">
                  Saved on account: {describe(state.conflict!.values[key])}
                </dd>
              </div>
            ))}
          </dl>
          <div className="flex flex-wrap gap-3">
            <ConfirmAction
              trigger={
                <button className={primary} type="button">
                  Save my edits
                </button>
              }
              title="Save these preference edits?"
              description="Only the edits shown here will replace the reviewed account values. Other saved preferences will stay as they are."
              action="Save reviewed edits"
              onConfirm={() => {
                void store.resolve(false);
              }}
            />
            <ConfirmAction
              trigger={
                <button className={button} type="button">
                  Use account preferences
                </button>
              }
              title="Use the saved account preferences?"
              description="This replaces the open draft with the account version shown here."
              action="Use saved preferences"
              onConfirm={() => {
                void store.resolve(true);
              }}
            />
          </div>
        </section>
      )}
      {draft && (
        <form
          aria-label="Profile preferences"
          aria-describedby={state.error ? 'preferences-error' : undefined}
          onSubmit={(event) => {
            event.preventDefault();
            void store.save();
          }}
          className="space-y-6"
        >
          <fieldset disabled={locked} className="space-y-6">
            <section
              aria-labelledby="profile-basics"
              className="space-y-5 rounded-xl border border-white/10 bg-surface-1 p-5"
            >
              <h2 id="profile-basics" className="text-balance text-xl font-semibold">
                About you
              </h2>
              {textField('name', { required: true })}
              <div className="grid gap-5 sm:grid-cols-2">
                {textField('age', { numeric: true })}
                {textField('gender', {
                  help: 'Gender identity is separate from the physiological parameter used for a nutrition estimate.',
                })}
              </div>
              {select('unitSystem', [
                ['metric', 'Metric, kg and cm'],
                ['imperial', 'Imperial, lb and inches'],
              ])}
              {textField('height', {
                numeric: true,
                label: `Height (${fields.unitSystem === 'imperial' ? 'in' : 'cm'})`,
              })}
              {select('activityLevel', activityLevels)}
              {textField('timezone', {
                help: 'Use a time zone such as America/New_York. Existing log dates stay unchanged.',
              })}
              <p className="text-pretty text-sm text-slate-400">
                Log new weight readings in{' '}
                <Link className="underline" to="/dashboard/weight">
                  Weight
                </Link>
                . Review nutrition goals and accepted targets in{' '}
                <Link className="underline" to="/dashboard/program">
                  Program
                </Link>
                .
              </p>
            </section>
            <section
              aria-labelledby="profile-food"
              className="space-y-5 rounded-xl border border-white/10 bg-surface-1 p-5"
            >
              <h2 id="profile-food" className="text-balance text-xl font-semibold">
                Food preferences
              </h2>
              {textField('dietaryStyle', { help: 'For example, vegetarian or Mediterranean.' })}
              {textField('allergies', {
                multiline: true,
                help: 'One per line. These are your saved preferences; check food labels when choosing products.',
              })}
              {textField('mealsPerDay', { numeric: true })}
            </section>
            <section
              aria-labelledby="profile-training"
              className="space-y-5 rounded-xl border border-white/10 bg-surface-1 p-5"
            >
              <h2 id="profile-training" className="text-balance text-xl font-semibold">
                Training preferences
              </h2>
              {select('experienceLevel', [
                ['beginner', 'Beginner'],
                ['intermediate', 'Intermediate'],
                ['advanced', 'Advanced'],
              ])}
              {select('equipmentAccess', [
                ['bodyweight', 'Bodyweight'],
                ['home', 'Home'],
                ['full_gym', 'Gym'],
              ])}
              {textField('equipment', {
                multiline: true,
                help: 'One item per line. Existing equipment names are kept.',
              })}
              {textField('activityTypes', { multiline: true, help: 'One activity per line.' })}
              {textField('workoutDaysPerWeek', { numeric: true })}
              <fieldset>
                <legend className="mb-2 text-sm font-medium">Workout days</legend>
                <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
                  {weekdays.map((day) => (
                    <label className="flex min-h-11 items-center gap-3" key={day}>
                      <input
                        type="checkbox"
                        checked={(fields.workoutDays ?? '').split('\n').includes(day)}
                        onChange={(event) => {
                          const days = new Set(
                            (fields.workoutDays ?? '').split('\n').filter(Boolean)
                          );
                          if (event.target.checked) days.add(day);
                          else days.delete(day);
                          edit('workoutDays', weekdays.filter((day) => days.has(day)).join('\n'));
                        }}
                      />
                      {capital(day)}
                    </label>
                  ))}
                </div>
              </fieldset>
            </section>
            <section
              aria-labelledby="profile-sleep"
              className="space-y-5 rounded-xl border border-white/10 bg-surface-1 p-5"
            >
              <h2 id="profile-sleep" className="text-balance text-xl font-semibold">
                Sleep preferences
              </h2>
              {textField('sleepGoalHours', { numeric: true })}
              <div className="grid gap-5 sm:grid-cols-2">
                {textField('bedtime', { time: true })}
                {textField('wakeTime', { time: true })}
              </div>
              <p className="text-pretty text-sm text-slate-400">
                The sleep goal updates your daily goal. Preferred times do not create sleep entries.
              </p>
            </section>
            <section
              aria-labelledby="profile-reminders"
              className="space-y-5 rounded-xl border border-white/10 bg-surface-1 p-5"
            >
              <h2 id="profile-reminders" className="text-balance text-xl font-semibold">
                Reminder preferences
              </h2>
              <p className="text-pretty text-sm text-slate-400">
                These choices are shared with your iPhone. Notification delivery is enabled
                separately on each device.
              </p>
              {['meals', 'workouts', 'sleep'].map((kind) => (
                <label key={kind} className="flex min-h-11 items-center gap-3">
                  <input
                    type="checkbox"
                    checked={fields[`reminders.${kind}`] === 'true'}
                    onChange={(event) => edit(`reminders.${kind}`, String(event.target.checked))}
                  />
                  {labels[`reminders.${kind}`]}
                </label>
              ))}
              {textField('reminderTimes.meals', {
                multiline: true,
                help: 'One 24-hour time per line, such as 08:30.',
              })}
              <div className="grid gap-5 sm:grid-cols-2">
                {textField('reminderTimes.workout', { time: true })}
                {textField('reminderTimes.sleep', { time: true })}
              </div>
            </section>
          </fieldset>
          {draft.pending && (
            <p className="text-pretty text-sm text-slate-300">
              Your last save has not been confirmed. Retry it before editing these preferences.
            </p>
          )}
          <button
            type="submit"
            className={primary}
            disabled={state.saving || !state.readable || !!state.conflict}
          >
            {state.saving ? 'Saving…' : draft.pending ? 'Retry save' : 'Save preferences'}
          </button>
        </form>
      )}
      {otherDrafts.length > 0 && (
        <details className="mt-6 rounded-xl border border-white/10 p-4 text-sm">
          <summary className="min-h-11 cursor-pointer py-3">Other saved preference drafts</summary>
          <ul className="space-y-3">
            {otherDrafts.slice(0, 10).map(({ key, draft }) => (
              <li key={key}>
                <ConfirmAction
                  trigger={
                    <button className={button} type="button" disabled={locked || state.loading}>
                      Resume draft from {new Date(draft.updatedAt).toLocaleString()}
                    </button>
                  }
                  title="Resume these preference edits?"
                  description="This restores the saved draft in this tab. You can review it before saving it to your account."
                  action="Resume draft"
                  onConfirm={() => store.resume(key)}
                />
              </li>
            ))}
          </ul>
        </details>
      )}
    </div>
  );
}
