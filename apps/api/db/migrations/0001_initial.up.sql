-- Initial schema: one table per collection in data/schema.js.
-- id is the public identity; seq keeps insertion order for sorting.
-- Legacy camelCase columns are quoted so their case survives.

CREATE TABLE sync_cursors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  account_id text,
  sequence double precision
);
CREATE UNIQUE INDEX sync_cursors_0 ON sync_cursors (account_id);

CREATE TABLE sync_changes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  account_id text,
  sequence double precision,
  kind text,
  entity_id text,
  server_id text,
  revision double precision,
  deleted boolean,
  payload jsonb,
  created_at timestamptz
);
CREATE UNIQUE INDEX sync_changes_0 ON sync_changes (account_id, sequence);

CREATE TABLE sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  account_id text,
  session_id text,
  refresh_hash text,
  previous_refresh_hash text,
  previous_operation text,
  generation double precision,
  credentials_version double precision,
  device_name text,
  created_at timestamptz,
  updated_at timestamptz,
  expires_at timestamptz,
  revoked_at timestamptz
);
CREATE UNIQUE INDEX sessions_0 ON sessions (session_id);
CREATE INDEX sessions_1 ON sessions (account_id);

CREATE TABLE provider_budgets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  key text,
  count double precision,
  blocked_until timestamptz,
  created_at timestamptz
);
CREATE UNIQUE INDEX provider_budgets_0 ON provider_budgets (key);

CREATE TABLE operations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  account_id text,
  key text,
  fingerprint text,
  status double precision,
  response jsonb,
  created_at timestamptz
);
CREATE UNIQUE INDEX operations_0 ON operations (account_id, key);

CREATE TABLE onboarding_drafts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  account_id text,
  schema_version double precision,
  revision double precision,
  last_valid_step double precision,
  answers jsonb,
  updated_at timestamptz
);
CREATE UNIQUE INDEX onboarding_drafts_0 ON onboarding_drafts (account_id);

CREATE TABLE diary_days (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  email text,
  account_id text,
  entry_date text,
  status text,
  note text,
  revision double precision,
  updated_at timestamptz
);
CREATE UNIQUE INDEX diary_days_0 ON diary_days (email, entry_date);

CREATE TABLE target_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  email text,
  account_id text,
  effective_date text,
  targets jsonb,
  reason text,
  checkin_id text,
  created_at timestamptz
);
CREATE INDEX target_versions_0 ON target_versions (email, effective_date, created_at DESC);

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  name text,
  email text,
  hash text,
  profile jsonb,
  preferences_revision double precision,
  preferences_updated_at timestamptz,
  is_admin boolean,
  created_at timestamptz,
  "onboardingCompleted" boolean,
  onboarding_version double precision,
  onboarding_completed_at timestamptz,
  credentials_version double precision,
  email_verified_at timestamptz,
  age double precision,
  gender text,
  height double precision,
  weight double precision,
  goal text,
  "experienceLevel" text,
  "workoutDaysPerWeek" double precision,
  "equipmentAccess" text,
  timezone text,
  "unitSystem" text,
  "aiCreditsRemaining" double precision,
  "aiDailyCreditsUsed" double precision,
  "aiLastCreditReset" timestamptz,
  "aiDailyResetDate" timestamptz
);
CREATE UNIQUE INDEX users_0 ON users (email);

CREATE TABLE measurements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  account_id text,
  client_id text,
  type text,
  value double precision,
  unit text,
  entered_value double precision,
  entered_unit text,
  entry_date text,
  timezone text,
  note text,
  source text,
  revision double precision,
  deleted_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
);
CREATE UNIQUE INDEX measurements_0 ON measurements (account_id, client_id);
CREATE INDEX measurements_1 ON measurements (account_id, entry_date);

CREATE TABLE activities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  email text,
  account_id text,
  client_id text,
  identity_key text,
  revision double precision,
  revision_locked boolean,
  deleted_at timestamptz,
  updated_at timestamptz,
  activity text,
  duration_min double precision,
  calories double precision,
  intensity text,
  type text,
  entry_date text,
  created_at timestamptz
);
CREATE INDEX activities_0 ON activities (email, entry_date);
CREATE UNIQUE INDEX activities_1 ON activities (identity_key);

CREATE TABLE food (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  email text,
  account_id text,
  client_id text,
  revision double precision,
  revision_locked boolean,
  deleted_at timestamptz,
  updated_at timestamptz,
  name text,
  calories double precision,
  protein double precision,
  carbs double precision,
  fat double precision,
  fiber double precision,
  sugar double precision,
  sodium double precision,
  saturated_fat double precision,
  servings double precision,
  serving_size text,
  serving_unit text,
  nutrition_snapshot jsonb,
  entered_quantity jsonb,
  nutrition_basis jsonb,
  source text,
  meal_type text,
  barcode text,
  brand text,
  food_id text,
  entry_date text,
  logged_at timestamptz,
  created_at timestamptz
);
CREATE INDEX food_0 ON food (email, entry_date);
CREATE INDEX food_1 ON food (barcode);
CREATE UNIQUE INDEX food_2 ON food (account_id, client_id);

