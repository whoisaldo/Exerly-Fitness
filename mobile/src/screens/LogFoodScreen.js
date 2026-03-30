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
import Animated, { FadeInUp } from 'react-native-reanimated';
import { colors, gradients, spacing, radii, fontSize, fontWeight } from '../theme/colors';
import { GlassCard } from '../components/GlassCard';
import { ActionButton } from '../components/ActionButton';
import apiClient from '../api/client';

const MEAL_TYPES = [
  { id: 'breakfast', label: 'Breakfast' },
  { id: 'lunch', label: 'Lunch' },
  { id: 'dinner', label: 'Dinner' },
  { id: 'snack', label: 'Snack' },
];

export default function LogFoodScreen({ navigation }) {
  const [name, setName] = useState('');
  const [calories, setCalories] = useState('');
  const [protein, setProtein] = useState('');
  const [carbs, setCarbs] = useState('');
  const [fat, setFat] = useState('');
  const [sugar, setSugar] = useState('');
  const [mealType, setMealType] = useState('lunch');
  const [loading, setLoading] = useState(false);
  const [focusedField, setFocusedField] = useState(null);

  const handleSubmit = async () => {
    if (!name || !calories || !protein || !sugar) {
      Alert.alert('Missing Fields', 'Please fill in name, calories, protein, and sugar');
      return;
    }

    setLoading(true);
    try {
      await apiClient.post('/api/food', {
        name,
        calories: parseInt(calories, 10),
        protein: parseInt(protein, 10),
        sugar: parseInt(sugar, 10),
        carbs: carbs ? parseInt(carbs, 10) : null,
        fat: fat ? parseInt(fat, 10) : null,
        mealType,
      });
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
      Alert.alert('Success!', 'Food logged successfully', [
        { text: 'OK', onPress: () => navigation.goBack() },
      ]);
    } catch (error) {
      Alert.alert('Error', error.message || 'Failed to log food');
    } finally {
      setLoading(false);
    }
  };

  const renderInput = (label, value, setter, placeholder, required, fieldKey) => (
    <View style={styles.fieldWrap}>
      <Text style={styles.label}>
        {label}
        {required ? ' *' : ''}
      </Text>
      <TextInput
        style={[
          styles.input,
          focusedField === fieldKey && styles.inputFocused,
        ]}
        placeholder={placeholder}
        placeholderTextColor={colors.textMuted}
        value={value}
        onChangeText={setter}
        onFocus={() => setFocusedField(fieldKey)}
        onBlur={() => setFocusedField(null)}
        keyboardType={fieldKey === 'name' ? 'default' : 'numeric'}
      />
    </View>
  );

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
              <Text style={styles.title}>Log Food</Text>
            </Animated.View>

            {/* Form */}
            <Animated.View entering={FadeInUp.delay(150).duration(600)}>
              <GlassCard elevated style={styles.card}>
                <BlurView intensity={15} tint="dark" style={styles.blur}>
                  <View style={styles.cardInner}>
                    {/* Food Name */}
                    {renderInput('Food Name', name, setName, 'e.g., Grilled Chicken Salad', true, 'name')}

                    {/* Meal Type Pills */}
                    <Text style={styles.label}>Meal Type</Text>
                    <View style={styles.pillRow}>
                      {MEAL_TYPES.map((type) => {
                        const active = mealType === type.id;
                        return (
                          <Pressable
                            key={type.id}
                            onPress={() => {
                              setMealType(type.id);
                              Haptics.selectionAsync();
                            }}
                            style={[
                              styles.pill,
                              active && styles.pillActive,
                            ]}
                          >
                            <Text
                              style={[
                                styles.pillText,
                                active && styles.pillTextActive,
                              ]}
                            >
                              {type.label}
                            </Text>
                          </Pressable>
                        );
                      })}
                    </View>

                    {/* Macro Inputs — two-column grid */}
                    <View style={styles.macroGrid}>
                      <View style={styles.macroCol}>
                        {renderInput('Calories', calories, setCalories, '350', true, 'cal')}
                      </View>
                      <View style={styles.macroCol}>
                        {renderInput('Protein (g)', protein, setProtein, '25', true, 'protein')}
                      </View>
                    </View>

                    <View style={styles.macroGrid}>
                      <View style={styles.macroCol}>
                        {renderInput('Carbs (g)', carbs, setCarbs, '30', false, 'carbs')}
                      </View>
                      <View style={styles.macroCol}>
                        {renderInput('Fat (g)', fat, setFat, '10', false, 'fat')}
                      </View>
                    </View>

                    <View style={styles.macroGrid}>
                      <View style={styles.macroCol}>
                        {renderInput('Sugar (g)', sugar, setSugar, '5', true, 'sugar')}
                      </View>
                      <View style={styles.macroCol} />
                    </View>

                    {/* Submit */}
                    <ActionButton
                      variant="primary"
                      onPress={handleSubmit}
                      loading={loading}
                      style={styles.submitBtn}
                    >
                      Log Food
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
  fieldWrap: {
    marginBottom: spacing.sm,
  },
  label: {
    fontSize: fontSize.sm,
    fontWeight: fontWeight.semibold,
    color: colors.textSecondary,
    marginBottom: spacing.xs,
    marginTop: spacing.sm,
    textTransform: 'uppercase',
    letterSpacing: 0.8,
  },
  input: {
    backgroundColor: 'rgba(255,255,255,0.04)',
    borderWidth: 1,
    borderColor: colors.borderSubtle,
    borderRadius: radii.md,
    paddingHorizontal: spacing.md,
    paddingVertical: 12,
    color: colors.textPrimary,
    fontSize: fontSize.base,
    minHeight: 48,
  },
  inputFocused: {
    borderColor: colors.borderAccent,
  },
  pillRow: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginBottom: spacing.sm,
  },
  pill: {
    flex: 1,
    backgroundColor: 'rgba(255,255,255,0.04)',
    borderWidth: 1,
    borderColor: colors.borderSubtle,
    borderRadius: radii.full,
    paddingVertical: 10,
    alignItems: 'center',
    minHeight: 44,
    justifyContent: 'center',
  },
  pillActive: {
    backgroundColor: 'rgba(245,158,11,0.15)',
    borderColor: colors.nutrition,
  },
  pillText: {
    fontSize: fontSize.xs,
    fontWeight: fontWeight.semibold,
    color: colors.textMuted,
  },
  pillTextActive: {
    color: colors.nutrition,
  },
  macroGrid: {
    flexDirection: 'row',
    gap: spacing.md,
  },
  macroCol: {
    flex: 1,
  },
  submitBtn: {
    marginTop: spacing.xl,
    minHeight: 52,
  },
});
