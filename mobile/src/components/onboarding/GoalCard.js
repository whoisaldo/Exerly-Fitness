import React from 'react';
import { Pressable, Text, View, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import Animated, { useAnimatedStyle, withSpring, useSharedValue } from 'react-native-reanimated';
import GlassCard from '../GlassCard';
import { colors, spacing, fontSize, fontWeight, radii } from '../../theme/colors';

/**
 * Selectable card for goal/option lists.
 * @param {{ icon?: string, title: string, subtitle?: string, selected: boolean, onPress: () => void }} props
 */
export default function GoalCard({ icon, title, subtitle, selected, onPress }) {
  const scale = useSharedValue(1);
  const animStyle = useAnimatedStyle(() => ({ transform: [{ scale: scale.value }] }));

  const handlePress = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    scale.value = withSpring(0.96, { damping: 15 });
    setTimeout(() => { scale.value = withSpring(1, { damping: 15 }); }, 100);
    onPress();
  };

  return (
    <Animated.View style={animStyle}>
      <Pressable onPress={handlePress} accessibilityRole="radio" accessibilityState={{ selected }}>
        <GlassCard style={[styles.card, selected && styles.cardSelected]}>
          <View style={styles.row}>
            {icon ? <Text style={styles.icon}>{icon}</Text> : null}
            <View style={styles.text}>
              <Text style={styles.title}>{title}</Text>
              {subtitle ? <Text style={styles.subtitle}>{subtitle}</Text> : null}
            </View>
            {selected && (
              <View style={styles.check}>
                <Ionicons name="checkmark" size={16} color="#fff" />
              </View>
            )}
          </View>
        </GlassCard>
      </Pressable>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  card: { marginBottom: spacing.sm },
  cardSelected: {
    borderColor: colors.borderAccent,
    shadowColor: colors.primary,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 8,
    elevation: 4,
  },
  row: { flexDirection: 'row', alignItems: 'center' },
  icon: { fontSize: 24, marginRight: spacing.md },
  text: { flex: 1 },
  title: {
    color: colors.textPrimary,
    fontSize: fontSize.base,
    fontWeight: fontWeight.semibold,
  },
  subtitle: {
    color: colors.textMuted,
    fontSize: fontSize.xs,
    marginTop: 2,
  },
  check: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
