import React, { useCallback } from 'react';
import {
  Text,
  Pressable,
  ActivityIndicator,
  StyleSheet,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import { colors, radii, fontSize, fontWeight, gradients } from '../theme/colors';

/**
 * Multi-variant action button with haptic feedback.
 * Accepts label via `title` prop or `children`.
 * @param {{ title?: string, children?: React.ReactNode, onPress: () => void, variant?: 'primary'|'secondary'|'ghost'|'destructive', loading?: boolean, disabled?: boolean, icon?: React.ReactNode, style?: object, fullWidth?: boolean }} props
 */
export default function ActionButton({
  title,
  children,
  onPress,
  variant = 'primary',
  loading = false,
  disabled = false,
  icon,
  style,
  fullWidth = false,
}) {
  const label = title ?? children;

  const handlePress = useCallback(() => {
    if (loading || disabled) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    onPress?.();
  }, [loading, disabled, onPress]);

  const isDisabled = disabled || loading;
  const isPrimary = variant === 'primary';
  const isGhost = variant === 'ghost';
  const isDestructive = variant === 'destructive';

  const labelEl = loading ? (
    <ActivityIndicator
      color={isPrimary ? '#fff' : colors.primary}
      size="small"
    />
  ) : (
    <>
      {icon}
      <Text
        style={[
          styles.label,
          isPrimary && styles.labelPrimary,
          isGhost && styles.labelGhost,
          isDestructive && styles.labelDestructive,
        ]}
      >
        {label}
      </Text>
    </>
  );

  if (isPrimary) {
    return (
      <Pressable
        onPress={handlePress}
        disabled={isDisabled}
        accessibilityRole="button"
        accessibilityLabel={typeof label === 'string' ? label : undefined}
        accessibilityState={{ disabled: isDisabled }}
        style={({ pressed }) => [
          fullWidth && styles.fullWidth,
          pressed && styles.pressed,
          isDisabled && styles.disabled,
          style,
        ]}
      >
        <LinearGradient
          colors={gradients.primary}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.gradient}
        >
          {labelEl}
        </LinearGradient>
      </Pressable>
    );
  }

  return (
    <Pressable
      onPress={handlePress}
      disabled={isDisabled}
      accessibilityRole="button"
      accessibilityLabel={typeof label === 'string' ? label : undefined}
      accessibilityState={{ disabled: isDisabled }}
      style={({ pressed }) => [
        styles.base,
        variant === 'secondary' && styles.secondary,
        isGhost && styles.ghost,
        isDestructive && styles.destructive,
        pressed && styles.pressed,
        isDisabled && styles.disabled,
        fullWidth && styles.fullWidth,
        style,
      ]}
    >
      {labelEl}
    </Pressable>
  );
}

export { ActionButton };

const styles = StyleSheet.create({
  base: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    height: 48,
    borderRadius: radii.md,
    paddingHorizontal: 20,
    minWidth: 44,
    minHeight: 44,
  },
  gradient: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    height: 48,
    borderRadius: radii.md,
    paddingHorizontal: 24,
  },
  secondary: {
    backgroundColor: colors.glassBg,
    borderWidth: 1,
    borderColor: colors.borderAccent,
  },
  ghost: {
    backgroundColor: 'transparent',
  },
  destructive: {
    backgroundColor: `${colors.error}18`,
    borderWidth: 1,
    borderColor: `${colors.error}44`,
  },
  pressed: {
    opacity: 0.85,
    transform: [{ scale: 0.97 }],
  },
  disabled: {
    opacity: 0.5,
  },
  fullWidth: {
    width: '100%',
  },
  label: {
    fontSize: fontSize.base,
    fontWeight: fontWeight.semibold,
    color: colors.primary,
  },
  labelPrimary: {
    color: '#ffffff',
  },
  labelGhost: {
    color: colors.textMuted,
  },
  labelDestructive: {
    color: colors.error,
  },
});
