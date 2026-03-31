import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import GlassCard from './GlassCard';
import { colors, fontSize, fontWeight, spacing, radii } from '../theme/colors';

/**
 * Stat display card with icon, label, value, and optional trend.
 * @param {{ icon: string, label: string, value: string|number, trend?: number, color?: string, style?: object }} props
 */
export default function StatCard({ icon, label, value, trend, color, style }) {
  const iconColor = color ?? colors.primary;
  const trendPositive = trend != null && trend >= 0;
  const trendColor = trendPositive ? colors.success : colors.error;
  const trendArrow = trendPositive ? '\u2191' : '\u2193';

  return (
    <GlassCard style={[styles.card, style]}>
      <View style={[styles.iconWrap, { backgroundColor: `${iconColor}18` }]}>
        <Ionicons name={icon} size={20} color={iconColor} />
      </View>
      <Text style={styles.label}>{label}</Text>
      <View style={styles.valueRow}>
        <Text
          style={styles.value}
          accessibilityRole="text"
          accessibilityLabel={`${label}: ${value}`}
        >
          {value}
        </Text>
        {trend != null && (
          <Text style={[styles.trend, { color: trendColor }]}>
            {trendArrow} {Math.abs(trend)}%
          </Text>
        )}
      </View>
    </GlassCard>
  );
}

export { StatCard };

const styles = StyleSheet.create({
  card: {
    width: 140,
    marginRight: 12,
  },
  iconWrap: {
    width: 38,
    height: 38,
    borderRadius: radii.md,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: spacing.sm,
  },
  label: {
    fontSize: fontSize.xs,
    fontWeight: fontWeight.medium,
    color: colors.textSecondary,
    textTransform: 'uppercase',
    letterSpacing: 1.2,
    marginBottom: 4,
  },
  valueRow: {
    flexDirection: 'row',
    alignItems: 'baseline',
    gap: 6,
  },
  value: {
    fontSize: fontSize.xl,
    fontWeight: fontWeight.bold,
    color: colors.textPrimary,
  },
  trend: {
    fontSize: fontSize.xs,
    fontWeight: fontWeight.semibold,
  },
});
