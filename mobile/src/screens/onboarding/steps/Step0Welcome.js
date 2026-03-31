import React from 'react';
import { View, Text, StyleSheet, Dimensions } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { Ionicons } from '@expo/vector-icons';
import Animated, {
  FadeIn,
  FadeInUp,
  useSharedValue,
  useAnimatedStyle,
  withRepeat,
  withTiming,
  withDelay,
  Easing,
} from 'react-native-reanimated';
import GlassCard from '../../../components/GlassCard';
import {
  colors,
  gradients,
  spacing,
  fontSize,
  fontWeight,
  radii,
} from '../../../theme/colors';

const { width: W, height: H } = Dimensions.get('window');

const VALUE_PROPS = [
  {
    icon: 'nutrition-outline',
    title: 'Personalized Nutrition',
    desc: 'AI-calculated macros & calorie targets tailored to your body',
  },
  {
    icon: 'barbell-outline',
    title: 'Smart Workout Plans',
    desc: 'Built around your goals, equipment, and schedule',
  },
  {
    icon: 'trending-up-outline',
    title: 'Progress Tracking',
    desc: 'Streaks, achievements, body stats — all in one place',
  },
];

function Orb({ size, x, y, delay, color }) {
  const ty = useSharedValue(0);
  const tx = useSharedValue(0);

  React.useEffect(() => {
    ty.value = withDelay(
      delay,
      withRepeat(withTiming(20, { duration: 5000, easing: Easing.inOut(Easing.ease) }), -1, true),
    );
    tx.value = withDelay(
      delay + 400,
      withRepeat(withTiming(14, { duration: 6000, easing: Easing.inOut(Easing.ease) }), -1, true),
    );
  }, [ty, tx, delay]);

  const style = useAnimatedStyle(() => ({
    transform: [{ translateY: ty.value }, { translateX: tx.value }],
  }));

  return (
    <Animated.View
      entering={FadeIn.delay(delay).duration(1200)}
      style={[styles.orb, { width: size, height: size, borderRadius: size / 2, left: x, top: y }, style]}
    >
      <LinearGradient colors={[color, 'transparent']} style={styles.orbGrad} start={{ x: 0.5, y: 0 }} end={{ x: 0.5, y: 1 }} />
    </Animated.View>
  );
}

function PropCard({ item, index }) {
  return (
    <Animated.View entering={FadeInUp.delay(600 + index * 150).duration(500).springify()}>
      <GlassCard style={styles.propCard}>
        <View style={styles.propRow}>
          <View style={styles.propIcon}>
            <Ionicons name={item.icon} size={22} color={colors.primary} />
          </View>
          <View style={styles.propText}>
            <Text style={styles.propTitle}>{item.title}</Text>
            <Text style={styles.propDesc}>{item.desc}</Text>
          </View>
        </View>
      </GlassCard>
    </Animated.View>
  );
}

export default function Step0Welcome() {
  return (
    <View style={styles.container}>
      {/* Background orbs */}
      <View style={styles.orbWrap} pointerEvents="none">
        <Orb size={260} x={W * 0.45} y={-50} delay={0} color="rgba(139,92,246,0.12)" />
        <Orb size={180} x={-70} y={H * 0.35} delay={500} color="rgba(236,72,153,0.09)" />
        <Orb size={120} x={W * 0.55} y={H * 0.55} delay={1000} color="rgba(168,85,247,0.07)" />
      </View>

      {/* Logo + brand */}
      <Animated.View entering={FadeInUp.delay(100).duration(700).springify()} style={styles.brand}>
        <View style={styles.logoShadow}>
          <LinearGradient colors={gradients.primary} style={styles.logo} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }}>
            <Text style={styles.logoLetter}>E</Text>
          </LinearGradient>
        </View>
        <Text style={styles.appName}>Exerly</Text>
        <Text style={styles.tagline}>Train smarter. Live stronger.</Text>
      </Animated.View>

      {/* Value props */}
      <View style={styles.props}>
        {VALUE_PROPS.map((item, i) => (
          <PropCard key={item.title} item={item} index={i} />
        ))}
      </View>

      {/* Footer hint */}
      <Animated.Text entering={FadeIn.delay(1200).duration(600)} style={styles.hint}>
        Takes about 3 minutes
      </Animated.Text>
    </View>
  );
}

export function validate() {
  return true;
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingHorizontal: spacing.lg,
    justifyContent: 'center',
  },
  orbWrap: {
    ...StyleSheet.absoluteFillObject,
    overflow: 'hidden',
  },
  orb: {
    position: 'absolute',
    overflow: 'hidden',
  },
  orbGrad: {
    flex: 1,
    borderRadius: 9999,
  },
  brand: {
    alignItems: 'center',
    marginBottom: spacing.xl,
  },
  logoShadow: {
    shadowColor: colors.primary,
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.45,
    shadowRadius: 24,
    elevation: 12,
    marginBottom: spacing.md,
  },
  logo: {
    width: 80,
    height: 80,
    borderRadius: radii.xl,
    alignItems: 'center',
    justifyContent: 'center',
  },
  logoLetter: {
    color: '#fff',
    fontSize: 40,
    fontWeight: fontWeight.extrabold,
    letterSpacing: -2,
  },
  appName: {
    color: colors.textPrimary,
    fontSize: fontSize['3xl'],
    fontWeight: fontWeight.extrabold,
    letterSpacing: -1.2,
  },
  tagline: {
    color: colors.textSecondary,
    fontSize: fontSize.base,
    fontWeight: fontWeight.medium,
    marginTop: spacing.xs,
  },
  props: {
    gap: spacing.sm,
  },
  propCard: {
    paddingVertical: 14,
    paddingHorizontal: 14,
  },
  propRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  propIcon: {
    width: 42,
    height: 42,
    borderRadius: 21,
    backgroundColor: `${colors.primary}18`,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 14,
  },
  propText: {
    flex: 1,
  },
  propTitle: {
    color: colors.textPrimary,
    fontSize: fontSize.sm,
    fontWeight: fontWeight.semibold,
  },
  propDesc: {
    color: colors.textMuted,
    fontSize: fontSize.xs,
    marginTop: 2,
    lineHeight: 17,
  },
  hint: {
    color: colors.textMuted,
    fontSize: fontSize.xs,
    textAlign: 'center',
    marginTop: spacing.xl,
  },
});
