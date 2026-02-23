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

const ACTIVITY_TYPES = [
  { id: 'cardio', label: 'Cardio', emoji: '🏃' },
  { id: 'strength', label: 'Strength', emoji: '🏋️' },
  { id: 'flexibility', label: 'Flexibility', emoji: '🧘' },
  { id: 'sports', label: 'Sports', emoji: '⚽' },
];

const INTENSITIES = [
  { id: 'light', label: 'Light', color: colors.success },
  { id: 'moderate', label: 'Moderate', color: colors.warning },
  { id: 'intense', label: 'Intense', color: colors.error },
];

export default function LogActivityScreen({ navigation }) {
  const [activity, setActivity] = useState('');
  const [duration, setDuration] = useState('');
  const [calories, setCalories] = useState('');
  const [activityType, setActivityType] = useState('cardio');
  const [intensity, setIntensity] = useState('moderate');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async () => {
    if (!activity || !duration || !calories) {
      Alert.alert('Missing Fields', 'Please fill in all required fields');
      return;
    }

    setLoading(true);
    try {
      await apiClient.post('/api/activities', {
        activity,
        duration_min: parseInt(duration),
        calories: parseInt(calories),
        type: activityType,
        intensity,
      });
      Alert.alert('Success!', 'Activity logged successfully', [
        { text: 'OK', onPress: () => navigation.goBack() }
      ]);
    } catch (error) {
      Alert.alert('Error', error.message || 'Failed to log activity');
    } finally {
      setLoading(false);
    }
  };

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
          <Text style={styles.title}>Log Activity 🏃</Text>
        </View>

        <View style={styles.card}>
          {/* Activity Name */}
          <Text style={styles.label}>Activity Name *</Text>
          <View style={styles.inputGroup}>
            <TextInput
              style={styles.input}
              placeholder="e.g., Morning Run, Weight Training"
              placeholderTextColor={colors.textMuted}
              value={activity}
              onChangeText={setActivity}
            />
          </View>

          {/* Activity Type */}
          <Text style={styles.label}>Activity Type</Text>
          <View style={styles.typeGrid}>
            {ACTIVITY_TYPES.map((type) => (
              <TouchableOpacity
                key={type.id}
                style={[
                  styles.typeButton,
                  activityType === type.id && styles.typeButtonActive,
                ]}
                onPress={() => setActivityType(type.id)}
              >
                <Text style={styles.typeEmoji}>{type.emoji}</Text>
                <Text style={[
                  styles.typeLabel,
                  activityType === type.id && styles.typeLabelActive,
                ]}>{type.label}</Text>
              </TouchableOpacity>
            ))}
          </View>

          {/* Duration */}
          <Text style={styles.label}>Duration (minutes) *</Text>
          <View style={styles.inputGroup}>
            <TextInput
              style={styles.input}
              placeholder="30"
              placeholderTextColor={colors.textMuted}
              value={duration}
              onChangeText={setDuration}
              keyboardType="numeric"
            />
          </View>

          {/* Calories */}
          <Text style={styles.label}>Calories Burned *</Text>
          <View style={styles.inputGroup}>
            <TextInput
              style={styles.input}
              placeholder="250"
              placeholderTextColor={colors.textMuted}
              value={calories}
              onChangeText={setCalories}
              keyboardType="numeric"
            />
          </View>

          {/* Intensity */}
          <Text style={styles.label}>Intensity</Text>
          <View style={styles.intensityRow}>
            {INTENSITIES.map((int) => (
              <TouchableOpacity
                key={int.id}
                style={[
                  styles.intensityButton,
                  intensity === int.id && { backgroundColor: `${int.color}30`, borderColor: int.color },
                ]}
                onPress={() => setIntensity(int.id)}
              >
                <Text style={[
                  styles.intensityLabel,
                  intensity === int.id && { color: int.color },
                ]}>{int.label}</Text>
              </TouchableOpacity>
            ))}
          </View>

          {/* Submit Button */}
          <TouchableOpacity
            style={styles.submitButtonWrapper}
            onPress={handleSubmit}
            disabled={loading}
          >
            <LinearGradient
              colors={colors.gradientWorkout}
              style={styles.submitButton}
            >
              {loading ? (
                <ActivityIndicator color="#fff" />
              ) : (
                <Text style={styles.submitButtonText}>Log Activity</Text>
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
  inputGroup: {
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.1)',
    borderRadius: borderRadius.md,
    paddingHorizontal: spacing.md,
  },
  input: { color: colors.textPrimary, fontSize: fontSize.md, paddingVertical: spacing.md },
  typeGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  typeButton: {
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.1)',
    borderRadius: borderRadius.md,
    padding: spacing.md,
    alignItems: 'center',
    width: '48%',
  },
  typeButtonActive: { backgroundColor: 'rgba(0, 184, 148, 0.2)', borderColor: colors.workout },
  typeEmoji: { fontSize: 24, marginBottom: spacing.xs },
  typeLabel: { color: colors.textMuted, fontSize: fontSize.sm },
  typeLabelActive: { color: colors.workout },
  intensityRow: { flexDirection: 'row', gap: spacing.sm },
  intensityButton: {
    flex: 1,
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.1)',
    borderRadius: borderRadius.md,
    padding: spacing.md,
    alignItems: 'center',
  },
  intensityLabel: { color: colors.textMuted, fontSize: fontSize.sm, fontWeight: fontWeight.medium },
  submitButtonWrapper: { marginTop: spacing.xl, borderRadius: borderRadius.lg, overflow: 'hidden' },
  submitButton: { paddingVertical: spacing.md, alignItems: 'center' },
  submitButtonText: { color: colors.textPrimary, fontSize: fontSize.lg, fontWeight: fontWeight.bold },
});

