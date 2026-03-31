import React, { useState } from 'react';
import {
  StyleSheet,
  Text,
  View,
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
import DateTimePicker from '@react-native-community/datetimepicker';
import Animated, { FadeInUp } from 'react-native-reanimated';
import { colors, gradients, spacing, radii, fontSize, fontWeight } from '../theme/colors';
import GlassCard from '../components/GlassCard';
import ActionButton from '../components/ActionButton';
import apiClient from '../api/client';

const QUALITY_OPTIONS = [
  { id: 'poor', emoji: '\u{1F62B}', label: 'Poor' },
  { id: 'fair', emoji: '\u{1F610}', label: 'Fair' },
  { id: 'good', emoji: '\u{1F60A}', label: 'Good' },
  { id: 'great', emoji: '\u{1F60D}', label: 'Great' },
  { id: 'excellent', emoji: '\u{1F634}', label: 'Perfect' },
];

function formatTime(date) {
  return date.toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  });
}

export default function LogSleepScreen({ navigation }) {
  const [hours, setHours] = useState(7);
  const [quality, setQuality] = useState('good');
  const [bedtime, setBedtime] = useState(new Date(2026, 0, 1, 22, 30));
  const [wakeTime, setWakeTime] = useState(new Date(2026, 0, 1, 6, 30));
  const [showBedPicker, setShowBedPicker] = useState(false);
  const [showWakePicker, setShowWakePicker] = useState(false);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async () => {
    if (hours <= 0) {
      Alert.alert('Invalid', 'Please set hours slept');
      return;
    }

    setLoading(true);
    try {
      await apiClient.post('/api/sleep', {
        hours: parseFloat(hours.toFixed(1)),
        quality,
        bedtime: formatTime(bedtime),
        wakeTime: formatTime(wakeTime),
      });
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
      Alert.alert('Success!', 'Sleep logged successfully', [
        { text: 'OK', onPress: () => navigation.goBack() },
      ]);
    } catch (error) {
      Alert.alert('Error', error.message || 'Failed to log sleep');
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
              <Text style={styles.title}>Log Sleep</Text>
            </Animated.View>

            {/* Form */}
            <Animated.View entering={FadeInUp.delay(150).duration(600)}>
              <GlassCard elevated style={styles.card}>
                <BlurView intensity={15} tint="dark" style={styles.blur}>
                  <View style={styles.cardInner}>
                    {/* Hours Slider */}
                    <Text style={styles.label}>Hours Slept</Text>
                    <View style={styles.hoursDisplay}>
                      <Text style={styles.hoursValue}>
                        {hours.toFixed(1)}
                      </Text>
                      <Text style={styles.hoursUnit}>hours</Text>
                    </View>
                    <Slider
                      style={styles.slider}
                      minimumValue={0}
                      maximumValue={12}
                      step={0.5}
                      value={hours}
                      onValueChange={(val) => {
                        setHours(val);
                        if (val % 1 === 0) Haptics.selectionAsync();
                      }}
                      minimumTrackTintColor={colors.sleep}
                      maximumTrackTintColor={colors.surface3}
                      thumbTintColor={colors.primaryBright}
                    />
                    <View style={styles.sliderLabels}>
                      <Text style={styles.sliderMinMax}>0h</Text>
                      <Text style={styles.sliderMinMax}>12h</Text>
                    </View>

                    {/* Quality — emoji scale */}
                    <Text style={styles.label}>Sleep Quality</Text>
                    <View style={styles.qualityRow}>
                      {QUALITY_OPTIONS.map((opt) => {
                        const active = quality === opt.id;
                        return (
                          <Pressable
                            key={opt.id}
                            onPress={() => {
                              setQuality(opt.id);
                              Haptics.selectionAsync();
                            }}
                            style={[
                              styles.qualityBtn,
                              active && styles.qualityBtnActive,
                            ]}
                          >
                            <Text
                              style={[
                                styles.qualityEmoji,
                                active && styles.qualityEmojiActive,
                              ]}
                            >
                              {opt.emoji}
                            </Text>
                            <Text
                              style={[
                                styles.qualityLabel,
                                active && styles.qualityLabelActive,
                              ]}
                            >
                              {opt.label}
                            </Text>
                          </Pressable>
                        );
                      })}
                    </View>

                    {/* Bedtime & Wake Time */}
                    <Text style={styles.label}>Schedule</Text>
                    <View style={styles.timeRow}>
                      <Pressable
                        onPress={() => setShowBedPicker(true)}
                        style={styles.timeBtn}
                      >
                        <Text style={styles.timeBtnLabel}>Bedtime</Text>
                        <Text style={styles.timeBtnValue}>
                          {formatTime(bedtime)}
                        </Text>
                      </Pressable>
                      <Pressable
                        onPress={() => setShowWakePicker(true)}
                        style={styles.timeBtn}
                      >
                        <Text style={styles.timeBtnLabel}>Wake Up</Text>
                        <Text style={styles.timeBtnValue}>
                          {formatTime(wakeTime)}
                        </Text>
                      </Pressable>
                    </View>

                    {showBedPicker && (
                      <DateTimePicker
                        value={bedtime}
                        mode="time"
                        display={Platform.OS === 'ios' ? 'spinner' : 'default'}
                        onChange={(e, date) => {
                          setShowBedPicker(Platform.OS === 'ios');
                          if (date) setBedtime(date);
                        }}
                        themeVariant="dark"
                      />
                    )}
                    {showWakePicker && (
                      <DateTimePicker
                        value={wakeTime}
                        mode="time"
                        display={Platform.OS === 'ios' ? 'spinner' : 'default'}
                        onChange={(e, date) => {
                          setShowWakePicker(Platform.OS === 'ios');
                          if (date) setWakeTime(date);
                        }}
                        themeVariant="dark"
                      />
                    )}

                    {/* Summary */}
                    {hours > 0 && (
                      <View style={styles.summary}>
                        <Text style={styles.summaryText}>
                          {hours >= 8
                            ? 'Great rest!'
                            : hours >= 6
                            ? 'Solid sleep'
                            : 'Try to get more rest'}{' '}
                          {'\u2014'} {hours.toFixed(1)}h,{' '}
                          {QUALITY_OPTIONS.find((q) => q.id === quality)?.label.toLowerCase()}{' '}
                          quality
                        </Text>
                      </View>
                    )}

                    {/* Submit */}
                    <ActionButton
                      variant="primary"
                      onPress={handleSubmit}
                      loading={loading}
                      style={styles.submitBtn}
                    >
                      Log Sleep
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
  hoursDisplay: {
    flexDirection: 'row',
    alignItems: 'baseline',
    justifyContent: 'center',
    gap: spacing.sm,
    marginBottom: spacing.sm,
  },
  hoursValue: {
    fontSize: fontSize.display,
    fontWeight: fontWeight.bold,
    color: colors.sleep,
  },
  hoursUnit: {
    fontSize: fontSize.lg,
    color: colors.textMuted,
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
  qualityRow: {
    flexDirection: 'row',
    gap: spacing.xs,
  },
  qualityBtn: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: spacing.md,
    borderRadius: radii.md,
    backgroundColor: 'rgba(255,255,255,0.03)',
    borderWidth: 1,
    borderColor: colors.borderSubtle,
    minHeight: 44,
    justifyContent: 'center',
  },
  qualityBtnActive: {
    backgroundColor: 'rgba(139,92,246,0.15)',
    borderColor: colors.sleep,
  },
  qualityEmoji: {
    fontSize: 22,
    opacity: 0.5,
  },
  qualityEmojiActive: {
    opacity: 1,
  },
  qualityLabel: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
    marginTop: 2,
  },
  qualityLabelActive: {
    color: colors.sleep,
  },
  timeRow: {
    flexDirection: 'row',
    gap: spacing.md,
  },
  timeBtn: {
    flex: 1,
    backgroundColor: 'rgba(255,255,255,0.04)',
    borderWidth: 1,
    borderColor: colors.borderSubtle,
    borderRadius: radii.md,
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.md,
    alignItems: 'center',
    minHeight: 56,
    justifyContent: 'center',
  },
  timeBtnLabel: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
    marginBottom: 2,
    textTransform: 'uppercase',
    letterSpacing: 0.6,
  },
  timeBtnValue: {
    fontSize: fontSize.md,
    fontWeight: fontWeight.semibold,
    color: colors.textPrimary,
  },
  summary: {
    backgroundColor: 'rgba(139,92,246,0.1)',
    borderRadius: radii.md,
    padding: spacing.md,
    marginTop: spacing.lg,
  },
  summaryText: {
    fontSize: fontSize.sm,
    color: colors.textSecondary,
    textAlign: 'center',
    lineHeight: 20,
  },
  submitBtn: {
    marginTop: spacing.xl,
    minHeight: 52,
  },
});
