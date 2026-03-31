import React from 'react';
import { View, Text, ScrollView, StyleSheet } from 'react-native';
import { colors, spacing, fontSize, fontWeight } from '../../theme/colors';

/**
 * Shared wrapper for each wizard step.
 * @param {{ title: string, subtitle?: string, children: React.ReactNode, scrollable?: boolean }} props
 */
export default function StepContainer({ title, subtitle, children, scrollable = true }) {
  const Wrapper = scrollable ? ScrollView : View;
  const wrapperProps = scrollable
    ? { contentContainerStyle: styles.scroll, showsVerticalScrollIndicator: false, keyboardShouldPersistTaps: 'handled' }
    : { style: styles.fixed };

  return (
    <Wrapper {...wrapperProps}>
      <Text style={styles.title}>{title}</Text>
      {subtitle ? <Text style={styles.subtitle}>{subtitle}</Text> : null}
      <View style={styles.body}>{children}</View>
    </Wrapper>
  );
}

const styles = StyleSheet.create({
  scroll: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
    paddingBottom: 120,
  },
  fixed: {
    flex: 1,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
  },
  title: {
    color: colors.textPrimary,
    fontSize: fontSize['2xl'],
    fontWeight: fontWeight.bold,
    letterSpacing: -0.5,
  },
  subtitle: {
    color: colors.textSecondary,
    fontSize: fontSize.sm,
    marginTop: spacing.xs,
    lineHeight: 20,
  },
  body: {
    marginTop: spacing.lg,
  },
});
