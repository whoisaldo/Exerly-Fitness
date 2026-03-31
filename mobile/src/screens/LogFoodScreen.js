import React, { useState, useCallback, useMemo } from 'react';
import {
  StyleSheet,
  Text,
  View,
  TextInput,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  FlatList,
  Pressable,
  Alert,
} from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import Animated, { FadeInUp } from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { colors, gradients, spacing, radii, fontSize, fontWeight } from '../theme/colors';
import GlassCard from '../components/GlassCard';
import ActionButton from '../components/ActionButton';
import FoodSearchBar from '../components/library/FoodSearchBar';
import FoodCard from '../components/library/FoodCard';
import LoadingSkeleton from '../components/LoadingSkeleton';
import EmptyState from '../components/EmptyState';
import ErrorBoundary from '../components/ErrorBoundary';
import useFoodSearch from '../hooks/useFoodSearch';
import useFoodLibrary from '../hooks/useFoodLibrary';

const MEAL_TYPES = [
  { id: 'breakfast', label: 'Breakfast' },
  { id: 'lunch', label: 'Lunch' },
  { id: 'dinner', label: 'Dinner' },
  { id: 'snack', label: 'Snack' },
];

function getDefaultMealType() {
  const hour = new Date().getHours();
  if (hour >= 5 && hour < 10) return 'breakfast';
  if (hour >= 10 && hour < 14) return 'lunch';
  if (hour >= 14 && hour < 19) return 'dinner';
  return 'snack';
}

