import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import StepContainer from '../../../components/onboarding/StepContainer';
import GoalCard from '../../../components/onboarding/GoalCard';
import { goalRateSafety, kgToLbs, lbsToKg } from '../../../services/WizardService';
import { colors, spacing, fontSize, fontWeight, radii } from '../../../theme/colors';

const GOALS = [
  { id: 'lose_weight', icon: '\uD83D\uDD25', title: 'Lose Weight', sub: 'Burn fat, feel lighter' },
  { id: 'build_muscle', icon: '\uD83D\uDCAA', title: 'Build Muscle', sub: 'Get stronger, add mass' },
  { id: 'maintain', icon: '\u2696\uFE0F', title: 'Maintain', sub: "Keep what I've got" },
  { id: 'improve_endurance', icon: '\uD83C\uDFC3', title: 'Improve Endurance', sub: 'Run farther, last longer' },
  { id: 'improve_health', icon: '\u2764\uFE0F', title: 'Improve Health', sub: 'Feel better overall' },
];

const TIMELINES = [4, 8, 12, 16, 24];

export default function Step4Goals({ data, update }) {
  const needsTarget = data.primaryGoal === 'lose_weight' || data.primaryGoal === 'build_muscle';
  const isMetric = data.unitPreference === 'metric';
  const currentW = data.weightKg ?? 70;
  const targetW = data.targetWeightKg ?? currentW;
  const weeks = data.goalTimelineWeeks ?? 12;
  const safety = goalRateSafety(currentW, targetW, weeks);
  const stepSize = isMetric ? 0.5 : lbsToKg(1);
  const directionHint = data.primaryGoal === 'lose_weight'
    ? 'Choose a target below your current weight.'
    : 'Choose a target above your current weight.';

  const handleGoalSelect = (goalId) => {
    if (goalId === 'lose_weight') {
      const suggested = data.targetWeightKg != null && data.targetWeightKg < currentW
        ? data.targetWeightKg
        : Math.max(25, +(currentW - 5).toFixed(1));
      update({ primaryGoal: goalId, targetWeightKg: suggested });
      return;
    }

    if (goalId === 'build_muscle') {
      const suggested = data.targetWeightKg != null && data.targetWeightKg > currentW
        ? data.targetWeightKg
        : Math.min(230, +(currentW + 3).toFixed(1));
      update({ primaryGoal: goalId, targetWeightKg: suggested });
      return;
    }

    update({ primaryGoal: goalId, targetWeightKg: null });
  };

  const stepTargetWeight = (delta) => {
    const next = Math.max(25, Math.min(230, +(targetW + delta).toFixed(1)));
    update({ targetWeightKg: next });
  };

  return (
    <StepContainer title="What's your main mission?">
      {GOALS.map((g) => (
        <GoalCard
          key={g.id}
          icon={g.icon}
          title={g.title}
          subtitle={g.sub}
          selected={data.primaryGoal === g.id}
          onPress={() => handleGoalSelect(g.id)}
        />
      ))}

      {needsTarget && (
        <View style={styles.targetSection}>
          <Text style={styles.label}>Target Weight</Text>
          <View style={styles.targetRow}>
            <Pressable
              onPress={() => stepTargetWeight(-stepSize)}
              style={styles.targetStepBtn}
              accessibilityLabel="Decrease target weight"
            >
              <Text style={styles.targetStepText}>-</Text>
            </Pressable>
            <Text style={styles.targetValue}>
              {isMetric ? `${targetW} kg` : `${kgToLbs(targetW)} lbs`}
            </Text>
            <Pressable
              onPress={() => stepTargetWeight(stepSize)}
              style={styles.targetStepBtn}
              accessibilityLabel="Increase target weight"
            >
              <Text style={styles.targetStepText}>+</Text>
            </Pressable>
          </View>
          <Text style={styles.targetHint}>{directionHint}</Text>

          <Text style={styles.label}>Timeline</Text>
          <View style={styles.timeRow}>
            {TIMELINES.map((w) => (
              <Pressable
                key={w}
                onPress={() => update({ goalTimelineWeeks: w })}
                style={[styles.timePill, weeks === w && styles.timePillActive]}
                accessibilityRole="radio"
                accessibilityState={{ selected: weeks === w }}
              >
                <Text style={[styles.timeText, weeks === w && styles.timeTextActive]}>
                  {w}w
                </Text>
              </Pressable>
            ))}
          </View>

          <View style={[styles.safetyBadge, { backgroundColor: safety.label === 'healthy' ? `${colors.success}22` : safety.label === 'aggressive' ? `${colors.warning}22` : `${colors.error}22` }]}>
            <Text style={[styles.safetyText, { color: safety.label === 'healthy' ? colors.success : safety.label === 'aggressive' ? colors.warning : colors.error }]}>
              {safety.weeklyKg.toFixed(2)} kg/week — {safety.label}
            </Text>
          </View>
        </View>
      )}
    </StepContainer>
  );
}

export function validate(data) {
  if (!data.primaryGoal) return false;

  const needsTarget = data.primaryGoal === 'lose_weight' || data.primaryGoal === 'build_muscle';
  if (!needsTarget) return true;

  if (!data.targetWeightKg || !data.goalTimelineWeeks) return false;
  if (data.primaryGoal === 'lose_weight') return data.targetWeightKg < data.weightKg;
  return data.targetWeightKg > data.weightKg;
}

const styles = StyleSheet.create({
  targetSection: { marginTop: spacing.lg },
  label: {
    color: colors.textSecondary,
    fontSize: fontSize.xs,
    fontWeight: fontWeight.semibold,
    textTransform: 'uppercase',
    letterSpacing: 1,
    marginBottom: spacing.sm,
    marginTop: spacing.md,
  },
  targetValue: {
    color: colors.textPrimary,
    fontSize: fontSize['2xl'],
    fontWeight: fontWeight.bold,
    textAlign: 'center',
  },
  targetRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.lg,
  },
  targetStepBtn: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: colors.surface2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  targetStepText: {
    color: colors.primary,
    fontSize: fontSize.lg,
    fontWeight: fontWeight.bold,
  },
  targetHint: {
    color: colors.textMuted,
    fontSize: fontSize.xs,
    textAlign: 'center',
    marginTop: spacing.sm,
  },
  timeRow: { flexDirection: 'row', gap: spacing.sm },
  timePill: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: radii.full,
    backgroundColor: colors.surface2,
    alignItems: 'center',
    minHeight: 44,
    justifyContent: 'center',
  },
  timePillActive: { backgroundColor: `${colors.primary}22`, borderWidth: 1, borderColor: colors.primary },
  timeText: { color: colors.textMuted, fontSize: fontSize.sm, fontWeight: fontWeight.semibold },
  timeTextActive: { color: colors.primary },
  safetyBadge: {
    marginTop: spacing.md,
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: radii.md,
    alignItems: 'center',
  },
  safetyText: { fontSize: fontSize.sm, fontWeight: fontWeight.medium },
});
