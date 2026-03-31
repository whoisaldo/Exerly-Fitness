import React, { useState, useCallback, useEffect } from 'react';
import {
  View,
  Text,
  Pressable,
  KeyboardAvoidingView,
  Platform,
  StyleSheet,
  Dimensions,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  FadeIn,
  FadeInDown,
} from 'react-native-reanimated';
import { colors, spacing, fontSize, fontWeight, radii } from '../../theme/colors';
import ActionButton from '../../components/ActionButton';
import CompletionAnimation from '../../components/onboarding/CompletionAnimation';
import { saveProgress, completeOnboarding } from '../../services/WizardService';

import Step0Welcome, { validate as v0 } from './steps/Step0Welcome';
import Step1Name, { validate as v1 } from './steps/Step1Name';
import Step2AgeGender, { validate as v2 } from './steps/Step2AgeGender';
import Step3HeightWeight, { validate as v3 } from './steps/Step3HeightWeight';
import Step4Goals, { validate as v4 } from './steps/Step4Goals';
import Step5ActivityLevel, { validate as v5 } from './steps/Step5ActivityLevel';
import Step6ActivityTypes, { validate as v6 } from './steps/Step6ActivityTypes';
import Step7Diet, { validate as v7 } from './steps/Step7Diet';
import Step8Sleep, { validate as v8 } from './steps/Step8Sleep';
import Step9Equipment, { validate as v9 } from './steps/Step9Equipment';
import Step10Results, { validate as v10 } from './steps/Step10Results';
import Step11Notifications, { validate as v11 } from './steps/Step11Notifications';

const STEPS = [
  { Component: Step0Welcome, validate: v0, section: null },
  { Component: Step1Name, validate: v1, section: null },
  { Component: Step2AgeGender, validate: v2, section: 'About You' },
  { Component: Step3HeightWeight, validate: v3, section: null },
  { Component: Step4Goals, validate: v4, section: 'Your Goals' },
  { Component: Step5ActivityLevel, validate: v5, section: null },
  { Component: Step6ActivityTypes, validate: v6, section: 'Your Lifestyle' },
  { Component: Step7Diet, validate: v7, section: null },
  { Component: Step8Sleep, validate: v8, section: 'Your Setup' },
  { Component: Step9Equipment, validate: v9, section: null },
  { Component: Step10Results, validate: v10, section: 'Your Plan' },
  { Component: Step11Notifications, validate: v11, section: 'Final Touch' },
];

const TOTAL = STEPS.length;
const DISPLAY_TOTAL = TOTAL - 1; // Don't count Step0 in user-facing counter
const { width: SCREEN_W } = Dimensions.get('window');
const SPRING = { damping: 20, stiffness: 90 };

const DEFAULTS = {
  name: '',
  age: 25,
  gender: null,
  heightCm: 170,
  weightKg: 70,
  unitPreference: 'metric',
  primaryGoal: null,
  targetWeightKg: null,
  goalTimelineWeeks: 12,
  fitnessLevel: null,
  workoutsPerWeek: 3,
  activityTypes: [],
  dietaryStyle: [],
  allergies: ['None'],
  mealsPerDay: 3,
  sleepGoalHours: 7.5,
  wakeTime: '07:00',
  gymAccess: false,
  equipment: ['bodyweight'],
  notifications: {
    dailyReminder: true,
    reminderTime: '20:00',
    weeklyReport: true,
    streakAlerts: true,
    achievementAlerts: true,
  },
};

function sanitizeStepIndex(value) {
  const parsed = Number.isFinite(value) ? value : 0;
  return Math.min(Math.max(parsed, 0), TOTAL - 1);
}

function mergeWizardData(initialData) {
  return {
    ...DEFAULTS,
    ...(initialData ?? {}),
    notifications: {
      ...DEFAULTS.notifications,
      ...(initialData?.notifications ?? {}),
    },
  };
}

