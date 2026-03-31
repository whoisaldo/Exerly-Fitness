import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import StepContainer from '../../../components/onboarding/StepContainer';
import GoalCard from '../../../components/onboarding/GoalCard';
import { colors, spacing, fontSize, fontWeight, radii } from '../../../theme/colors';

const DIETS = [
  { id: 'standard', icon: '\uD83C\uDF57', title: 'Standard', sub: 'No restrictions' },
  { id: 'vegetarian', icon: '\uD83E\uDD57', title: 'Vegetarian', sub: 'No meat' },
  { id: 'vegan', icon: '\uD83C\uDF31', title: 'Vegan', sub: 'No animal products' },
  { id: 'keto', icon: '\uD83E\uDD53', title: 'Keto', sub: 'High fat, very low carb' },
  { id: 'paleo', icon: '\uD83E\uDD69', title: 'Paleo', sub: 'Whole foods, no grains' },
  { id: 'mediterranean', icon: '\uD83E\uDED2', title: 'Mediterranean', sub: 'Fish, olive oil, veggies' },
  { id: 'halal', icon: '\u262A\uFE0F', title: 'Halal', sub: 'Islamic dietary law' },
  { id: 'kosher', icon: '\u2721\uFE0F', title: 'Kosher', sub: 'Jewish dietary law' },
];

const ALLERGIES = ['Gluten', 'Dairy', 'Tree Nuts', 'Eggs', 'Soy', 'Shellfish', 'None'];

export default function Step7Diet({ data, update }) {
  const selected = data.allergies ?? [];
  const meals = data.mealsPerDay ?? 3;

  const toggleAllergy = (a) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (a === 'None') {
      update({ allergies: ['None'] });
      return;
    }
    const without = selected.filter((x) => x !== 'None');
    const next = without.includes(a) ? without.filter((x) => x !== a) : [...without, a];
    update({ allergies: next.length ? next : ['None'] });
  };

  return (
    <StepContainer title="How do you eat?" subtitle="This helps us tailor meal suggestions to your preferences">
      <Text style={styles.label}>Dietary Style</Text>
      {DIETS.map((d) => (
        <GoalCard
          key={d.id}
          icon={d.icon}
          title={d.title}
          subtitle={d.sub}
          selected={(data.dietaryStyle ?? []).includes(d.id)}
          onPress={() => update({ dietaryStyle: [d.id] })}
        />
      ))}

      <Text style={styles.label}>Allergies / Intolerances</Text>
      <View style={styles.chipRow}>
        {ALLERGIES.map((a) => {
          const on = selected.includes(a);
          return (
            <Pressable
              key={a}
              onPress={() => toggleAllergy(a)}
              style={[styles.chip, on && styles.chipActive]}
              accessibilityRole="checkbox"
              accessibilityState={{ checked: on }}
            >
              <Text style={[styles.chipText, on && styles.chipTextActive]}>{a}</Text>
            </Pressable>
          );
        })}
      </View>

      <Text style={styles.label}>Meals per day</Text>
      <View style={styles.mealsRow}>
        {[3, 4, 5, 6].map((n) => (
          <Pressable
            key={n}
            onPress={() => { Haptics.selectionAsync(); update({ mealsPerDay: n }); }}
            style={[styles.mealPill, meals === n && styles.mealPillActive]}
            accessibilityRole="radio"
            accessibilityState={{ selected: meals === n }}
          >
            <Text style={[styles.mealText, meals === n && styles.mealTextActive]}>{n}</Text>
          </Pressable>
        ))}
      </View>
      <Text style={styles.mealNote}>
        We'll split your macros across {meals} meals
      </Text>
    </StepContainer>
  );
}

export function validate(data) {
  return (data.dietaryStyle ?? []).length >= 1 && (data.allergies ?? []).length >= 1;
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
  chipRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  chip: {
    paddingVertical: 8,
    paddingHorizontal: 14,
    borderRadius: radii.full,
    backgroundColor: colors.surface2,
    minHeight: 36,
    justifyContent: 'center',
  },
  chipActive: { backgroundColor: `${colors.primary}22`, borderWidth: 1, borderColor: colors.primary },
  chipText: { color: colors.textMuted, fontSize: fontSize.xs, fontWeight: fontWeight.medium },
  chipTextActive: { color: colors.primary },
  mealsRow: { flexDirection: 'row', gap: spacing.sm },
  mealPill: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: radii.full,
    backgroundColor: colors.surface2,
    alignItems: 'center',
    minHeight: 44,
    justifyContent: 'center',
  },
  mealPillActive: { backgroundColor: `${colors.primary}22`, borderWidth: 1, borderColor: colors.primary },
  mealText: { color: colors.textMuted, fontSize: fontSize.lg, fontWeight: fontWeight.bold },
  mealTextActive: { color: colors.primary },
  mealNote: { color: colors.textMuted, fontSize: fontSize.xs, textAlign: 'center', marginTop: spacing.sm },
});