CREATE TABLE sleep (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  email text,
  account_id text,
  client_id text,
  identity_key text,
  revision double precision,
  revision_locked boolean,
  deleted_at timestamptz,
  updated_at timestamptz,
  hours double precision,
  quality text,
  bedtime text,
  wake_time text,
  entry_date text,
  created_at timestamptz
);
CREATE INDEX sleep_0 ON sleep (email, entry_date);
CREATE UNIQUE INDEX sleep_1 ON sleep (identity_key);

CREATE TABLE weights (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  account_id text,
  revision double precision,
  revision_locked boolean,
  deleted_at timestamptz,
  updated_at timestamptz,
  email text,
  weight_kg double precision,
  body_fat_pct double precision,
  note text,
  source text,
  entry_date text,
  created_at timestamptz
);
CREATE UNIQUE INDEX weights_0 ON weights (email, entry_date);

CREATE TABLE goals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  email text,
  daily_calories double precision,
  protein_g double precision,
  carbs_g double precision,
  fat_g double precision,
  fiber_g double precision,
  weekly_workouts double precision,
  daily_steps double precision,
  weekly_weight double precision,
  sleep_hours double precision,
  water_ml double precision,
  updated_at timestamptz
);
CREATE UNIQUE INDEX goals_0 ON goals (email);

CREATE TABLE programs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  email text,
  goal_type text,
  target_mode text,
  rate_kg_per_week double precision,
  target_weight_kg double precision,
  protein_strategy text,
  fat_strategy text,
  diet_type text,
  calories double precision,
  protein_g double precision,
  carbs_g double precision,
  fat_g double precision,
  expenditure double precision,
  expenditure_confidence text,
  last_checkin_date text,
  active boolean,
  created_at timestamptz,
  updated_at timestamptz
);
CREATE UNIQUE INDEX programs_0 ON programs (email);

CREATE TABLE checkins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  email text,
  entry_date text,
  expenditure double precision,
  expenditure_confidence text,
  mean_intake double precision,
  trend_weight_kg double precision,
  trend_change_kg double precision,
  days_logged double precision,
  window_days double precision,
  calories double precision,
  protein_g double precision,
  carbs_g double precision,
  fat_g double precision,
  previous_calories double precision,
  note text,
  created_at timestamptz
);
CREATE UNIQUE INDEX checkins_0 ON checkins (email, entry_date);

CREATE TABLE library_foods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  email text,
  name text,
  brand text,
  barcode text,
  calories double precision,
  protein double precision,
  carbs double precision,
  fat double precision,
  fiber double precision,
  sugar double precision,
  sodium double precision,
  saturated_fat double precision,
  serving_size text,
  serving_unit text,
  serving_grams double precision,
  nutrition_basis jsonb,
  portions jsonb,
  missing_nutrients jsonb,
  fetched_at timestamptz,
  region text,
  source text,
  is_favorite boolean,
  use_count double precision,
  last_used timestamptz,
  created_at timestamptz
);
CREATE INDEX library_foods_0 ON library_foods (email, name);
CREATE INDEX library_foods_1 ON library_foods (email, last_used DESC);

CREATE TABLE recipes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  email text,
  name text,
  ingredients jsonb,
  servings double precision,
  note text,
  created_at timestamptz,
  updated_at timestamptz
);
CREATE INDEX recipes_0 ON recipes (email, name);

CREATE TABLE workouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  email text,
  name text,
  exercises jsonb,
  created_at timestamptz,
  updated_at timestamptz
);
CREATE INDEX workouts_0 ON workouts (email);

CREATE TABLE water (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  account_id text,
  revision double precision,
  email text,
  entry_date text,
  ml double precision,
  updated_at timestamptz
);
CREATE UNIQUE INDEX water_0 ON water (email, entry_date);

CREATE TABLE ai_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  email text,
  "userId" text,
  type text,
  prompt text,
  response text,
  applied boolean,
  "createdAt" timestamptz
);
CREATE INDEX ai_plans_0 ON ai_plans (email, "createdAt" DESC);

CREATE TABLE ai_errors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  email text,
  "userId" text,
  "sessionId" text,
  "errorType" text,
  "errorCode" text,
  "errorMessage" text,
  "errorDetails" jsonb,
  "userAgent" text,
  "ipAddress" text,
  "requestData" jsonb,
  "responseData" jsonb,
  "stackTrace" text,
  severity text,
  status text,
  "adminNotes" text,
  "resolvedBy" text,
  "resolvedAt" timestamptz,
  created_at timestamptz,
  updated_at timestamptz
);
CREATE INDEX ai_errors_0 ON ai_errors (created_at DESC);
CREATE INDEX ai_errors_1 ON ai_errors (status);

CREATE TABLE barcode_cache (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  barcode text,
  name text,
  brand text,
  calories double precision,
  protein double precision,
  carbs double precision,
  fat double precision,
  fiber double precision,
  sugar double precision,
  sodium double precision,
  saturated_fat double precision,
  serving_size text,
  nutrition_basis jsonb,
  portions jsonb,
  missing_nutrients jsonb,
  region text,
  source text,
  fetched_at timestamptz,
  expires_at timestamptz
);
CREATE UNIQUE INDEX barcode_cache_0 ON barcode_cache (barcode);
