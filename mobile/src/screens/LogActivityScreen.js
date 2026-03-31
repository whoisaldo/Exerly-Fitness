import React, { useState } from 'react';
import {
  StyleSheet,
  Text,
  View,
  TextInput,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  Pressable,
  Alert,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { BlurView } from 'expo-blur';
import * as Haptics from 'expo-haptics';
import Slider from '@react-native-community/slider';
import Animated, { FadeInUp } from 'react-native-reanimated';
import { colors, gradients, spacing, radii, fontSize, fontWeight } from '../theme/colors';
import GlassCard from '../components/GlassCard';
import ActionButton from '../components/ActionButton';
import apiClient from '../api/client';

const INTENSITIES = [
  { id: 'light', label: 'Low', color: colors.success },
  { id: 'moderate', label: 'Med', color: colors.warning },
  { id: 'intense', label: 'High', color: colors.error },
];

export default function LogActivityScreen({ navigation }) {
  const [activity, setActivity] = useState('');
  const [duration, setDuration] = useState(30);
  const [calories, setCalories] = useState('');
  const [intensity, setIntensity] = useState('moderate');
  const [loading, setLoading] = useState(false);
  const [activityFocused, setActivityFocused] = useState(false);
  const [calFocused, setCalFocused] = useState(false);

  const handleSubmit = async () => {
    if (!activity || !calories) {
      Alert.alert('Missing Fields', 'Please fill in activity name and calories');
      return;
    }

    setLoading(true);
    try {
      await apiClient.post('/api/activities', {
        activity,
        duration_min: Math.round(duration),
        calories: parseInt(calories, 10),
        intensity,
      });
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
      Alert.alert('Success!', 'Activity logged successfully', [
        { text: 'OK', onPress: () => navigation.goBack() },
      ]);
    } catch (error) {
      Alert.alert('Error', error.message || 'Failed to log activity');
    } finally {
      setLoading(false);
    }
  };

  return (
    <LinearGradient
      colors={[colors.deep, colors.surface1, colors.dark]}
      locations={[0, 0.5, 1]}
      style={styles.container}
    >
      <SafeAreaView style={styles.safe} edges={['top', 'bottom']}>
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          style={styles.kav}
        >
          <ScrollView
            contentContainerStyle={styles.scroll}
            showsVerticalScrollIndicator={false}
            keyboardShouldPersistTaps="handled"
          >
            {/* Header */}
            <Animated.View entering={FadeInUp.delay(50).duration(500)}>
              <Pressable
                onPress={() => navigation.goBack()}
                style={styles.backBtn}
                hitSlop={12}
              >
                <Text style={styles.backText}>{'\u2190'} Back</Text>
              </Pressable>
              <Text style={styles.title}>Log Activity</Text>
            </Animated.View>

            {/* Form */}
            <Animated.View entering={FadeInUp.delay(150).duration(600)}>
              <GlassCard elevated style={styles.card}>
                <BlurView intensity={15} tint="dark" style={styles.blur}>
                  <View style={styles.cardInner}>
                    {/* Activity Name */}
                    <Text style={styles.label}>Activity Name</Text>
                    <TextInput
                      style={[
                        styles.input,
                        activityFocused && styles.inputFocused,
                      ]}
                      placeholder="e.g., Morning Run"
                      placeholderTextColor={colors.textMuted}
                      value={activity}
                      onChangeText={setActivity}
                      onFocus={() => setActivityFocused(true)}
                      onBlur={() => setActivityFocused(false)}
                    />

                    {/* Duration Slider */}
                    <Text style={styles.label}>Duration</Text>
                    <View style={styles.sliderWrap}>
                      <Text style={styles.sliderValue}>
                        {Math.round(duration)} min
                      </Text>
                      <Slider
                        style={styles.slider}
                        minimumValue={5}
                        maximumValue={180}
                        step={5}
                        value={duration}
                        onValueChange={setDuration}
                        minimumTrackTintColor={colors.primary}
                        maximumTrackTintColor={colors.surface3}
                        thumbTintColor={colors.primaryBright}
                      />
                      <View style={styles.sliderLabels}>
                        <Text style={styles.sliderMinMax}>5 min</Text>
                        <Text style={styles.sliderMinMax}>180 min</Text>
                      </View>
                    </View>

                    {/* Intensity Pills */}
                    <Text style={styles.label}>Intensity</Text>
                    <View style={styles.pillRow}>
                      {INTENSITIES.map((item) => {
                        const active = intensity === item.id;
                        return (
                          <Pressable
                            key={item.id}
                            onPress={() => {
                              setIntensity(item.id);
                              Haptics.selectionAsync();
                            }}
                            style={[
                              styles.pill,
                              active && {
                                backgroundColor: `${item.color}25`,
                                borderColor: item.color,
                              },
                            ]}
                          >
                            <Text
                              style={[
                                styles.pillText,
                                active && { color: item.color },
                              ]}
                            >
                              {item.label}
                            </Text>
                          </Pressable>
                        );
                      })}
                    </View>

                    {/* Calories */}
                    <Text style={styles.label}>Calories Burned</Text>
                    <TextInput
                      style={[
                        styles.input,
                        calFocused && styles.inputFocused,
                      ]}
                      placeholder="250"
                      placeholderTextColor={colors.textMuted}
                      value={calories}
                      onChangeText={setCalories}
                      onFocus={() => setCalFocused(true)}
                      onBlur={() => setCalFocused(false)}
                      keyboardType="numeric"
                    />

                    {/* Submit */}
                    <ActionButton
                      variant="primary"
                      onPress={handleSubmit}
                      loading={loading}
                      style={styles.submitBtn}
                    >
                      Log Activity
                    </ActionButton>
                  </View>
                </BlurView>
              </GlassCard>
            </Animated.View>
          </ScrollView>
        </KeyboardAvoidingView>
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
  kav: {
    flex: 1,
  },
  scroll: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
    paddingBottom: spacing['2xl'],
  },
  backBtn: {
    minWidth: 44,
    minHeight: 44,
    justifyContent: 'center',
    marginBottom: spacing.xs,
  },
  backText: {
    color: colors.primaryBright,
    fontSize: fontSize.base,
    fontWeight: fontWeight.medium,
  },
  title: {
    fontSize: fontSize['2xl'],
    fontWeight: fontWeight.bold,
    color: colors.textPrimary,
    marginBottom: spacing.lg,
  },
  card: {
    padding: 0,
    overflow: 'hidden',
  },
  blur: {
    overflow: 'hidden',
    borderRadius: radii.lg,
  },
  cardInner: {
    padding: spacing.lg,
  },
  label: {
    fontSize: fontSize.sm,
    fontWeight: fontWeight.semibold,
    color: colors.textSecondary,
    marginBottom: spacing.sm,
    marginTop: spacing.md,
    textTransform: 'uppercase',
    letterSpacing: 0.8,
  },
  input: {
    backgroundColor: 'rgba(255,255,255,0.04)',
    borderWidth: 1,
    borderColor: colors.borderSubtle,
    borderRadius: radii.md,
    paddingHorizontal: spacing.md,
    paddingVertical: 14,
    color: colors.textPrimary,
    fontSize: fontSize.base,
    minHeight: 48,
  },
  inputFocused: {
    borderColor: colors.borderAccent,
  },
  sliderWrap: {
    paddingVertical: spacing.sm,
  },
  sliderValue: {
    fontSize: fontSize['2xl'],
    fontWeight: fontWeight.bold,
    color: colors.primaryBright,
    textAlign: 'center',
    marginBottom: spacing.sm,
  },
  slider: {
    width: '100%',
    height: 44,
  },
  sliderLabels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  sliderMinMax: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
  },
  pillRow: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  pill: {
    flex: 1,
    backgroundColor: 'rgba(255,255,255,0.04)',
    borderWidth: 1,
    borderColor: colors.borderSubtle,
    borderRadius: radii.full,
    paddingVertical: 12,
    alignItems: 'center',
    minHeight: 44,
    justifyContent: 'center',
  },
  pillText: {
    fontSize: fontSize.sm,
    fontWeight: fontWeight.semibold,
    color: colors.textMuted,
  },
  submitBtn: {
    marginTop: spacing.xl,
    minHeight: 52,
  },
});
