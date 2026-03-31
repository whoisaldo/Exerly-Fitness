import React from 'react';
import { View, Text, TextInput, StyleSheet } from 'react-native';
import Animated, { FadeInUp } from 'react-native-reanimated';
import GlassCard from '../../../components/GlassCard';
import { colors, spacing, fontSize, fontWeight } from '../../../theme/colors';

export default function Step1Name({ data, update }) {
  return (
    <View style={styles.container}>
      <Animated.Text entering={FadeInUp.delay(100).duration(500)} style={styles.title}>
        First, what should we call you?
      </Animated.Text>
      <Animated.Text entering={FadeInUp.delay(250).duration(500)} style={styles.subtitle}>
        This is how we'll greet you in the app.
      </Animated.Text>

      <Animated.View entering={FadeInUp.delay(400).duration(500)}>
        <GlassCard glow style={styles.card}>
          <TextInput
            style={styles.input}
            placeholder="Your name"
            placeholderTextColor={colors.textMuted}
            value={data.name ?? ''}
            onChangeText={(v) => update({ name: v })}
            autoCapitalize="words"
            autoFocus
            returnKeyType="done"
            accessibilityLabel="Your name"
          />
        </GlassCard>
      </Animated.View>
    </View>
  );
}

export function validate(data) {
  return (data.name ?? '').trim().length >= 2;
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    paddingHorizontal: spacing.lg,
  },
  title: {
    color: colors.textPrimary,
    fontSize: fontSize['2xl'],
    fontWeight: fontWeight.bold,
    textAlign: 'center',
    letterSpacing: -0.4,
  },
  subtitle: {
    color: colors.textSecondary,
    fontSize: fontSize.sm,
    textAlign: 'center',
    marginTop: spacing.sm,
    marginBottom: spacing.xl,
  },
  card: {
    paddingVertical: 6,
    paddingHorizontal: 8,
  },
  input: {
    color: colors.textPrimary,
    fontSize: fontSize.xl,
    fontWeight: fontWeight.semibold,
    textAlign: 'center',
    paddingVertical: 14,
    minHeight: 52,
  },
});
