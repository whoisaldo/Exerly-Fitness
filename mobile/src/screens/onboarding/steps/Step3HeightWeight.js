import React, { useMemo } from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import * as Haptics from 'expo-haptics';
import StepContainer from '../../../components/onboarding/StepContainer';
import GlassCard from '../../../components/GlassCard';
import {
  calcBMI,
  bmiCategory,
  lbsToKg,
  kgToLbs,
  cmToFtIn,
} from '../../../services/WizardService';
import { colors, spacing, fontSize, fontWeight, radii } from '../../../theme/colors';

function Stepper({ value, onDec, onInc, label }) {
  return (
    <View style={styles.stepperGroup}>
      <Text style={styles.stepperLabel}>{label}</Text>
      <View style={styles.stepperRow}>
        <Pressable onPress={onDec} style={styles.stepBtn} accessibilityLabel={`Decrease ${label}`}>
          <Text style={styles.stepBtnText}>-</Text>
        </Pressable>
        <Text style={styles.stepValue}>{value}</Text>
        <Pressable onPress={onInc} style={styles.stepBtn} accessibilityLabel={`Increase ${label}`}>
          <Text style={styles.stepBtnText}>+</Text>
        </Pressable>
      </View>
    </View>
  );
}

export default function Step3HeightWeight({ data, update }) {
  const isMetric = data.unitPreference === 'metric';
  const heightCm = data.heightCm ?? 170;
  const weightKg = data.weightKg ?? 70;
  const { ft, in: inch } = cmToFtIn(heightCm);

  const toggle = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    update({ unitPreference: isMetric ? 'imperial' : 'metric' });
  };

  const bmi = useMemo(() => calcBMI(weightKg, heightCm), [weightKg, heightCm]);
  const cat = bmiCategory(bmi);

  const stepH = (delta) => {
    Haptics.selectionAsync();
    update({ heightCm: Math.max(100, Math.min(250, heightCm + delta)) });
  };
  const stepImperialHeight = (deltaInches) => {
    Haptics.selectionAsync();
    const currentTotalInches = Math.round(heightCm / 2.54);
    const nextTotalInches = Math.max(39, Math.min(98, currentTotalInches + deltaInches));
    update({ heightCm: +(nextTotalInches * 2.54).toFixed(1) });
  };
  const stepW = (delta) => {
    Haptics.selectionAsync();
    update({ weightKg: Math.max(25, Math.min(230, +(weightKg + delta).toFixed(1))) });
  };

  return (
    <StepContainer title="Height & Weight" subtitle="We use this to calculate your nutrition targets">
      <View style={styles.toggleRow}>
        <Pressable onPress={toggle} style={styles.togglePill}>
          <View style={[styles.toggleItem, !isMetric && styles.toggleActive]}>
            <Text style={[styles.toggleText, !isMetric && styles.toggleTextActive]}>Imperial</Text>
          </View>
          <View style={[styles.toggleItem, isMetric && styles.toggleActive]}>
            <Text style={[styles.toggleText, isMetric && styles.toggleTextActive]}>Metric</Text>
          </View>
        </Pressable>
      </View>

      <Text style={styles.sectionLabel}>Height</Text>
      {isMetric ? (
        <Stepper
          value={`${heightCm} cm`}
          onDec={() => stepH(-1)}
          onInc={() => stepH(1)}
          label="Height"
        />
      ) : (
        <View style={styles.impRow}>
          <Stepper
            value={`${ft} ft`}
            onDec={() => stepImperialHeight(-12)}
            onInc={() => stepImperialHeight(12)}
            label="Feet"
          />
          <Stepper
            value={`${inch} in`}
            onDec={() => stepImperialHeight(-1)}
            onInc={() => stepImperialHeight(1)}
            label="Inches"
          />
        </View>
      )}

      <Text style={styles.sectionLabel}>Weight</Text>
      <Stepper
        value={isMetric ? `${weightKg} kg` : `${kgToLbs(weightKg)} lbs`}
        onDec={() => stepW(isMetric ? -0.5 : -lbsToKg(1))}
        onInc={() => stepW(isMetric ? 0.5 : lbsToKg(1))}
        label="Weight"
      />

      <GlassCard style={styles.bmiCard}>
        <Text style={styles.bmiTitle}>BMI Preview</Text>
        <Text style={[styles.bmiValue, { color: cat.color }]}>{bmi}</Text>
        <Text style={[styles.bmiCat, { color: cat.color }]}>{cat.label}</Text>
        <Text style={styles.bmiNote}>Just for reference — we don't judge here</Text>
      </GlassCard>
    </StepContainer>
  );
}

export function validate(data) {
  return data.heightCm >= 100 && data.heightCm <= 250 && data.weightKg >= 25 && data.weightKg <= 230;
}

const styles = StyleSheet.create({
  toggleRow: { alignItems: 'center', marginBottom: spacing.lg },
  togglePill: {
    flexDirection: 'row',
    backgroundColor: colors.surface1,
    borderRadius: radii.md,
    padding: 3,
  },
  toggleItem: {
    paddingVertical: 8,
    paddingHorizontal: 20,
    borderRadius: radii.sm,
    minHeight: 36,
    justifyContent: 'center',
  },
  toggleActive: { backgroundColor: colors.surface2 },
  toggleText: { color: colors.textMuted, fontSize: fontSize.sm, fontWeight: fontWeight.medium },
  toggleTextActive: { color: colors.primary, fontWeight: fontWeight.semibold },
  sectionLabel: {
    color: colors.textSecondary,
    fontSize: fontSize.xs,
    fontWeight: fontWeight.semibold,
    textTransform: 'uppercase',
    letterSpacing: 1,
    marginBottom: spacing.sm,
    marginTop: spacing.md,
  },
  impRow: { flexDirection: 'row', gap: spacing.md },
  stepperGroup: { flex: 1, alignItems: 'center' },
  stepperLabel: { color: colors.textMuted, fontSize: fontSize.xs, marginBottom: 4 },
  stepperRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
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
  stepValue: {
    color: colors.textPrimary,
    fontSize: fontSize['2xl'],
    fontWeight: fontWeight.bold,
    minWidth: 100,
    textAlign: 'center',
  },
  bmiCard: { marginTop: spacing.xl, alignItems: 'center' },
  bmiTitle: {
    color: colors.textSecondary,
    fontSize: fontSize.xs,
    textTransform: 'uppercase',
    letterSpacing: 1,
    marginBottom: spacing.sm,
  },
  bmiValue: { fontSize: fontSize['3xl'], fontWeight: fontWeight.bold },
  bmiCat: { fontSize: fontSize.base, fontWeight: fontWeight.semibold, marginTop: 2 },
  bmiNote: { color: colors.textMuted, fontSize: fontSize.xs, marginTop: spacing.sm },
});