function LogFoodScreenInner({ navigation }) {
  const search = useFoodSearch();
  const library = useFoodLibrary();
  const [showManual, setShowManual] = useState(false);

  const [name, setName] = useState('');
  const [calories, setCalories] = useState('');
  const [protein, setProtein] = useState('');
  const [mealType, setMealType] = useState(getDefaultMealType());
  const [loading, setLoading] = useState(false);
  const [focusedField, setFocusedField] = useState(null);

  const favIds = useMemo(
    () => new Set(library.favorites.map((f) => f.id)),
    [library.favorites],
  );

  useFocusEffect(
    useCallback(() => {
      library.refreshAll();
    }, [library.refreshAll]),
  );

  const handleFoodPress = useCallback(
    (food) => {
      navigation.navigate('FoodDetail', { food, mode: 'log', mealType });
    },
    [navigation, mealType],
  );

  const handleBarcodePress = useCallback(() => {
    navigation.navigate('BarcodeScanner');
  }, [navigation]);

  const handleManualSubmit = async () => {
    if (!name || !calories || !protein) {
      Alert.alert('Missing Fields', 'Please fill in name, calories, and protein');
      return;
    }
    setLoading(true);
    try {
      await library.logFood({
        id: `manual_${Date.now()}`,
        name: name.trim(),
        brand: null,
        calories: parseFloat(calories) || 0,
        protein: parseFloat(protein) || 0,
        carbs: 0,
        fat: 0,
        sugar: 0,
        fiber: 0,
        sodium: 0,
        saturatedFat: 0,
        servingSize: '1 entry',
        servingGrams: 100,
        imageUrl: null,
        source: 'manual',
        barcode: null,
        categories: '',
      }, {
        grams: 100,
        servings: 1,
        mealType,
      });
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      Alert.alert('Logged!', 'Food logged successfully', [
        { text: 'OK', onPress: () => navigation.goBack() },
      ]);
    } catch (error) {
      Alert.alert('Error', error.message || 'Failed to log food');
    } finally {
      setLoading(false);
    }
  };

  const isSearching = search.query.length >= 2;

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
          <View style={styles.headerRow}>
            <Pressable
              onPress={() => navigation.goBack()}
              style={styles.backBtn}
              hitSlop={12}
              accessibilityRole="button"
              accessibilityLabel="Go back"
            >
              <Ionicons name="close" size={24} color={colors.textPrimary} />
            </Pressable>
            <Text style={styles.title}>Log Food</Text>
            <View style={styles.backBtn} />
          </View>

          <DailySummary totals={library.dailyTotals} />

          <Animated.View entering={FadeInUp.delay(50).duration(400)} style={styles.searchWrap}>
            <FoodSearchBar
              value={search.query}
              onChangeText={search.setQuery}
              loading={search.loading && isSearching}
              onBarcodePress={handleBarcodePress}
              autoFocus
            />
          </Animated.View>

          {!isSearching && !showManual && (
            <ScrollView
              contentContainerStyle={styles.scroll}
              showsVerticalScrollIndicator={false}
              keyboardShouldPersistTaps="handled"
            >
              {library.recents.length > 0 && (
                <Animated.View entering={FadeInUp.delay(100).duration(400)}>
                  <Text style={styles.sectionTitle}>Recent</Text>
                  <FlatList
                    data={library.recents.slice(0, 5)}
                    horizontal
                    showsHorizontalScrollIndicator={false}
                    keyExtractor={(item) => item.id}
                    renderItem={({ item }) => (
                      <FoodCard food={item} onPress={handleFoodPress} compact />
                    )}
                  />
                </Animated.View>
              )}

              {library.favorites.length > 0 && (
                <Animated.View entering={FadeInUp.delay(150).duration(400)}>
                  <Text style={styles.sectionTitle}>Favorites</Text>
                  <FlatList
                    data={library.favorites.slice(0, 5)}
                    horizontal
                    showsHorizontalScrollIndicator={false}
                    keyExtractor={(item) => item.id}
                    renderItem={({ item }) => (
                      <FoodCard food={item} onPress={handleFoodPress} compact />
                    )}
                  />
                </Animated.View>
              )}

              <Pressable
                onPress={() => {
                  Haptics.selectionAsync();
                  setShowManual(true);
                }}
                style={styles.manualToggle}
                accessibilityRole="button"
              >
                <Ionicons name="create-outline" size={18} color={colors.primary} />
                <Text style={styles.manualToggleText}>Log manually without searching</Text>
              </Pressable>
            </ScrollView>
          )}

          {isSearching && (
            <FlatList
              data={search.results}
              keyExtractor={(item) => item.id}
              renderItem={({ item }) => (
                <FoodCard
                  food={item}
                  onPress={handleFoodPress}
                  onToggleFavorite={(f) => library.toggleFavorite(f)}
                  isFavorite={favIds.has(item.id)}
                />
              )}
              ListEmptyComponent={() => {
                if (search.loading) {
                  return <LoadingSkeleton variant="row" count={5} style={styles.skeletons} />;
                }
                if (search.error) {
                  return (
                    <EmptyState
                      icon="cloud-offline-outline"
                      title="Search failed"
                      subtitle={search.error}
                      actionTitle="Retry"
                      onAction={search.retry}
                    />
                  );
                }
                return (
                  <EmptyState
                    icon="search-outline"
                    title={`No results for '${search.query}'`}
                    actionTitle="Create custom food"
                    onAction={() => navigation.navigate('CreateFood', {
                      initialName: search.query.trim(),
                      logAfterSave: true,
                      mealType,
                    })}
                  />
                );
              }}
              onEndReached={search.loadMore}
              onEndReachedThreshold={0.3}
              contentContainerStyle={styles.listContent}
              showsVerticalScrollIndicator={false}
              keyboardShouldPersistTaps="handled"
            />
          )}

          {showManual && !isSearching && (
            <ScrollView
              contentContainerStyle={styles.scroll}
              showsVerticalScrollIndicator={false}
              keyboardShouldPersistTaps="handled"
            >
              <Animated.View entering={FadeInUp.duration(400)}>
                <GlassCard elevated style={styles.card}>
                  <ManualField
                    label="Food Name *"
                    value={name}
                    setter={setName}
                    placeholder="e.g., Grilled Chicken"
                    fieldKey="name"
                    focused={focusedField}
                    setFocused={setFocusedField}
                  />

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
                          style={[styles.pill, active && styles.pillActive]}
                          accessibilityRole="button"
                          accessibilityState={{ selected: active }}
                        >
                          <Text style={[styles.pillText, active && styles.pillTextActive]}>
                            {type.label}
                          </Text>
                        </Pressable>
                      );
                    })}
                  </View>

                  <View style={styles.macroGrid}>
                    <View style={styles.macroCol}>
                      <ManualField
                        label="Calories *"
                        value={calories}
                        setter={setCalories}
                        placeholder="350"
                        fieldKey="cal"
                        focused={focusedField}
                        setFocused={setFocusedField}
                        numeric
                      />
                    </View>
                    <View style={styles.macroCol}>
                      <ManualField
                        label="Protein (g) *"
                        value={protein}
                        setter={setProtein}
                        placeholder="25"
                        fieldKey="protein"
                        focused={focusedField}
                        setFocused={setFocusedField}
                        numeric
                      />
                    </View>
                  </View>

                  <ActionButton
                    variant="primary"
                    onPress={handleManualSubmit}
                    loading={loading}
                    style={styles.submitBtn}
                  >
                    Log Food
                  </ActionButton>
                </GlassCard>

                <Pressable
                  onPress={() => {
                    Haptics.selectionAsync();
                    setShowManual(false);
                  }}
                  style={styles.manualToggle}
                  accessibilityRole="button"
                >
                  <Ionicons name="search" size={18} color={colors.primary} />
                  <Text style={styles.manualToggleText}>Search foods instead</Text>
                </Pressable>
              </Animated.View>
            </ScrollView>
          )}
        </KeyboardAvoidingView>
      </SafeAreaView>
    </LinearGradient>
  );
}

