import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import * as Haptics from 'expo-haptics';
import StepContainer from '../../../components/onboarding/StepContainer';
import GoalCard from '../../../components/onboarding/GoalCard';
import { colors, spacing, fontSize, fontWeight, radii } from '../../../theme/colors';

const LEVELS = [
  { id: 'sedentary', icon: '\uD83D\uDECB', title: 'Sedentary', sub: 'Desk job, little to no exercise', pal: 1.2 },
  { id: 'lightly_active', icon: '\uD83D\uDEB6', title: 'Lightly Active', sub: 'Light exercise 1-3x/week', pal: 1.375 },
  { id: 'moderately_active', icon: '\uD83C\uDFC3', title: 'Moderately Active', sub: 'Exercise 3-5x/week', pal: 1.55 },
  { id: 'very_active', icon: '\u26A1', title: 'Very Active', sub: 'Hard exercise 6-7x/week', pal: 1.725 },
  { id: 'athlete', icon: '\uD83C\uDFC6', title: 'Athlete', sub: 'Physical job or 2x/day training', pal: 1.9 },
];

export default function Step5ActivityLevel({ data, update }) {
  const wpw = data.workoutsPerWeek ?? 3;
  const selected = LEVELS.find((l) => l.id === data.fitnessLevel);

  return (
    <StepContainer
      title="How active are you right now?"
      subtitle="Be honest — we'll calibrate everything around this"
    >
      {LEVELS.map((l) => (
        <GoalCard
          key={l.id}
          icon={l.icon}
          title={l.title}
          subtitle={l.sub}
          selected={data.fitnessLevel === l.id}
          onPress={() => update({ fitnessLevel: l.id })}
        />
      ))}

      <Text style={styles.label}>Workouts per week</Text>
      <View style={styles.wpwRow}>
        <Pressable
          onPress={() => { Haptics.selectionAsync(); update({ workoutsPerWeek: Math.max(wpw - 1, 0) }); }}
          style={styles.stepBtn}
          accessibilityLabel="Decrease workouts"
        >
          <Text style={styles.stepBtnText}>-</Text>
        </Pressable>
        <Text style={styles.wpwValue}>{wpw}</Text>
        <Pressable
          onPress={() => { Haptics.selectionAsync(); update({ workoutsPerWeek: Math.min(wpw + 1, 7) }); }}
          style={styles.stepBtn}
          accessibilityLabel="Increase workouts"
        >
          <Text style={styles.stepBtnText}>+</Text>
        </Pressable>
      </View>
      {selected && (
        <Text style={styles.palText}>Activity multiplier: {selected.pal}x</Text>
      )}
    </StepContainer>
  );
}

export function validate(data) {
  return !!data.fitnessLevel;
}

const styles = StyleSheet.create({
  label: {
    color: colors.textSecondary,
    fontSize: fontSize.xs,
    fontWeight: fontWeight.semibold,
    textTransform: 'uppercase',
    letterSpacing: 1,
    marginTop: spacing.xl,
    marginBottom: spacing.sm,
  },
  wpwRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.lg,
  },
  stepBtn: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: colors.surface2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stepBtnText: { color: colors.primary, fontSize: fontSize.lg, fontWeight: fontWeight.bold },
  wpwValue: {
    color: colors.textPrimary,
    fontSize: fontSize['3xl'],
    fontWeight: fontWeight.bold,
    minWidth: 40,
    textAlign: 'center',
  },
  palText: {
    color: colors.textMuted,
    fontSize: fontSize.xs,
    textAlign: 'center',
    marginTop: spacing.sm,
  },
});
