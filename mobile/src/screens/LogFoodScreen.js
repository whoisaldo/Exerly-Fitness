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

const MEAL_TYPES = [
  { id: 'breakfast', label: 'Breakfast', emoji: '🌅' },
  { id: 'lunch', label: 'Lunch', emoji: '☀️' },
  { id: 'dinner', label: 'Dinner', emoji: '🌙' },
  { id: 'snack', label: 'Snack', emoji: '🍿' },
];

export default function LogFoodScreen({ navigation }) {
  const [name, setName] = useState('');
  const [calories, setCalories] = useState('');
  const [protein, setProtein] = useState('');
  const [sugar, setSugar] = useState('');
  const [carbs, setCarbs] = useState('');
  const [fat, setFat] = useState('');
  const [mealType, setMealType] = useState('lunch');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async () => {
    if (!name || !calories || !protein || !sugar) {
      Alert.alert('Missing Fields', 'Please fill in name, calories, protein, and sugar');
      return;
    }

    setLoading(true);
    try {
      await apiClient.post('/api/food', {
        name,
        calories: parseInt(calories),
        protein: parseInt(protein),
        sugar: parseInt(sugar),
        carbs: carbs ? parseInt(carbs) : null,
        fat: fat ? parseInt(fat) : null,
        mealType,
      });
      Alert.alert('Success!', 'Food logged successfully', [
        { text: 'OK', onPress: () => navigation.goBack() }
      ]);
    } catch (error) {
      Alert.alert('Error', error.message || 'Failed to log food');
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
          <Text style={styles.title}>Log Food 🍎</Text>
        </View>

        <View style={styles.card}>
          {/* Food Name */}
          <Text style={styles.label}>Food Name *</Text>
          <View style={styles.inputGroup}>
            <TextInput
              style={styles.input}
              placeholder="e.g., Grilled Chicken Salad"
              placeholderTextColor={colors.textMuted}
              value={name}
              onChangeText={setName}
            />
          </View>

          {/* Meal Type */}
          <Text style={styles.label}>Meal Type</Text>
          <View style={styles.typeGrid}>
            {MEAL_TYPES.map((type) => (
              <TouchableOpacity
                key={type.id}
                style={[
                  styles.typeButton,
                  mealType === type.id && styles.typeButtonActive,
                ]}
                onPress={() => setMealType(type.id)}
              >
                <Text style={styles.typeEmoji}>{type.emoji}</Text>
                <Text style={[
                  styles.typeLabel,
                  mealType === type.id && styles.typeLabelActive,
                ]}>{type.label}</Text>
              </TouchableOpacity>
            ))}
          </View>

          {/* Macros Row */}
          <View style={styles.macroRow}>
            <View style={styles.macroInput}>
              <Text style={styles.label}>Calories *</Text>
              <View style={styles.inputGroup}>
                <TextInput
                  style={styles.input}
                  placeholder="350"
                  placeholderTextColor={colors.textMuted}
                  value={calories}
                  onChangeText={setCalories}
                  keyboardType="numeric"
                />
              </View>
            </View>
            <View style={styles.macroInput}>
              <Text style={styles.label}>Protein (g) *</Text>
              <View style={styles.inputGroup}>
                <TextInput
                  style={styles.input}
                  placeholder="25"
                  placeholderTextColor={colors.textMuted}
                  value={protein}
                  onChangeText={setProtein}
                  keyboardType="numeric"
                />
              </View>
            </View>
          </View>

          <View style={styles.macroRow}>
            <View style={styles.macroInput}>
              <Text style={styles.label}>Sugar (g) *</Text>
              <View style={styles.inputGroup}>
                <TextInput
                  style={styles.input}
                  placeholder="5"
                  placeholderTextColor={colors.textMuted}
                  value={sugar}
                  onChangeText={setSugar}
                  keyboardType="numeric"
                />
              </View>
            </View>
            <View style={styles.macroInput}>
              <Text style={styles.label}>Carbs (g)</Text>
              <View style={styles.inputGroup}>
                <TextInput
                  style={styles.input}
                  placeholder="30"
                  placeholderTextColor={colors.textMuted}
                  value={carbs}
                  onChangeText={setCarbs}
                  keyboardType="numeric"
                />
              </View>
            </View>
          </View>

          <View style={styles.macroRow}>
            <View style={styles.macroInput}>
              <Text style={styles.label}>Fat (g)</Text>
              <View style={styles.inputGroup}>
                <TextInput
                  style={styles.input}
                  placeholder="10"
                  placeholderTextColor={colors.textMuted}
                  value={fat}
                  onChangeText={setFat}
                  keyboardType="numeric"
                />
              </View>
            </View>
            <View style={styles.macroInput} />
          </View>

          {/* Submit Button */}
          <TouchableOpacity
            style={styles.submitButtonWrapper}
            onPress={handleSubmit}
            disabled={loading}
          >
            <LinearGradient
              colors={[colors.consumed, colors.burnedSecondary]}
              style={styles.submitButton}
            >
              {loading ? (
                <ActivityIndicator color="#fff" />
              ) : (
                <Text style={styles.submitButtonText}>Log Food</Text>
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
    padding: spacing.sm,
    alignItems: 'center',
    width: '23%',
  },
  typeButtonActive: { backgroundColor: 'rgba(253, 203, 110, 0.2)', borderColor: colors.consumed },
  typeEmoji: { fontSize: 20, marginBottom: 2 },
  typeLabel: { color: colors.textMuted, fontSize: fontSize.xs },
  typeLabelActive: { color: colors.consumed },
  macroRow: { flexDirection: 'row', gap: spacing.md },
  macroInput: { flex: 1 },
  submitButtonWrapper: { marginTop: spacing.xl, borderRadius: borderRadius.lg, overflow: 'hidden' },
  submitButton: { paddingVertical: spacing.md, alignItems: 'center' },
  submitButtonText: { color: colors.textPrimary, fontSize: fontSize.lg, fontWeight: fontWeight.bold },
});

