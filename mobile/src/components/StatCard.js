import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { colors, radii, fontSize, fontWeight, spacing } from '../theme/colors';
import { GlassCard } from './GlassCard';

export function StatCard({ icon, label, value, trend, style }) {
  const trendPositive = trend !== undefined && trend >= 0;
  const trendColor = trendPositive ? colors.success : colors.error;
  const trendArrow = trendPositive ? '\u2191' : '\u2193';

  return (
    <GlassCard style={style}>
      <View style={styles.iconWrap}>{icon}</View>
      <Text style={styles.label}>{label}</Text>
      <View style={styles.valueRow}>
        <Text style={styles.value}>{value}</Text>
        {trend !== undefined && (
          <Text style={[styles.trend, { color: trendColor }]}>
            {trendArrow} {Math.abs(trend)}%
          </Text>
        )}
      </View>
    </GlassCard>
  );
}

const styles = StyleSheet.create({
  iconWrap: {
    width: 40,
    height: 40,
    borderRadius: radii.md,
    backgroundColor: 'rgba(139,92,246,0.1)',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: spacing.sm,
  },
  label: {
    fontSize: fontSize.xs,
    fontWeight: fontWeight.medium,
    color: colors.textSecondary,
    textTransform: 'uppercase',
    letterSpacing: 1.5,
    marginBottom: 4,
  },
  valueRow: {
    flexDirection: 'row',
    alignItems: 'baseline',
    gap: 8,
  },
  value: {
    fontSize: fontSize['2xl'],
    fontWeight: fontWeight.bold,
    color: colors.textPrimary,
  },
  trend: {
    fontSize: fontSize.sm,
    fontWeight: fontWeight.medium,
  },
});
