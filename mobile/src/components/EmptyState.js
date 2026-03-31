import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import ActionButton from './ActionButton';
import { colors, fontSize, fontWeight, spacing } from '../theme/colors';

/**
 * Empty-state placeholder with icon, message, and optional CTA.
 * @param {{ icon?: string|React.ReactNode, title: string, subtitle?: string, message?: string, actionTitle?: string, action?: { label: string, onPress: () => void }, onAction?: () => void, style?: object }} props
 */
export default function EmptyState({
  icon = 'layers-outline',
  title,
  subtitle,
  message,
  actionTitle,
  action,
  onAction,
  style,
}) {
  const desc = subtitle ?? message;
  const btnLabel = actionTitle ?? action?.label;
  const btnPress = onAction ?? action?.onPress;

  return (
    <View style={[styles.container, style]} accessibilityRole="text">
      {typeof icon === 'string' ? (
        <Ionicons name={icon} size={56} color={`${colors.primary}55`} />
      ) : (
        <View style={styles.iconWrap}>{icon}</View>
      )}
      <Text style={styles.title}>{title}</Text>
      {desc ? <Text style={styles.subtitle}>{desc}</Text> : null}
      {btnLabel && btnPress ? (
        <ActionButton
          title={btnLabel}
          onPress={btnPress}
          variant="secondary"
          style={styles.btn}
        />
      ) : null}
    </View>
  );
}

export { EmptyState };

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: spacing['2xl'],
    paddingHorizontal: spacing.lg,
  },
  iconWrap: {
    marginBottom: spacing.md,
  },
  title: {
    color: colors.textPrimary,
    fontSize: fontSize.md,
    fontWeight: fontWeight.semibold,
    marginTop: spacing.md,
    textAlign: 'center',
  },
  subtitle: {
    color: colors.textMuted,
    fontSize: fontSize.sm,
    marginTop: spacing.xs,
    textAlign: 'center',
    lineHeight: 20,
    maxWidth: 260,
  },
  btn: {
    marginTop: spacing.lg,
  },
});
