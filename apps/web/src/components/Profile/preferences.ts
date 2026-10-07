import type { SessionUser } from '../../hooks/useSession';

export type Value = string | number | boolean | null | Value[] | { [key: string]: Value };
export interface Preferences {
  schema_version: 1;
  account_id: string;
  revision: number;
  values: Record<string, Value>;
  user: SessionUser;
}
export const labels: Record<string, string> = {
  name: 'Name',
  age: 'Age',
  gender: 'Gender identity',
  height: 'Height',
  activityLevel: 'Usual activity level',
  timezone: 'Time zone',
  unitSystem: 'Display units',
  dietaryStyle: 'Diet preference',
  allergies: 'Allergies',
  mealsPerDay: 'Meals per day',
  experienceLevel: 'Training experience',
  equipmentAccess: 'Training location',
  equipment: 'Available equipment',
  activityTypes: 'Preferred activities',
  workoutDays: 'Workout days',
  workoutDaysPerWeek: 'Weekly workout goal',
  sleepGoalHours: 'Sleep goal (hours)',
  bedtime: 'Preferred bedtime',
  wakeTime: 'Preferred wake time',
  'reminders.meals': 'Meal reminders',
  'reminders.workouts': 'Workout reminders',
  'reminders.sleep': 'Sleep reminders',
  'reminderTimes.meals': 'Meal reminder times',
  'reminderTimes.workout': 'Workout reminder time',
  'reminderTimes.sleep': 'Sleep reminder time',
};
export const listFields = [
  'allergies',
  'equipment',
  'activityTypes',
  'workoutDays',
  'reminderTimes.meals',
];
export const numericFields = ['age', 'mealsPerDay', 'workoutDaysPerWeek', 'sleepGoalHours'];
export const signature = (value: unknown): string =>
  JSON.stringify(value, (_key, item) =>
    item && typeof item === 'object' && !Array.isArray(item)
      ? Object.fromEntries(
          Object.keys(item)
            .sort()
            .map((key) => [key, item[key]])
        )
      : item
  );
export function number(text: string): number | null {
  const value = text.trim().replace(',', '.');
  return /^\d+(?:\.\d*)?$/.test(value) && Number.isFinite(Number(value)) ? Number(value) : null;
}
export function heightText(cm: number | null, units: string): string {
  return cm == null ? '' : String(Number((units === 'imperial' ? cm / 2.54 : cm).toFixed(8)));
}
export function fieldsFor(snapshot: Preferences): Record<string, string> {
  const fields: Record<string, string> = {};
  for (const key of Object.keys(labels)) {
    const [group, child] = key.split('.');
    const value = child
      ? (snapshot.values[group] as Record<string, Value> | null)?.[child]
      : snapshot.values[key];
    fields[key] = Array.isArray(value) ? value.join('\n') : value == null ? '' : String(value);
    if (key.startsWith('reminders.')) fields[key] = value === true ? 'true' : 'false';
  }
  fields.height = heightText(
    typeof snapshot.values.height === 'number' ? snapshot.values.height : null,
    fields.unitSystem
  );
  return fields;
}
export function changesFor(
  base: Preferences,
  fields: Record<string, string>,
  heightCM: number | null
): Record<string, Value> {
  const before = fieldsFor(base);
  const changes: Record<string, Value> = {};
  for (const key of Object.keys(labels)) {
    if (key === 'height') {
      if (fields.height.trim() && number(fields.height) == null)
        throw new Error('Enter a valid height.');
      if (heightCM !== base.values.height) changes.height = heightCM;
      continue;
    }
    if (fields[key] === before[key]) continue;
    let value: Value = fields[key].trim() || null;
    if (numericFields.includes(key)) {
      if (value != null && number(String(value)) == null)
        throw new Error(`Enter a valid number for ${labels[key].toLowerCase()}.`);
      value = value == null ? null : number(String(value));
    } else if (listFields.includes(key))
      value = [
        ...new Set(
          fields[key]
            .split('\n')
            .map((item) => item.trim())
            .filter(Boolean)
        ),
      ];
    else if (key.startsWith('reminders.')) value = fields[key] === 'true';
    const [group, child] = key.split('.');
    if (child)
      changes[group] = { ...(changes[group] as Record<string, Value> | undefined), [child]: value };
    else changes[key] = value;
  }
  return changes;
}
export function describe(value: Value | undefined): string {
  if (value == null || value === '') return 'Not set';
  if (Array.isArray(value)) return value.map(describe).join(', ') || 'None';
  if (typeof value === 'boolean') return value ? 'On' : 'Off';
  if (typeof value === 'object')
    return Object.entries(value)
      .map(([key, item]) => `${labels[`reminders.${key}`] ?? key}: ${describe(item)}`)
      .join('; ');
  return String(value);
}
