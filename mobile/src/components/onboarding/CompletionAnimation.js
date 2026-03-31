import React, { useEffect } from 'react';
import { View, Text, StyleSheet, Dimensions } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withDelay,
  withSequence,
  FadeIn,
  Easing,
} from 'react-native-reanimated';
import { colors, fontSize, fontWeight } from '../../theme/colors';

const { width: W, height: H } = Dimensions.get('window');
const PARTICLE_COUNT = 30;

function Particle({ index }) {
  const x = useSharedValue(W / 2);
  const y = useSharedValue(H / 2);
  const opacity = useSharedValue(1);
  const size = 4 + Math.random() * 6;
  const hue = [colors.primary, colors.accent, colors.warning, '#fbbf24'][index % 4];

  useEffect(() => {
    const angle = (index / PARTICLE_COUNT) * Math.PI * 2 + Math.random() * 0.5;
    const dist = 100 + Math.random() * 200;
    const dur = 1200 + Math.random() * 800;
    x.value = withDelay(100, withTiming(W / 2 + Math.cos(angle) * dist, { duration: dur }));
    y.value = withDelay(100, withTiming(H / 2 + Math.sin(angle) * dist + 120, { duration: dur, easing: Easing.out(Easing.quad) }));
    opacity.value = withDelay(dur * 0.6, withTiming(0, { duration: dur * 0.4 }));
  }, [index, x, y, opacity]);

  const style = useAnimatedStyle(() => ({
    position: 'absolute',
    left: x.value,
    top: y.value,
    width: size,
    height: size,
    borderRadius: size / 2,
    backgroundColor: hue,
    opacity: opacity.value,
  }));

  return <Animated.View style={style} />;
}

/**
 * Full-screen completion animation with confetti + message.
 * @param {{ name: string }} props
 */
export default function CompletionAnimation({ name }) {
  const flashOpacity = useSharedValue(0);

  useEffect(() => {
    flashOpacity.value = withSequence(
      withTiming(0.5, { duration: 150 }),
      withTiming(0, { duration: 350 }),
    );
  }, [flashOpacity]);

  const flashStyle = useAnimatedStyle(() => ({
    opacity: flashOpacity.value,
  }));

  return (
    <View style={styles.container} pointerEvents="none">
      <Animated.View style={[styles.flash, flashStyle]} />
      {Array.from({ length: PARTICLE_COUNT }, (_, i) => (
        <Particle key={i} index={i} />
      ))}
      <Animated.View entering={FadeIn.delay(400).duration(600)} style={styles.textWrap}>
        <Text style={styles.heading}>Welcome to Exerly,</Text>
        <Text style={styles.name}>{name}!</Text>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(8,8,16,0.95)',
    zIndex: 1000,
  },
  flash: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: '#fff',
  },
  textWrap: {
    alignItems: 'center',
    zIndex: 10,
  },
  heading: {
    color: colors.textPrimary,
    fontSize: fontSize['2xl'],
    fontWeight: fontWeight.bold,
  },
  name: {
    color: colors.primary,
    fontSize: fontSize['3xl'],
    fontWeight: fontWeight.extrabold,
    marginTop: 4,
  },
});