export default function OnboardingWizard({ initialStep, initialData, onComplete }) {
  const safeInitialStep = sanitizeStepIndex(initialStep);
  const [step, setStep] = useState(safeInitialStep);
  const [data, setData] = useState(() => mergeWizardData(initialData));
  const [completing, setCompleting] = useState(false);
  const [showComplete, setShowComplete] = useState(false);
  const translateX = useSharedValue(0);
  const progressWidth = useSharedValue((safeInitialStep / DISPLAY_TOTAL) * 100);

  const update = useCallback((partial) => {
    setData((prev) => ({ ...prev, ...partial }));
  }, []);

  useEffect(() => {
    if (step > 0 && !showComplete) {
      saveProgress(step, data).catch(() => {});
    }
  }, [step, data, showComplete]);

  const goNext = useCallback(async () => {
    if (step >= TOTAL - 1) {
      setCompleting(true);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      try { await completeOnboarding(data); } catch { /* offline ok */ }
      setShowComplete(true);
      setTimeout(() => onComplete?.(), 3000);
      return;
    }

    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    const next = step + 1;
    translateX.value = withSpring(-SCREEN_W, SPRING);
    setTimeout(() => {
      setStep(next);
      translateX.value = SCREEN_W;
      translateX.value = withSpring(0, SPRING);
      progressWidth.value = withSpring((next / DISPLAY_TOTAL) * 100, SPRING);
    }, 200);
  }, [step, data, translateX, progressWidth, onComplete]);

  const goBack = useCallback(() => {
    if (step <= 0) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    const prev = step - 1;
    translateX.value = withSpring(SCREEN_W, SPRING);
    setTimeout(() => {
      setStep(prev);
      translateX.value = -SCREEN_W;
      translateX.value = withSpring(0, SPRING);
      progressWidth.value = withSpring((prev / DISPLAY_TOTAL) * 100, SPRING);
    }, 200);
  }, [step, translateX, progressWidth]);

  const { Component, validate, section } = STEPS[step];
  const isValid = validate(data);
  const isLast = step === TOTAL - 1;
  const isWelcome = step === 0;

  const slideStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: translateX.value }],
  }));
  const barStyle = useAnimatedStyle(() => ({
    width: `${progressWidth.value}%`,
  }));

  if (showComplete) {
    return <CompletionAnimation name={(data.name ?? '').split(' ')[0]} />;
  }

  return (
    <LinearGradient
      colors={[colors.deep, colors.surface1, colors.dark]}
      locations={[0, 0.5, 1]}
      style={styles.container}
    >
      <SafeAreaView style={styles.safe} edges={['top', 'bottom']}>
        {/* Top bar — hidden on welcome */}
        {!isWelcome && (
          <View style={styles.topBar}>
            <Pressable onPress={goBack} style={styles.backBtn} accessibilityLabel="Go back">
              <Ionicons name="chevron-back" size={24} color={colors.textPrimary} />
            </Pressable>
            <View style={styles.progressTrack}>
              <Animated.View style={[styles.progressFill, barStyle]} />
            </View>
            <Text style={styles.stepCounter}>{step} of {DISPLAY_TOTAL}</Text>
          </View>
        )}

        {/* Section label */}
        {section && !isWelcome && (
          <Animated.View entering={FadeInDown.duration(350)} style={styles.sectionWrap}>
            <View style={styles.sectionBadge}>
              <Text style={styles.sectionText}>{section}</Text>
            </View>
          </Animated.View>
        )}

        {/* Step content */}
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
          style={styles.content}
          keyboardVerticalOffset={100}
        >
          <Animated.View style={[styles.stepWrap, slideStyle]}>
            <Component data={data} update={update} />
          </Animated.View>
        </KeyboardAvoidingView>

        {/* Bottom CTA */}
        <Animated.View entering={FadeIn.duration(300)} style={styles.bottomBar}>
          <ActionButton
            title={isWelcome ? "Let's set up your profile" : isLast ? 'Finish Setup' : 'Continue'}
            onPress={goNext}
            disabled={!isValid}
            loading={completing}
            fullWidth
          />
        </Animated.View>
      </SafeAreaView>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  safe: { flex: 1 },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    gap: spacing.sm,
  },
  backBtn: {
    width: 44,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  progressTrack: {
    flex: 1,
    height: 4,
    backgroundColor: colors.surface2,
    borderRadius: 2,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: colors.primary,
    borderRadius: 2,
  },
  stepCounter: {
    color: colors.textMuted,
    fontSize: fontSize.xs,
    fontWeight: fontWeight.medium,
    minWidth: 50,
    textAlign: 'right',
  },
  sectionWrap: {
    alignItems: 'center',
    paddingBottom: spacing.xs,
  },
  sectionBadge: {
    backgroundColor: `${colors.primary}15`,
    borderWidth: 1,
    borderColor: `${colors.primary}30`,
    borderRadius: radii.full,
    paddingHorizontal: 14,
    paddingVertical: 5,
  },
  sectionText: {
    color: colors.primary,
    fontSize: fontSize.xs,
    fontWeight: fontWeight.semibold,
    letterSpacing: 0.5,
  },
  content: { flex: 1 },
  stepWrap: { flex: 1 },
  bottomBar: {
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.md,
    paddingTop: spacing.sm,
  },
});
