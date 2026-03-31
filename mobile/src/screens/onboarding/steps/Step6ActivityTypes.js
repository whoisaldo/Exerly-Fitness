import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import Animated, { useAnimatedStyle, withSpring, useSharedValue } from 'react-native-reanimated';
import StepContainer from '../../../components/onboarding/StepContainer';
import { colors, spacing, fontSize, fontWeight, radii } from '../../../theme/colors';

const ACTIVITIES = [
  { id: 'weights', label: 'Weight Training', icon: '\uD83C\uDFCB' },
  { id: 'running', label: 'Running', icon: '\uD83C\uDFC3' },
  { id: 'cycling', label: 'Cycling', icon: '\uD83D\uDEB4' },
  { id: 'swimming', label: 'Swimming', icon: '\uD83C\uDFCA' },
  { id: 'yoga', label: 'Yoga', icon: '\uD83E\uDDD8' },
  { id: 'boxing', label: 'Boxing / HIIT', icon: '\uD83E\uDD4A' },
  { id: 'sports', label: 'Sports', icon: '\u26F9' },
  { id: 'hiking', label: 'Outdoor / Hiking', icon: '\uD83D\uDEB5' },
  { id: 'calisthenics', label: 'Calisthenics', icon: '\uD83E\uDD38' },
  { id: 'team_sports', label: 'Team Sports', icon: '\uD83C\uDFD0' },
  { id: 'pilates', label: 'Pilates', icon: '\uD83C\uDFAF' },
  { id: 'dance', label: 'Dance', icon: '\uD83D\uDC83' },
];

function Chip({ item, selected, onToggle }) {
  const scale = useSharedValue(1);
  const animStyle = useAnimatedStyle(() => ({ transform: [{ scale: scale.value }] }));

  const handlePress = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    scale.value = withSpring(0.93, { damping: 14 });
    setTimeout(() => { scale.value = withSpring(1, { damping: 14 }); }, 100);
    onToggle();
  };

  return (
    <Animated.View style={[styles.chipWrap, animStyle]}>
      <Pressable
        onPress={handlePress}
        style={[styles.chip, selected && styles.chipSelected]}
        accessibilityRole="checkbox"
        accessibilityState={{ checked: selected }}
        accessibilityLabel={item.label}
      >
        <Text style={styles.chipIcon}>{item.icon}</Text>
        <Text style={[styles.chipLabel, selected && styles.chipLabelActive]}>{item.label}</Text>
        {selected && <Ionicons name="checkmark" size={14} color="#fff" style={styles.chipCheck} />}
      </Pressable>
    </Animated.View>
  );
}

export default function Step6ActivityTypes({ data, update }) {
  const selected = data.activityTypes ?? [];

  const toggle = (id) => {
    const next = selected.includes(id)
      ? selected.filter((x) => x !== id)
      : [...selected, id];
    update({ activityTypes: next });
  };

  return (
    <StepContainer
      title="What do you like to do?"
      subtitle="Select all that apply — this shapes your workout plan"
    >
      <View style={styles.grid}>
        {ACTIVITIES.map((a) => (
          <Chip
            key={a.id}
            item={a}
            selected={selected.includes(a.id)}
            onToggle={() => toggle(a.id)}
          />
        ))}
      </View>
    </StepContainer>
  );
}

export function validate(data) {
  return (data.activityTypes ?? []).length >= 1;
}

const styles = StyleSheet.create({
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  chipWrap: { width: '48%' },
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.glassBg,
    borderWidth: 1,
    borderColor: colors.glassBorder,
    borderRadius: radii.md,
    paddingVertical: 12,
    paddingHorizontal: 12,
    minHeight: 48,
  },
  chipSelected: {
    backgroundColor: `${colors.primary}18`,
    borderColor: colors.primary,
  },
  chipIcon: { fontSize: 18, marginRight: 8 },
  chipLabel: { flex: 1, color: colors.textMuted, fontSize: fontSize.xs, fontWeight: fontWeight.medium },
  chipLabelActive: { color: colors.textPrimary },
  chipCheck: { marginLeft: 4 },
});
