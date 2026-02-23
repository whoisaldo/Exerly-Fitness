import React, { useState } from 'react';
import {
  StyleSheet,
  Text,
  View,
  TextInput,
  TouchableOpacity,
  ActivityIndicator,
  ScrollView,
  Alert,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { colors, spacing, borderRadius, fontSize, fontWeight } from '../theme/colors';
import apiClient from '../api/client';

const QUALITY_OPTIONS = [
  { id: 'poor', label: 'Poor', emoji: '😫', color: colors.error },
  { id: 'fair', label: 'Fair', emoji: '😐', color: colors.warning },
  { id: 'good', label: 'Good', emoji: '😊', color: colors.success },
  { id: 'excellent', label: 'Excellent', emoji: '😴', color: colors.primary },
];

export default function LogSleepScreen({ navigation }) {
  const [hours, setHours] = useState('');
  const [quality, setQuality] = useState('good');
  const [bedtime, setBedtime] = useState('');
  const [wakeTime, setWakeTime] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async () => {
    if (!hours || !quality) {
      Alert.alert('Missing Fields', 'Please enter hours and select quality');
      return;
    }

    setLoading(true);
    try {
      await apiClient.post('/api/sleep', {
        hours: parseFloat(hours),
        quality,
        bedtime: bedtime || null,
        wakeTime: wakeTime || null,
      });
      Alert.alert('Success!', 'Sleep logged successfully', [
        { text: 'OK', onPress: () => navigation.goBack() }
      ]);
    } catch (error) {
      Alert.alert('Error', error.message || 'Failed to log sleep');
    } finally {
      setLoading(false);
    }
  };

  const selectedQuality = QUALITY_OPTIONS.find(q => q.id === quality);

  return (
    <LinearGradient
      colors={colors.gradientBackground}
      locations={[0, 0.5, 1]}
      style={styles.container}
    >
      <ScrollView 
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.header}>
          <TouchableOpacity onPress={() => navigation.goBack()}>
            <Text style={styles.backButton}>← Back</Text>
          </TouchableOpacity>
          <Text style={styles.title}>Log Sleep 😴</Text>
        </View>

        <View style={styles.card}>
          {/* Hours Slept */}
          <Text style={styles.label}>Hours Slept *</Text>
          <View style={styles.hoursContainer}>
            <View style={styles.hoursInputWrapper}>
              <TextInput
                style={styles.hoursInput}
                placeholder="7.5"
                placeholderTextColor={colors.textMuted}
                value={hours}
                onChangeText={setHours}
                keyboardType="decimal-pad"
              />
              <Text style={styles.hoursLabel}>hours</Text>
            </View>
          </View>

          {/* Quick Hour Buttons */}
          <View style={styles.quickHours}>
            {[6, 7, 8, 9].map((h) => (
              <TouchableOpacity
                key={h}
                style={[styles.quickHourButton, hours === h.toString() && styles.quickHourActive]}
                onPress={() => setHours(h.toString())}
              >
                <Text style={[styles.quickHourText, hours === h.toString() && styles.quickHourTextActive]}>{h}h</Text>
              </TouchableOpacity>
            ))}
          </View>

          {/* Sleep Quality */}
          <Text style={styles.label}>Sleep Quality *</Text>
          <View style={styles.qualityGrid}>
            {QUALITY_OPTIONS.map((option) => (
              <TouchableOpacity
                key={option.id}
                style={[
                  styles.qualityButton,
                  quality === option.id && { backgroundColor: `${option.color}20`, borderColor: option.color },
                ]}
                onPress={() => setQuality(option.id)}
              >
                <Text style={styles.qualityEmoji}>{option.emoji}</Text>
                <Text style={[
                  styles.qualityLabel,
                  quality === option.id && { color: option.color },
                ]}>{option.label}</Text>
              </TouchableOpacity>
            ))}
          </View>

          {/* Bedtime & Wake Time (Optional) */}
          <View style={styles.timeRow}>
            <View style={styles.timeInput}>
              <Text style={styles.label}>Bedtime</Text>
              <View style={styles.inputGroup}>
                <TextInput
                  style={styles.input}
                  placeholder="10:30 PM"
                  placeholderTextColor={colors.textMuted}
                  value={bedtime}
                  onChangeText={setBedtime}
                />
              </View>
            </View>
            <View style={styles.timeInput}>
              <Text style={styles.label}>Wake Time</Text>
              <View style={styles.inputGroup}>
                <TextInput
                  style={styles.input}
                  placeholder="6:30 AM"
                  placeholderTextColor={colors.textMuted}
                  value={wakeTime}
                  onChangeText={setWakeTime}
                />
              </View>
            </View>
          </View>

          {/* Sleep Summary */}
          {hours && (
            <View style={styles.summary}>
              <Text style={styles.summaryText}>
                {parseFloat(hours) >= 7 ? '✨ Great!' : parseFloat(hours) >= 6 ? '👍 Good' : '⚠️ Could be better'} 
                {' '}You slept {hours} hours with {selectedQuality?.label.toLowerCase()} quality
              </Text>
            </View>
          )}

          {/* Submit Button */}
          <TouchableOpacity
            style={styles.submitButtonWrapper}
            onPress={handleSubmit}
            disabled={loading}
          >
            <LinearGradient
              colors={colors.gradientSleep}
              style={styles.submitButton}
            >
              {loading ? (
                <ActivityIndicator color="#fff" />
              ) : (
                <Text style={styles.submitButtonText}>Log Sleep</Text>
              )}
            </LinearGradient>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  scrollContent: { padding: spacing.lg, paddingTop: 60 },
  header: { marginBottom: spacing.lg },
  backButton: { color: colors.primary, fontSize: fontSize.md, marginBottom: spacing.sm },
  title: { fontSize: fontSize.xxl, fontWeight: fontWeight.bold, color: colors.textPrimary },
  card: {
    backgroundColor: 'rgba(139, 92, 246, 0.1)',
    borderRadius: borderRadius.xl,
    borderWidth: 1,
    borderColor: 'rgba(139, 92, 246, 0.2)',
    padding: spacing.lg,
  },
  label: { color: colors.textSecondary, fontSize: fontSize.sm, fontWeight: fontWeight.semibold, marginBottom: spacing.sm, marginTop: spacing.md },
  hoursContainer: { alignItems: 'center', paddingVertical: spacing.lg },
  hoursInputWrapper: { flexDirection: 'row', alignItems: 'baseline' },
  hoursInput: {
    fontSize: 48,
    fontWeight: fontWeight.bold,
    color: colors.primary,
    textAlign: 'center',
    minWidth: 100,
  },
  hoursLabel: { fontSize: fontSize.xl, color: colors.textMuted, marginLeft: spacing.sm },
  quickHours: { flexDirection: 'row', justifyContent: 'center', gap: spacing.sm, marginBottom: spacing.md },
  quickHourButton: {
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: borderRadius.full,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.1)',
  },
  quickHourActive: { backgroundColor: 'rgba(108, 92, 231, 0.3)', borderColor: colors.sleep },
  quickHourText: { color: colors.textMuted, fontSize: fontSize.sm },
  quickHourTextActive: { color: colors.sleep },
  qualityGrid: { flexDirection: 'row', gap: spacing.sm },
  qualityButton: {
    flex: 1,
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.1)',
    borderRadius: borderRadius.md,
    padding: spacing.md,
    alignItems: 'center',
  },
  qualityEmoji: { fontSize: 28, marginBottom: spacing.xs },
  qualityLabel: { color: colors.textMuted, fontSize: fontSize.xs },
  timeRow: { flexDirection: 'row', gap: spacing.md },
  timeInput: { flex: 1 },
  inputGroup: {
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.1)',
    borderRadius: borderRadius.md,
    paddingHorizontal: spacing.md,
  },
  input: { color: colors.textPrimary, fontSize: fontSize.md, paddingVertical: spacing.md },
  summary: {
    backgroundColor: 'rgba(108, 92, 231, 0.2)',
    borderRadius: borderRadius.md,
    padding: spacing.md,
    marginTop: spacing.lg,
  },
  summaryText: { color: colors.textSecondary, fontSize: fontSize.sm, textAlign: 'center' },
  submitButtonWrapper: { marginTop: spacing.xl, borderRadius: borderRadius.lg, overflow: 'hidden' },
  submitButton: { paddingVertical: spacing.md, alignItems: 'center' },
  submitButtonText: { color: colors.textPrimary, fontSize: fontSize.lg, fontWeight: fontWeight.bold },
});