function DailySummary({ totals }) {
  return (
    <View style={styles.summaryBar}>
      <Text style={styles.summaryText}>
        Today: {Math.round(totals.calories)} cal · {Math.round(totals.protein)}g protein
      </Text>
    </View>
  );
}

function ManualField({ label, value, setter, placeholder, fieldKey, focused, setFocused, numeric = false }) {
  return (
    <View style={styles.fieldWrap}>
      <Text style={styles.label}>{label}</Text>
      <TextInput
        style={[styles.input, focused === fieldKey && styles.inputFocused]}
        placeholder={placeholder}
        placeholderTextColor={colors.textMuted}
        value={value}
        onChangeText={setter}
        onFocus={() => setFocused(fieldKey)}
        onBlur={() => setFocused(null)}
        keyboardType={numeric ? 'numeric' : 'default'}
      />
    </View>
  );
}

export default function LogFoodScreen(props) {
  return (
    <ErrorBoundary>
      <LogFoodScreenInner {...props} />
    </ErrorBoundary>
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
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.sm,
  },
  backBtn: {
    minWidth: 44,
    minHeight: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    fontSize: fontSize.lg,
    fontWeight: fontWeight.bold,
    color: colors.textPrimary,
  },
  summaryBar: {
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
  },
  summaryText: {
    fontSize: fontSize.sm,
    color: colors.primary,
    fontWeight: fontWeight.medium,
    textAlign: 'center',
  },
  searchWrap: {
    paddingHorizontal: spacing.lg,
    marginBottom: spacing.md,
  },
  scroll: {
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing['2xl'],
  },
  listContent: {
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing['2xl'],
  },
  sectionTitle: {
    fontSize: fontSize.base,
    fontWeight: fontWeight.semibold,
    color: colors.textPrimary,
    marginTop: spacing.md,
    marginBottom: spacing.sm,
  },
  manualToggle: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
    paddingVertical: spacing.lg,
    minHeight: 44,
  },
  manualToggleText: {
    fontSize: fontSize.sm,
    color: colors.primary,
    fontWeight: fontWeight.medium,
  },
  card: {
    padding: 0,
    overflow: 'hidden',
  },
  fieldWrap: {
    marginBottom: spacing.sm,
    padding: spacing.md,
    paddingBottom: 0,
  },
  label: {
    fontSize: fontSize.sm,
    fontWeight: fontWeight.semibold,
    color: colors.textSecondary,
    marginBottom: spacing.xs,
    marginTop: spacing.sm,
    textTransform: 'uppercase',
    letterSpacing: 0.8,
    paddingHorizontal: spacing.md,
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
    paddingHorizontal: spacing.md,
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
    paddingHorizontal: spacing.md,
  },
  macroCol: {
    flex: 1,
  },
  submitBtn: {
    marginTop: spacing.lg,
    marginHorizontal: spacing.md,
    marginBottom: spacing.md,
    minHeight: 52,
  },
  skeletons: {
    paddingHorizontal: spacing.lg,
    marginTop: spacing.md,
  },
});
