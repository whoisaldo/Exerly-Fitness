import React, { useMemo } from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import * as Haptics from 'expo-haptics';
import Slider from '@react-native-community/slider';
import StepContainer from '../../../components/onboarding/StepContainer';
import GlassCard from '../../../components/GlassCard';
import { calcBedtime, sleepCopy } from '../../../services/WizardService';
import { colors, spacing, fontSize, fontWeight, radii } from '../../../theme/colors';

const HOURS = [5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10];
const WAKE_HOURS = Array.from({ length: 13 }, (_, i) => i + 5); // 5-17

function hourColor(h) {
  if (h < 6) return colors.error;
  if (h < 7) return colors.warning;
  if (h <= 9) return colors.success;
  return '#3b82f6';
}

function formatTime24to12(t) {
  const [h, m] = t.split(':').map(Number);
  const ampm = h >= 12 ? 'PM' : 'AM';
  const h12 = h % 12 || 12;
  return `${h12}:${String(m).padStart(2, '0')} ${ampm}`;
}

export default function Step8Sleep({ data, update }) {
  const sleepGoal = data.sleepGoalHours ?? 7.5;
  const wakeTime = data.wakeTime ?? '07:00';
  const wakeH = parseInt(wakeTime.split(':')[0], 10);
  const bedtime = useMemo(() => calcBedtime(wakeTime, sleepGoal), [wakeTime, sleepGoal]);
  const color = hourColor(sleepGoal);

  return (
    <StepContainer title="Let's optimize your recovery">
      <Text style={styles.label}>Sleep Goal</Text>
      <Text style={[styles.bigNumber, { color }]}>{sleepGoal} hrs</Text>
      <Slider
        style={styles.slider}
        minimumValue={5}
        maximumValue={10}
        step={0.5}
        value={sleepGoal}
        onValueChange={(v) => {
          if (v % 0.5 === 0) Haptics.selectionAsync();
          update({ sleepGoalHours: v });
        }}
        minimumTrackTintColor={color}
        maximumTrackTintColor={colors.surface3}
        thumbTintColor={color}
      />
      <Text style={styles.copy}>{sleepCopy(sleepGoal)}</Text>

      <Text style={styles.label}>Wake Time</Text>
      <View style={styles.wakeRow}>
        <Pressable
          onPress={() => {
            Haptics.selectionAsync();
            const h = Math.max(wakeH - 1, 5);
            update({ wakeTime: `${String(h).padStart(2, '0')}:00` });
          }}
          style={styles.wakeBtn}
          accessibilityLabel="Earlier wake time"
        >
          <Text style={styles.wakeBtnText}>-</Text>
        </Pressable>
        <Text style={styles.wakeValue}>{formatTime24to12(wakeTime)}</Text>
        <Pressable
          onPress={() => {
            Haptics.selectionAsync();
            const h = Math.min(wakeH + 1, 17);
            update({ wakeTime: `${String(h).padStart(2, '0')}:00` });
          }}
          style={styles.wakeBtn}
          accessibilityLabel="Later wake time"
        >
          <Text style={styles.wakeBtnText}>+</Text>
        </Pressable>
      </View>

      <GlassCard style={styles.bedCard}>
        <Text style={styles.bedLabel}>Calculated Bedtime</Text>
        <Text style={styles.bedValue}>{formatTime24to12(bedtime)}</Text>
        {parseInt(bedtime.split(':')[0], 10) >= 0 && parseInt(bedtime.split(':')[0], 10) < 6 && (
          <Text style={styles.bedWarn}>
            That's pretty late — consider adjusting for better recovery
          </Text>
        )}
      </GlassCard>
    </StepContainer>
  );
}

export function validate(data) {
  return data.sleepGoalHours >= 5 && !!data.wakeTime;
}

const styles = StyleSheet.create({
  label: {
    color: colors.textSecondary,
    fontSize: fontSize.xs,
    fontWeight: fontWeight.semibold,
    textTransform: 'uppercase',
    letterSpacing: 1,
    marginBottom: spacing.sm,
    marginTop: spacing.lg,
  },
  bigNumber: {
    fontSize: fontSize.display,
    fontWeight: fontWeight.bold,
    textAlign: 'center',
  },
  slider: { width: '100%', height: 44, marginTop: spacing.sm },
  copy: { color: colors.textMuted, fontSize: fontSize.sm, textAlign: 'center', marginTop: spacing.sm },
  wakeRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: spacing.lg },
  wakeBtn: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: colors.surface2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  wakeBtnText: { color: colors.primary, fontSize: fontSize.lg, fontWeight: fontWeight.bold },
  wakeValue: {
    color: colors.textPrimary,
    fontSize: fontSize['2xl'],
    fontWeight: fontWeight.bold,
    minWidth: 120,
    textAlign: 'center',
  },
  bedCard: { marginTop: spacing.xl, alignItems: 'center' },
  bedLabel: { color: colors.textSecondary, fontSize: fontSize.xs, textTransform: 'uppercase', letterSpacing: 1 },
  bedValue: { color: colors.primary, fontSize: fontSize.xl, fontWeight: fontWeight.bold, marginTop: spacing.sm },
  bedWarn: { color: colors.warning, fontSize: fontSize.xs, marginTop: spacing.sm, textAlign: 'center' },
});
