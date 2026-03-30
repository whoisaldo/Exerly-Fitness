import React from 'react';
import { StyleSheet, Text, View, Dimensions } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
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
import { colors, gradients, spacing, radii, fontSize, fontWeight } from '../theme/colors';
import { ActionButton } from '../components/ActionButton';

const { width, height } = Dimensions.get('window');

function AnimatedOrb({ size, x, y, delay, color }) {
  const translateY = useSharedValue(0);
  const translateX = useSharedValue(0);

  React.useEffect(() => {
    translateY.value = withDelay(
      delay,
      withRepeat(
        withTiming(24, { duration: 4000, easing: Easing.inOut(Easing.ease) }),
        -1,
        true,
      ),
    );
    translateX.value = withDelay(
      delay + 500,
      withRepeat(
        withTiming(16, { duration: 5000, easing: Easing.inOut(Easing.ease) }),
        -1,
        true,
      ),
    );
  }, [translateY, translateX, delay]);

  const animStyle = useAnimatedStyle(() => ({
    transform: [
      { translateY: translateY.value },
      { translateX: translateX.value },
    ],
  }));

  return (
    <Animated.View
      entering={FadeIn.delay(delay).duration(1200)}
      style={[
        styles.orb,
        { width: size, height: size, borderRadius: size / 2, left: x, top: y },
        animStyle,
      ]}
    >
      <LinearGradient
        colors={[color, 'transparent']}
        style={styles.orbGradient}
        start={{ x: 0.5, y: 0 }}
        end={{ x: 0.5, y: 1 }}
      />
    </Animated.View>
  );
}

export default function WelcomeScreen({ navigation }) {
  return (
    <LinearGradient
      colors={[colors.deep, colors.surface1, colors.dark]}
      locations={[0, 0.5, 1]}
      style={styles.container}
    >
      <SafeAreaView style={styles.safe} edges={['top', 'bottom']}>
        {/* Animated background orbs */}
        <View style={styles.orbContainer} pointerEvents="none">
          <AnimatedOrb
            size={280}
            x={width * 0.5}
            y={-60}
            delay={0}
            color="rgba(139,92,246,0.12)"
          />
          <AnimatedOrb
            size={200}
            x={-80}
            y={height * 0.55}
            delay={600}
            color="rgba(236,72,153,0.10)"
          />
          <AnimatedOrb
            size={140}
            x={width * 0.6}
            y={height * 0.7}
            delay={1200}
            color="rgba(168,85,247,0.08)"
          />
        </View>

        <View style={styles.content}>
          {/* Logo + Tagline */}
          <Animated.View
            entering={FadeInUp.delay(200).duration(800).springify()}
            style={styles.logoSection}
          >
            <View style={styles.logoWrap}>
              <LinearGradient
                colors={gradients.primary}
                style={styles.logoGradient}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
              >
                <Text style={styles.logoIcon}>E</Text>
              </LinearGradient>
            </View>
            <Text style={styles.brand}>Exerly</Text>
            <Text style={styles.tagline}>Train smarter. Live stronger.</Text>
          </Animated.View>

          {/* Spacer */}
          <View style={styles.spacer} />

          {/* CTA Buttons */}
          <Animated.View
            entering={FadeInUp.delay(500).duration(700).springify()}
            style={styles.cta}
          >
            <ActionButton
              variant="primary"
              onPress={() => navigation.navigate('Signup')}
              style={styles.ctaButton}
            >
              Get Started
            </ActionButton>
            <ActionButton
              variant="ghost"
              onPress={() => navigation.navigate('Login')}
              style={styles.ctaButton}
            >
              Log In
            </ActionButton>
          </Animated.View>
        </View>
      </SafeAreaView>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  safe: {
    flex: 1,
  },
  orbContainer: {
    ...StyleSheet.absoluteFillObject,
    overflow: 'hidden',
  },
  orb: {
    position: 'absolute',
    overflow: 'hidden',
  },
  orbGradient: {
    flex: 1,
    borderRadius: 9999,
  },
  content: {
    flex: 1,
    paddingHorizontal: spacing.lg,
    justifyContent: 'center',
  },
  logoSection: {
    alignItems: 'center',
    marginTop: spacing['3xl'],
  },
  logoWrap: {
    width: 88,
    height: 88,
    borderRadius: radii.xl,
    overflow: 'hidden',
    marginBottom: spacing.lg,
    shadowColor: colors.primary,
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.4,
    shadowRadius: 28,
    elevation: 12,
  },
  logoGradient: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  logoIcon: {
    fontSize: 42,
    fontWeight: fontWeight.extrabold,
    color: '#fff',
    letterSpacing: -2,
  },
  brand: {
    fontSize: fontSize.display,
    fontWeight: fontWeight.extrabold,
    color: colors.textPrimary,
    letterSpacing: -1.5,
  },
  tagline: {
    fontSize: fontSize.md,
    fontWeight: fontWeight.medium,
    color: colors.textSecondary,
    marginTop: spacing.xs,
    letterSpacing: 0.3,
  },
  spacer: {
    flex: 1,
  },
  cta: {
    gap: spacing.md,
    paddingBottom: spacing.xl,
  },
  ctaButton: {
    minHeight: 52,
  },
});
