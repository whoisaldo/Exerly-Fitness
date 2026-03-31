import React, { useEffect } from 'react';
import { View, StyleSheet } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withRepeat,
  withSequence,
  withTiming,
} from 'react-native-reanimated';
import { colors, radii } from '../theme/colors';

const VARIANT_DIMS = {
  card: { height: 160, borderRadius: radii.lg },
  stat: { height: 112, borderRadius: radii.lg },
  row: { height: 48, borderRadius: radii.sm },
  'table-row': { height: 48, borderRadius: radii.sm },
  text: { height: 16, width: '75%', borderRadius: radii.sm },
  circle: { height: 48, width: 48, borderRadius: radii.full },
};

function SkeletonItem({ variant = 'card', style }) {
  const opacity = useSharedValue(0.3);

  useEffect(() => {
    opacity.value = withRepeat(
      withSequence(
        withTiming(0.7, { duration: 800 }),
        withTiming(0.3, { duration: 800 }),
      ),
      -1,
      false,
    );
  }, [opacity]);

  const animStyle = useAnimatedStyle(() => ({ opacity: opacity.value }));
  const vs = VARIANT_DIMS[variant] ?? VARIANT_DIMS.card;

  return (
    <Animated.View
      style={[styles.base, vs, animStyle, style]}
      accessibilityRole="progressbar"
      accessibilityLabel="Loading"
    />
  );
}

/**
 * Pulsing skeleton placeholder.
 * @param {{ variant?: string, count?: number, width?: number|string, height?: number, style?: object }} props
 */
export default function LoadingSkeleton({ variant = 'card', count = 1, width, height, style }) {
  return (
    <View style={style}>
      {Array.from({ length: count }, (_, i) => (
        <SkeletonItem
          key={i}
          variant={variant}
          style={[i > 0 && styles.gap, width != null && { width }, height != null && { height }]}
        />
      ))}
    </View>
  );
}

export { LoadingSkeleton };

const styles = StyleSheet.create({
  base: {
    backgroundColor: colors.surface3,
    width: '100%',
  },
  gap: {
    marginTop: 12,
  },
});
