import React from 'react';
import { View, Text, TextInput, Pressable, StyleSheet } from 'react-native';
import * as Haptics from 'expo-haptics';
import Animated, { useAnimatedStyle, withSpring, useSharedValue } from 'react-native-reanimated';
import StepContainer from '../../../components/onboarding/StepContainer';
import GlassCard from '../../../components/GlassCard';
import { colors, spacing, fontSize, fontWeight, radii } from '../../../theme/colors';

const GENDERS = [
  { id: 'male', label: 'Male', symbol: '\u2642' },
  { id: 'female', label: 'Female', symbol: '\u2640' },
  { id: 'other', label: 'Other', symbol: '\u26A7' },
];

function GenderCard({ item, selected, onPress }) {
  const scale = useSharedValue(1);
  const animStyle = useAnimatedStyle(() => ({ transform: [{ scale: scale.value }] }));

  const handlePress = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    scale.value = withSpring(0.94, { damping: 15 });
    setTimeout(() => { scale.value = withSpring(1, { damping: 15 }); }, 100);
    onPress(item.id);
  };

  return (
    <Animated.View style={[styles.genderCol, animStyle]}>
      <Pressable onPress={handlePress} accessibilityRole="radio" accessibilityState={{ selected }}>
        <GlassCard style={[styles.genderCard, selected && styles.genderSelected]}>
          <Text style={styles.genderSymbol}>{item.symbol}</Text>
          <Text style={[styles.genderLabel, selected && styles.genderLabelActive]}>
            {item.label}
          </Text>
        </GlassCard>
      </Pressable>
    </Animated.View>
  );
}

export default function Step2AgeGender({ data, update }) {
  const name = (data.name ?? '').split(' ')[0];

  return (
    <StepContainer title={`Tell us about yourself, ${name}`}>
      <Text style={styles.label}>Gender</Text>
      <View style={styles.genderRow}>
        {GENDERS.map((g) => (
          <GenderCard
            key={g.id}
            item={g}
            selected={data.gender === g.id}
            onPress={(id) => update({ gender: id })}
          />
        ))}
      </View>

      <Text style={styles.label}>Age</Text>
      <View style={styles.ageRow}>
        <Pressable
          onPress={() => {
            Haptics.selectionAsync();
            update({ age: Math.max((data.age ?? 25) - 1, 13) });
          }}
          style={styles.stepper}
          accessibilityLabel="Decrease age"
        >
          <Text style={styles.stepperText}>-</Text>
        </Pressable>
        <TextInput
          style={styles.ageInput}
          value={String(data.age ?? 25)}
          onChangeText={(v) => {
            const n = parseInt(v, 10);
            if (!isNaN(n) && n >= 13 && n <= 80) update({ age: n });
          }}
          keyboardType="number-pad"
          maxLength={2}
          accessibilityLabel="Age"
        />
        <Pressable
          onPress={() => {
            Haptics.selectionAsync();
            update({ age: Math.min((data.age ?? 25) + 1, 80) });
          }}
          style={styles.stepper}
          accessibilityLabel="Increase age"
        >
          <Text style={styles.stepperText}>+</Text>
        </Pressable>
      </View>
      <Text style={styles.ageLabel}>years old</Text>
    </StepContainer>
  );
}

export function validate(data) {
  return !!data.gender && data.age >= 13 && data.age <= 80;
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
  genderRow: { flexDirection: 'row', gap: spacing.sm },
  genderCol: { flex: 1 },
  genderCard: { alignItems: 'center', paddingVertical: spacing.lg },
  genderSelected: { borderColor: colors.borderAccent },
  genderSymbol: { fontSize: 32, marginBottom: spacing.sm },
  genderLabel: { color: colors.textMuted, fontSize: fontSize.sm, fontWeight: fontWeight.medium },
  genderLabelActive: { color: colors.primary },
  ageRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.lg,
  },
  stepper: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: colors.surface2,
    alignItems: 'center',
    justifyContent: 'center',
    minWidth: 44,
    minHeight: 44,
  },
  stepperText: {
    color: colors.primary,
    fontSize: fontSize.xl,
    fontWeight: fontWeight.bold,
  },
  ageInput: {
    color: colors.textPrimary,
    fontSize: fontSize.display,
    fontWeight: fontWeight.bold,
    textAlign: 'center',
    width: 80,
    minHeight: 48,
  },
  ageLabel: {
    color: colors.textMuted,
    fontSize: fontSize.sm,
    textAlign: 'center',
    marginTop: spacing.xs,
  },
});
