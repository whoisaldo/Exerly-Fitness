import React, { useState, useMemo, useCallback } from 'react';
import {
  View,
  Text,
  TextInput,
  ScrollView,
  Pressable,
  Alert,
  KeyboardAvoidingView,
  Platform,
  StyleSheet,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import Animated, { FadeInUp } from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { colors, gradients, spacing, radii, fontSize, fontWeight } from '../../theme/colors';
import ErrorBoundary from '../../components/ErrorBoundary';
import GlassCard from '../../components/GlassCard';
import ActionButton from '../../components/ActionButton';
import FoodCard from '../../components/library/FoodCard';
import { saveCustomFood } from '../../services/FoodLibraryService';

function CreateFoodScreenInner({ navigation, route }) {
  const prefillBarcode = route.params?.barcode ?? null;
  const initialName = route.params?.initialName ?? '';
  const logAfterSave = route.params?.logAfterSave ?? Boolean(prefillBarcode);
  const initialMealType = route.params?.mealType ?? undefined;

  const [name, setName] = useState(initialName);
  const [brand, setBrand] = useState('');
  const [servingSize, setServingSize] = useState('');
  const [gramsPerServing, setGramsPerServing] = useState('');
  const [calories, setCalories] = useState('');
  const [protein, setProtein] = useState('');
  const [carbs, setCarbs] = useState('');
  const [fat, setFat] = useState('');
  const [sugar, setSugar] = useState('');
  const [fiber, setFiber] = useState('');
  const [sodium, setSodium] = useState('');
  const [satFat, setSatFat] = useState('');
  const [showMore, setShowMore] = useState(false);
  const [saving, setSaving] = useState(false);
  const [focusedField, setFocusedField] = useState(null);

  const num = (v) => parseFloat(v) || 0;

  const isValid = name.length >= 2 && num(calories) > 0 && num(gramsPerServing) > 0;

  const macroWarning = useMemo(() => {
    const cal = num(calories);
    const macroCal = num(protein) * 4 + num(carbs) * 4 + num(fat) * 9;
    if (cal === 0 || macroCal === 0) return null;
    const diff = Math.abs(macroCal - cal) / cal;
    return diff > 0.2 ? 'Macros don\'t add up to calories — double check values' : null;
  }, [calories, protein, carbs, fat]);

  const previewFood = useMemo(() => {
    const gps = num(gramsPerServing) || 100;
    return {
      id: 'preview',
      name: name || 'Food Name',
      brand: brand || null,
      calories: Math.round(num(calories) / gps * 100),
      protein: Math.round(num(protein) / gps * 100 * 10) / 10,
      carbs: Math.round(num(carbs) / gps * 100 * 10) / 10,
      fat: Math.round(num(fat) / gps * 100 * 10) / 10,
      sugar: Math.round(num(sugar) / gps * 100 * 10) / 10,
      fiber: Math.round(num(fiber) / gps * 100 * 10) / 10,
      sodium: Math.round(num(sodium) / gps * 100),
      saturatedFat: Math.round(num(satFat) / gps * 100 * 10) / 10,
      servingSize: servingSize || `${gramsPerServing || 100}g`,
      servingGrams: num(gramsPerServing) || 100,
      imageUrl: null,
      source: 'custom',
      barcode: prefillBarcode,
      categories: '',
    };
  }, [name, brand, calories, protein, carbs, fat, sugar, fiber, sodium, satFat, servingSize, gramsPerServing, prefillBarcode]);

  const handleSave = useCallback(async () => {
    if (!isValid) {
      Alert.alert('Missing Fields', 'Name, calories, and grams per serving are required.');
      return;
    }
    setSaving(true);
    try {
      const savedFood = await saveCustomFood(previewFood);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      if (logAfterSave) {
        navigation.replace('FoodDetail', {
          food: savedFood,
          mode: 'log',
          mealType: initialMealType,
        });
      } else {
        navigation.goBack();
      }
    } catch {
      Alert.alert('Error', 'Failed to save food.');
    } finally {
      setSaving(false);
    }
  }, [initialMealType, isValid, logAfterSave, navigation, previewFood]);

  const renderField = (label, value, setter, placeholder, required, key, keyboardType = 'default') => (
    <View style={styles.fieldWrap} key={key}>
      <Text style={styles.label}>{label}{required ? ' *' : ''}</Text>
      <TextInput
        style={[styles.input, focusedField === key && styles.inputFocused]}
        placeholder={placeholder}
        placeholderTextColor={colors.textMuted}
        value={value}
        onChangeText={setter}
        onFocus={() => setFocusedField(key)}
        onBlur={() => setFocusedField(null)}
        keyboardType={keyboardType}
      />
    </View>
  );

  return (
    <LinearGradient
      colors={[colors.deep, colors.surface1, colors.dark]}
      locations={[0, 0.5, 1]}
      style={styles.gradient}
    >
      <SafeAreaView style={styles.safe} edges={['top', 'bottom']}>
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          style={styles.flex}
        >
          <ScrollView
            contentContainerStyle={styles.scroll}
            showsVerticalScrollIndicator={false}
            keyboardShouldPersistTaps="handled"
          >
            <View style={styles.header}>
              <Pressable
                onPress={() => {
                  Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                  navigation.goBack();
                }}
                style={styles.headerBtn}
                accessibilityRole="button"
                accessibilityLabel="Go back"
              >
                <Ionicons name="chevron-back" size={24} color={colors.textPrimary} />
              </Pressable>
              <Text style={styles.headerTitle}>Create Food</Text>
              <ActionButton
                title="Save"
                variant="primary"
                onPress={handleSave}
                loading={saving}
                disabled={!isValid}
                style={styles.saveBtn}
              />
            </View>

            <Animated.View entering={FadeInUp.delay(50).duration(500)}>
              <GlassCard elevated style={styles.card}>
                <Text style={styles.sectionTitle}>Basic Info</Text>
                {renderField('Food Name', name, setName, 'e.g., Homemade Granola', true, 'name')}
                {renderField('Brand', brand, setBrand, 'Optional', false, 'brand')}
                {renderField('Serving Size', servingSize, setServingSize, 'e.g., 1 cup, 1 slice', false, 'serving')}
                {renderField('Grams per Serving', gramsPerServing, setGramsPerServing, 'e.g., 100', true, 'grams', 'numeric')}
                <Text style={styles.helper}>Enter the weight in grams of one serving</Text>
              </GlassCard>
            </Animated.View>

            <Animated.View entering={FadeInUp.delay(100).duration(500)}>
              <GlassCard elevated style={styles.card}>
                <Text style={styles.sectionTitle}>Nutrition per Serving</Text>
                {renderField('Calories', calories, setCalories, '0', true, 'cal', 'numeric')}

                <View style={styles.macroGrid}>
                  <View style={styles.macroCol}>
                    {renderField('Protein (g)', protein, setProtein, '0', false, 'protein', 'numeric')}
                  </View>
                  <View style={styles.macroCol}>
                    {renderField('Carbs (g)', carbs, setCarbs, '0', false, 'carbs', 'numeric')}
                  </View>
                  <View style={styles.macroCol}>
                    {renderField('Fat (g)', fat, setFat, '0', false, 'fat', 'numeric')}
                  </View>
                </View>

                {macroWarning && (
                  <View style={styles.warningRow}>
                    <Ionicons name="warning-outline" size={16} color={colors.warning} />
                    <Text style={styles.warningText}>{macroWarning}</Text>
                  </View>
                )}

                <Pressable
                  onPress={() => {
                    Haptics.selectionAsync();
                    setShowMore(!showMore);
                  }}
                  style={styles.moreToggle}
                  accessibilityRole="button"
                >
                  <Text style={styles.moreText}>
                    {showMore ? 'Less details' : 'More details'}
                  </Text>
                  <Ionicons
                    name={showMore ? 'chevron-up' : 'chevron-down'}
                    size={16}
                    color={colors.primary}
                  />
                </Pressable>

                {showMore && (
                  <View style={styles.macroGrid}>
                    <View style={styles.macroCol}>
                      {renderField('Sugar (g)', sugar, setSugar, '0', false, 'sugar', 'numeric')}
                    </View>
                    <View style={styles.macroCol}>
                      {renderField('Fiber (g)', fiber, setFiber, '0', false, 'fiber', 'numeric')}
                    </View>
                    <View style={styles.macroCol}>
                      {renderField('Sat Fat (g)', satFat, setSatFat, '0', false, 'satFat', 'numeric')}
                    </View>
                  </View>
                )}

                {showMore && (
                  <View style={styles.macroGrid}>
                    <View style={styles.macroCol}>
                      {renderField('Sodium (mg)', sodium, setSodium, '0', false, 'sodium', 'numeric')}
                    </View>
                  </View>
                )}
              </GlassCard>
            </Animated.View>

            <Animated.View entering={FadeInUp.delay(150).duration(500)}>
              <GlassCard style={styles.card}>
                <Text style={styles.sectionTitle}>Preview</Text>
                <Text style={styles.previewHelper}>This is how your food will appear</Text>
                <FoodCard food={previewFood} />
              </GlassCard>
            </Animated.View>
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </LinearGradient>
  );
}

export default function CreateFoodScreen(props) {
  return (
    <ErrorBoundary>
      <CreateFoodScreenInner {...props} />
    </ErrorBoundary>
  );
}

const styles = StyleSheet.create({
  gradient: {
    flex: 1,
  },
  safe: {
    flex: 1,
  },
  flex: {
    flex: 1,
  },
  scroll: {
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing['2xl'],
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: spacing.sm,
  },
  headerBtn: {
    minWidth: 44,
    minHeight: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerTitle: {
    fontSize: fontSize.lg,
    fontWeight: fontWeight.bold,
    color: colors.textPrimary,
  },
  saveBtn: {
    minHeight: 36,
    height: 36,
  },
  card: {
    marginBottom: spacing.md,
  },
  sectionTitle: {
    fontSize: fontSize.base,
    fontWeight: fontWeight.bold,
    color: colors.textPrimary,
    marginBottom: spacing.sm,
  },
  fieldWrap: {
    marginBottom: spacing.sm,
  },
  label: {
    fontSize: fontSize.xs,
    fontWeight: fontWeight.semibold,
    color: colors.textSecondary,
    marginBottom: spacing.xs,
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
  helper: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
    marginTop: -4,
  },
  macroGrid: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  macroCol: {
    flex: 1,
  },
  warningRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    backgroundColor: 'rgba(245,158,11,0.1)',
    padding: spacing.sm,
    borderRadius: radii.sm,
    marginTop: spacing.sm,
  },
  warningText: {
    fontSize: fontSize.xs,
    color: colors.warning,
    flex: 1,
  },
  moreToggle: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.xs,
    paddingVertical: spacing.md,
    minHeight: 44,
  },
  moreText: {
    fontSize: fontSize.sm,
    color: colors.primary,
    fontWeight: fontWeight.medium,
  },
  previewHelper: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
    marginBottom: spacing.sm,
  },
});
