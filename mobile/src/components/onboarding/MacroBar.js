import React, { useEffect } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  Easing,
} from 'react-native-reanimated';
import { colors, fontSize, fontWeight, radii } from '../../theme/colors';

/**
 * Animated horizontal macro bar.
 * @param {{ label: string, grams: number, totalCal: number, color: string, percent: number }} props
 */
export default function MacroBar({ label, grams, totalCal, color, percent }) {
  const width = useSharedValue(0);

  useEffect(() => {
    width.value = withTiming(Math.min(percent, 100), {
      duration: 800,
      easing: Easing.out(Easing.cubic),
    });
  }, [percent, width]);

  const barStyle = useAnimatedStyle(() => ({
    width: `${width.value}%`,
    backgroundColor: color,
  }));

  const cal = grams * (label === 'Fat' ? 9 : 4);

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={[styles.label, { color }]}>{label}</Text>
        <Text style={styles.value}>{grams}g · {cal} cal</Text>
      </View>
      <View style={styles.track}>
        <Animated.View style={[styles.fill, barStyle]} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { marginBottom: 14 },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 4,
  },
  label: {
    fontSize: fontSize.sm,
    fontWeight: fontWeight.semibold,
  },
  value: {
    color: colors.textSecondary,
    fontSize: fontSize.xs,
  },
  track: {
    height: 8,
    backgroundColor: colors.surface3,
    borderRadius: radii.sm,
    overflow: 'hidden',
  },
  fill: {
    height: '100%',
    borderRadius: radii.sm,
  },
});
