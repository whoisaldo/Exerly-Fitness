import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { colors, radii, fontSize, fontWeight } from '../theme/colors';

const variantColors = {
  intensity: { bg: 'rgba(139,92,246,0.15)', text: colors.primaryBright, border: 'rgba(139,92,246,0.2)' },
  meal: { bg: 'rgba(245,158,11,0.15)', text: colors.warning, border: 'rgba(245,158,11,0.2)' },
  status: { bg: 'rgba(16,185,129,0.15)', text: colors.success, border: 'rgba(16,185,129,0.2)' },
  severity: { bg: 'rgba(239,68,68,0.15)', text: colors.error, border: 'rgba(239,68,68,0.2)' },
};

export function Badge({ children, variant = 'status', style }) {
  const scheme = variantColors[variant] || variantColors.status;

  return (
    <View
      style={[
        styles.pill,
        { backgroundColor: scheme.bg, borderColor: scheme.border },
        style,
      ]}
    >
      <Text style={[styles.text, { color: scheme.text }]}>{children}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  pill: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'flex-start',
    borderWidth: 1,
    borderRadius: radii.full,
    paddingHorizontal: 10,
    paddingVertical: 3,
  },
  text: {
    fontSize: fontSize.xs,
    fontWeight: fontWeight.medium,
  },
});
