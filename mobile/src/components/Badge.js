import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { colors, radii, fontSize, fontWeight } from '../theme/colors';

const VARIANT_COLORS = {
  // Intensity
  low: colors.success,
  medium: colors.warning,
  high: colors.error,
  // Meals
  breakfast: '#6366f1',
  lunch: '#f59e0b',
  dinner: '#ec4899',
  snack: '#10b981',
  // Status
  active: colors.primary,
  completed: colors.success,
  pending: colors.warning,
  // Legacy variant groups
  intensity: colors.primaryBright,
  meal: colors.warning,
  status: colors.success,
  severity: colors.error,
};

/**
 * Colored pill badge.
 * @param {{ label?: string, children?: React.ReactNode, variant?: string, color?: string, style?: object }} props
 */
export default function Badge({ label, children, variant = 'status', color, style }) {
  const bg = color ?? VARIANT_COLORS[variant] ?? colors.primary;
  const content = label ?? children;

  return (
    <View
      style={[styles.pill, { backgroundColor: `${bg}22`, borderColor: `${bg}33` }, style]}
      accessibilityRole="text"
      accessibilityLabel={typeof content === 'string' ? content : undefined}
    >
      <Text style={[styles.text, { color: bg }]}>{content}</Text>
    </View>
  );
}

export { Badge };

const styles = StyleSheet.create({
  pill: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'flex-start',
    borderWidth: 1,
    borderRadius: radii.full,
    paddingHorizontal: 10,
    paddingVertical: 4,
  },
  text: {
    fontSize: fontSize.xs,
    fontWeight: fontWeight.semibold,
    textTransform: 'capitalize',
  },
});
