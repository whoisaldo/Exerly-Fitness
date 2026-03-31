import React from 'react';
import { View, StyleSheet } from 'react-native';
import { BlurView } from 'expo-blur';
import { colors, radii } from '../theme/colors';

/**
 * Frosted-glass card with optional glow accent.
 * @param {{ children: React.ReactNode, glow?: boolean, elevated?: boolean, style?: object }} props
 */
export default function GlassCard({ children, glow = false, elevated = false, style }) {
  return (
    <View style={[styles.card, elevated && styles.elevated, glow && styles.glow, style]}>
      <BlurView intensity={18} tint="dark" style={StyleSheet.absoluteFill} />
      <View style={styles.inner}>{children}</View>
    </View>
  );
}

export { GlassCard };

const styles = StyleSheet.create({
  card: {
    borderRadius: radii.lg,
    overflow: 'hidden',
    backgroundColor: colors.glassBg,
    borderWidth: 1,
    borderColor: colors.glassBorder,
  },
  elevated: {
    backgroundColor: colors.glassElevated,
    borderColor: colors.glassBorderElevated,
  },
  glow: {
    shadowColor: colors.primary,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 16,
    elevation: 6,
  },
  inner: {
    padding: 16,
  },
});
