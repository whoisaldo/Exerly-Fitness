import React, { useEffect, useRef } from 'react';
import { View, Animated, StyleSheet } from 'react-native';
import { colors, radii } from '../theme/colors';

const variantStyles = {
  card: { height: 160, borderRadius: radii.lg },
  stat: { height: 112, borderRadius: radii.lg },
  'table-row': { height: 48, borderRadius: radii.sm },
  text: { height: 16, width: '75%', borderRadius: radii.sm },
  circle: { height: 48, width: 48, borderRadius: radii.full },
};

function SkeletonItem({ variant = 'card', style }) {
  const opacity = useRef(new Animated.Value(0.3)).current;

  useEffect(() => {
    const anim = Animated.loop(
      Animated.sequence([
        Animated.timing(opacity, {
          toValue: 0.7,
          duration: 800,
          useNativeDriver: true,
        }),
        Animated.timing(opacity, {
          toValue: 0.3,
          duration: 800,
          useNativeDriver: true,
        }),
      ]),
    );
    anim.start();
    return () => anim.stop();
  }, [opacity]);

  const vs = variantStyles[variant] || variantStyles.card;

  return (
    <Animated.View
      style={[styles.base, vs, { opacity }, style]}
    />
  );
}

export function LoadingSkeleton({ variant = 'card', count = 1, style }) {
  return (
    <View style={style}>
      {Array.from({ length: count }, (_, i) => (
        <SkeletonItem key={i} variant={variant} style={i > 0 && styles.gap} />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  base: {
    backgroundColor: colors.surface3,
    width: '100%',
  },
  gap: {
    marginTop: 12,
  },
});
