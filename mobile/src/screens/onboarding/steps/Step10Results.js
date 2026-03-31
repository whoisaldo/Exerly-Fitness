import React, { useMemo } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import Animated, { FadeInUp } from 'react-native-reanimated';
import StepContainer from '../../../components/onboarding/StepContainer';
import GlassCard from '../../../components/GlassCard';
import MacroBar from '../../../components/onboarding/MacroBar';
import WeeklyCalendar from '../../../components/onboarding/WeeklyCalendar';
import { calculateAll, calcBedtime, kgToLbs } from '../../../services/WizardService';
import { colors, spacing, fontSize, fontWeight, radii } from '../../../theme/colors';

function formatTime24to12(t) {
  const [h, m] = t.split(':').map(Number);
  const ampm = h >= 12 ? 'PM' : 'AM';
  const h12 = h % 12 || 12;
  return `${h12}:${String(m).padStart(2, '0')} ${ampm}`;
}

export default function Step10Results({ data }) {
  const calc = useMemo(() => calculateAll(data), [data]);
  const bedtime = useMemo(
    () => calcBedtime(data.wakeTime ?? '07:00', data.sleepGoalHours ?? 7.5),
    [data.wakeTime, data.sleepGoalHours],
  );
  const totalMacroCal = calc.protein * 4 + calc.carbs * 4 + calc.fat * 9;
  const name = (data.name ?? '').split(' ')[0];
  const isMetric = data.unitPreference === 'metric';
  const healthyRange = isMetric
    ? `${calc.healthyRange.min}-${calc.healthyRange.max}`
    : `${kgToLbs(calc.healthyRange.min)}-${kgToLbs(calc.healthyRange.max)}`;

  return (
    <StepContainer title={`Your personalized plan, ${name}`} subtitle="Calculated using Mifflin-St Jeor + your activity data">
      {/* Calorie Target */}
      <Animated.View entering={FadeInUp.delay(100).duration(500)}>
        <GlassCard glow style={styles.calCard}>
          <Text style={styles.calLabel}>Daily Calorie Target</Text>
          <Text style={styles.calValue}>{calc.targetCalories}</Text>
          <Text style={styles.calUnit}>calories / day</Text>
          <View style={styles.calMeta}>
            <Text style={styles.calMetaText}>BMR: {calc.bmr}</Text>
            <Text style={styles.calMetaDot}>{'\u00B7'}</Text>
            <Text style={styles.calMetaText}>TDEE: {calc.tdee}</Text>
          </View>
        </GlassCard>
      </Animated.View>

      {/* Macros */}
      <Animated.View entering={FadeInUp.delay(250).duration(500)}>
        <GlassCard style={styles.macroCard}>
          <Text style={styles.sectionTitle}>Macro Breakdown</Text>
          <MacroBar label="Protein" grams={calc.protein} totalCal={totalMacroCal} color="#3b82f6" percent={(calc.protein * 4 / totalMacroCal) * 100} />
          <MacroBar label="Carbs" grams={calc.carbs} totalCal={totalMacroCal} color={colors.warning} percent={(calc.carbs * 4 / totalMacroCal) * 100} />
          <MacroBar label="Fat" grams={calc.fat} totalCal={totalMacroCal} color={colors.accent} percent={(calc.fat * 9 / totalMacroCal) * 100} />
          <Text style={styles.macroSplit}>
            ~{Math.round(calc.protein / (data.mealsPerDay ?? 3))}g protein per meal ({data.mealsPerDay ?? 3} meals/day)
          </Text>
        </GlassCard>
      </Animated.View>

      {/* Workout Schedule */}
      <Animated.View entering={FadeInUp.delay(400).duration(500)}>
        <GlassCard style={styles.weekCard}>
          <Text style={styles.sectionTitle}>Weekly Schedule</Text>
          <WeeklyCalendar plan={calc.starterWorkoutPlan} />
        </GlassCard>
      </Animated.View>

      {/* Sleep */}
      <Animated.View entering={FadeInUp.delay(550).duration(500)}>
        <GlassCard style={styles.sleepCard}>
          <View style={styles.sleepRow}>
            <Ionicons name="moon" size={20} color={colors.primary} />
            <Text style={styles.sleepText}>
              Bed {formatTime24to12(bedtime)} · Wake {formatTime24to12(data.wakeTime ?? '07:00')} · {data.sleepGoalHours ?? 7.5}hrs
            </Text>
          </View>
        </GlassCard>
      </Animated.View>

      {/* Body Stats */}
      <Animated.View entering={FadeInUp.delay(700).duration(500)}>
        <GlassCard style={styles.bodyCard}>
          <Text style={styles.sectionTitle}>Body Stats</Text>
          <View style={styles.bodyRow}>
            <View style={styles.bodyStat}>
              <Text style={styles.bodyValue}>{calc.bmi}</Text>
              <Text style={styles.bodyLabel}>BMI</Text>
            </View>
            <View style={styles.bodyStat}>
              <Text style={styles.bodyValue}>{calc.bodyFat.low}-{calc.bodyFat.high}%</Text>
              <Text style={styles.bodyLabel}>Est. Body Fat</Text>
            </View>
            <View style={styles.bodyStat}>
              <Text style={styles.bodyValue}>{healthyRange}</Text>
              <Text style={styles.bodyLabel}>Healthy {isMetric ? 'kg' : 'lbs'}</Text>
            </View>
          </View>
        </GlassCard>
      </Animated.View>
    </StepContainer>
  );
}

export function validate() { return true; }

const styles = StyleSheet.create({
  calCard: { alignItems: 'center', marginBottom: spacing.md },
  calLabel: { color: colors.textSecondary, fontSize: fontSize.xs, textTransform: 'uppercase', letterSpacing: 1 },
  calValue: { color: colors.textPrimary, fontSize: fontSize.display, fontWeight: fontWeight.extrabold, marginTop: spacing.sm },
  calUnit: { color: colors.textMuted, fontSize: fontSize.sm },
  calMeta: { flexDirection: 'row', gap: 8, marginTop: spacing.sm },
  calMetaText: { color: colors.textMuted, fontSize: fontSize.xs },
  calMetaDot: { color: colors.textMuted, fontSize: fontSize.xs },
  macroCard: { marginBottom: spacing.md },
  sectionTitle: { color: colors.textPrimary, fontSize: fontSize.base, fontWeight: fontWeight.bold, marginBottom: spacing.md },
  macroSplit: { color: colors.textMuted, fontSize: fontSize.xs, marginTop: spacing.sm },
  weekCard: { marginBottom: spacing.md },
  sleepCard: { marginBottom: spacing.md },
  sleepRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  sleepText: { color: colors.textSecondary, fontSize: fontSize.sm, flex: 1 },
  bodyCard: { marginBottom: spacing.md },
  bodyRow: { flexDirection: 'row', justifyContent: 'space-around' },
  bodyStat: { alignItems: 'center' },
  bodyValue: { color: colors.textPrimary, fontSize: fontSize.lg, fontWeight: fontWeight.bold },
  bodyLabel: { color: colors.textMuted, fontSize: fontSize.xs, marginTop: 2 },
});
