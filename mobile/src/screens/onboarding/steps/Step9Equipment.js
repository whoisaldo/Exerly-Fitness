import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import StepContainer from '../../../components/onboarding/StepContainer';
import Toggle from '../../../components/Toggle';
import { colors, spacing, fontSize, fontWeight, radii } from '../../../theme/colors';

const EQUIPMENT = [
  { id: 'barbell', label: 'Barbell & Rack', icon: '\uD83C\uDFCB' },
  { id: 'dumbbells', label: 'Dumbbells', icon: '\uD83D\uDCAA' },
  { id: 'cables', label: 'Cable Machine', icon: '\uD83D\uDD17' },
  { id: 'machines', label: 'Weight Machines', icon: '\uD83E\uDD16' },
  { id: 'cardio_machines', label: 'Cardio Machines', icon: '\uD83C\uDFC3' },
  { id: 'resistance_bands', label: 'Resistance Bands', icon: '\uD83E\uDDF1' },
  { id: 'pull_up_bar', label: 'Pull-Up Bar', icon: '\u2B06\uFE0F' },
  { id: 'kettlebells', label: 'Kettlebells', icon: '\uD83D\uDD14' },
  { id: 'bench', label: 'Bench', icon: '\uD83E\uDE91' },
  { id: 'bodyweight', label: 'Bodyweight Only', icon: '\uD83C\uDFBD' },
];

const HOME_ONLY = ['bodyweight', 'resistance_bands', 'pull_up_bar', 'dumbbells', 'kettlebells'];

export default function Step9Equipment({ data, update }) {
  const gym = data.gymAccess ?? false;
  const selected = data.equipment ?? ['bodyweight'];

  const toggleGym = (v) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    if (v) {
      update({ gymAccess: true, equipment: EQUIPMENT.map((e) => e.id) });
    } else {
      update({ gymAccess: false, equipment: selected.filter((e) => HOME_ONLY.includes(e)) });
    }
  };

  const toggleEquip = (id) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (!gym && !HOME_ONLY.includes(id)) return;
    const next = selected.includes(id)
      ? selected.filter((x) => x !== id)
      : [...selected, id];
    update({ equipment: next.length ? next : ['bodyweight'] });
  };

  return (
    <StepContainer title="What do you have access to?" subtitle="We'll build your workouts around what you have">
      <View style={styles.gymRow}>
        <View style={styles.gymText}>
          <Text style={styles.gymLabel}>{gym ? 'I have gym access' : 'Home / outdoor only'}</Text>
        </View>
        <Toggle value={gym} onValueChange={toggleGym} />
      </View>

      <View style={styles.grid}>
        {EQUIPMENT.map((e) => {
          const on = selected.includes(e.id);
          const disabled = !gym && !HOME_ONLY.includes(e.id);
          return (
            <Pressable
              key={e.id}
              onPress={() => toggleEquip(e.id)}
              disabled={disabled}
              style={[styles.chip, on && styles.chipOn, disabled && styles.chipDisabled]}
              accessibilityRole="checkbox"
              accessibilityState={{ checked: on, disabled }}
              accessibilityLabel={e.label}
            >
              <Text style={styles.chipIcon}>{e.icon}</Text>
              <Text style={[styles.chipLabel, on && styles.chipLabelOn, disabled && styles.chipLabelDis]}>
                {e.label}
              </Text>
              {on && <Ionicons name="checkmark-circle" size={16} color={colors.primary} />}
            </Pressable>
          );
        })}
      </View>
    </StepContainer>
  );
}

export function validate(data) {
  return (data.equipment ?? []).length >= 1;
}

const styles = StyleSheet.create({
  gymRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: colors.surface1,
    borderRadius: radii.md,
    padding: spacing.md,
    marginBottom: spacing.lg,
  },
  gymText: { flex: 1 },
  gymLabel: { color: colors.textPrimary, fontSize: fontSize.base, fontWeight: fontWeight.semibold },
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    width: '48%',
    backgroundColor: colors.glassBg,
    borderWidth: 1,
    borderColor: colors.glassBorder,
    borderRadius: radii.md,
    paddingVertical: 10,
    paddingHorizontal: 10,
    minHeight: 44,
  },
  chipOn: { backgroundColor: `${colors.primary}15`, borderColor: colors.primary },
  chipDisabled: { opacity: 0.35 },
  chipIcon: { fontSize: 16, marginRight: 8 },
  chipLabel: { flex: 1, color: colors.textMuted, fontSize: fontSize.xs, fontWeight: fontWeight.medium },
  chipLabelOn: { color: colors.textPrimary },
  chipLabelDis: { color: colors.textMuted },
});
