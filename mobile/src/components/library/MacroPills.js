import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { colors, radii, fontSize, fontWeight, spacing } from '../../theme/colors';

const MACROS = [
  { key: 'protein', letter: 'P', label: 'Protein', color: '#60a5fa', bg: 'rgba(96,165,250,0.12)' },
  { key: 'carbs', letter: 'C', label: 'Carbs', color: '#fbbf24', bg: 'rgba(251,191,36,0.12)' },
  { key: 'fat', letter: 'F', label: 'Fat', color: '#fb7185', bg: 'rgba(251,113,133,0.12)' },
];

export default function MacroPills({ protein = 0, carbs = 0, fat = 0, size = 'sm' }) {
  const values = { protein, carbs, fat };
  const isLg = size === 'lg';
  const isMd = size === 'md';

  return (
    <View style={styles.row}>
      {MACROS.map((m) => (
        <View key={m.key} style={[styles.pill, { backgroundColor: m.bg }, isLg && styles.pillLg]}>
          <Text style={[styles.text, { color: m.color }, isLg && styles.textLg]}>
            {isMd || isLg ? `${m.label} ` : `${m.letter}:`}
            {Math.round(values[m.key])}g
          </Text>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    gap: spacing.xs,
  },
  pill: {
    paddingHorizontal: spacing.sm,
    paddingVertical: 3,
    borderRadius: radii.full,
  },
  pillLg: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
  },
  text: {
    fontSize: fontSize.xs,
    fontWeight: fontWeight.medium,
  },
  textLg: {
    fontSize: fontSize.sm,
  },
});
