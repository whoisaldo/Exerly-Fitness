import React from 'react';
import { View, StyleSheet } from 'react-native';
import { colors, radii } from '../theme/colors';

/**
 * Glassmorphism card for React Native.
 * Uses rgba overlay. Add expo-blur's BlurView as a child for true blur.
 */
export function GlassCard({ children, style, elevated = false }) {
  return (
    <View style={[styles.card, elevated && styles.elevated, style]}>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.glassBg,
    borderWidth: 1,
    borderColor: colors.glassBorder,
    borderRadius: radii.lg,
    padding: 20,
    overflow: 'hidden',
  },
  elevated: {
    backgroundColor: colors.glassElevated,
    borderColor: colors.glassBorderElevated,
    shadowColor: colors.primary,
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.15,
    shadowRadius: 24,
    elevation: 8,
  },
});
