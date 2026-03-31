import React, { useState, useCallback, useMemo } from 'react';
import {
  View,
  Text,
  ScrollView,
  Image,
  Pressable,
  Alert,
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
import ServingSelector from '../../components/library/ServingSelector';
import NutritionFacts from '../../components/library/NutritionFacts';
import useFoodLibrary from '../../hooks/useFoodLibrary';

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

function FoodDetailScreenInner({ route, navigation }) {
  const { food, mode = 'view', mealType: initialMeal } = route.params;
  const library = useFoodLibrary();

  const [grams, setGrams] = useState(food.servingGrams ?? 100);
  const [mealType, setMealType] = useState(initialMeal ?? getDefaultMealType());
  const [logging, setLogging] = useState(false);
  const [imgError, setImgError] = useState(false);

  const isFav = useMemo(
    () => library.favorites.some((f) => f.id === food.id),
    [library.favorites, food.id],
  );

  const handleToggleFav = useCallback(async () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    await library.toggleFavorite(food);
  }, [library, food]);

  const handleLog = useCallback(async () => {
    if (grams <= 0) {
      Alert.alert('Invalid serving', 'Serving size must be greater than 0 grams.');
      return;
    }

    setLogging(true);
    try {
      await library.logFood(food, {
        grams,
        servings: grams / (food.servingGrams || 100),
        mealType,
      });
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      Alert.alert('Logged!', `Added to ${mealType}`, [
        { text: 'OK', onPress: () => navigation.goBack() },
      ]);
    } catch {
      Alert.alert('Error', 'Failed to log food');
    } finally {
      setLogging(false);
    }
  }, [food, grams, mealType, library, navigation]);

  const sourceLabel = food.source === 'custom' ? 'Custom'
    : food.source === 'usda' ? 'USDA' : 'Open Food Facts';
  const showImg = food.imageUrl && !imgError;

  return (
    <LinearGradient
      colors={[colors.deep, colors.surface1, colors.dark]}
      locations={[0, 0.5, 1]}
      style={styles.gradient}
    >
      <SafeAreaView style={styles.safe} edges={['top', 'bottom']}>
        <ScrollView
          contentContainerStyle={styles.scroll}
          showsVerticalScrollIndicator={false}
          keyboardShouldPersistTaps="handled"
        >
          <DetailHeader
            food={food}
            isFav={isFav}
            onBack={() => navigation.goBack()}
            onToggleFav={handleToggleFav}
          />

          {showImg && (
            <Animated.View entering={FadeInUp.delay(50).duration(500)}>
              <View style={styles.imageWrap}>
                <Image
                  source={{ uri: food.imageUrl }}
                  style={styles.image}
                  onError={() => setImgError(true)}
                />
                <LinearGradient
                  colors={['transparent', 'rgba(8,8,16,0.9)']}
                  style={styles.imageOverlay}
                />
              </View>
            </Animated.View>
          )}

          <Animated.View entering={FadeInUp.delay(100).duration(500)}>
            <Text style={styles.foodName}>{food.name}</Text>
            <View style={styles.metaRow}>
              {food.brand && <Text style={styles.metaText}>{food.brand}</Text>}
              <View style={styles.sourceBadge}>
                <Text style={styles.sourceText}>{sourceLabel}</Text>
              </View>
            </View>
          </Animated.View>

          <Animated.View entering={FadeInUp.delay(150).duration(500)}>
            <GlassCard style={styles.sectionCard}>
              <ServingSelector food={food} onChange={setGrams} />
            </GlassCard>
          </Animated.View>

          <Animated.View entering={FadeInUp.delay(200).duration(500)}>
            <GlassCard style={styles.sectionCard}>
              <NutritionFacts food={food} grams={grams} />
            </GlassCard>
          </Animated.View>

          {mode === 'log' && (
            <Animated.View entering={FadeInUp.delay(250).duration(500)}>
              <GlassCard style={styles.sectionCard}>
                <Text style={styles.sectionLabel}>Meal Type</Text>
                <View style={styles.mealRow}>
                  {MEAL_TYPES.map((m) => {
                    const active = mealType === m.id;
                    return (
                      <Pressable
                        key={m.id}
                        onPress={() => {
                          Haptics.selectionAsync();
                          setMealType(m.id);
                        }}
                        style={[styles.mealPill, active && styles.mealPillActive]}
                        accessibilityRole="button"
                        accessibilityState={{ selected: active }}
                      >
                        <Text style={[styles.mealText, active && styles.mealTextActive]}>
                          {m.label}
                        </Text>
                      </Pressable>
                    );
                  })}
                </View>
              </GlassCard>
            </Animated.View>
          )}
        </ScrollView>

        {mode === 'log' && (
          <View style={styles.bottomBar}>
            <ActionButton
              variant="primary"
              onPress={handleLog}
              loading={logging}
              fullWidth
              style={styles.logBtn}
            >
              Log This Food
            </ActionButton>
          </View>
        )}

        {mode === 'view' && (
          <View style={styles.bottomBar}>
            <ActionButton
              variant="primary"
              onPress={() => {
                navigation.replace('FoodDetail', { food, mode: 'log' });
              }}
              fullWidth
              style={styles.logBtn}
            >
              Log This Food
            </ActionButton>
          </View>
        )}
      </SafeAreaView>
    </LinearGradient>
  );
}

function DetailHeader({ food, isFav, onBack, onToggleFav }) {
  return (
    <View style={styles.header}>
      <Pressable
        onPress={() => {
          Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
          onBack();
        }}
        style={styles.headerBtn}
        accessibilityRole="button"
        accessibilityLabel="Go back"
      >
        <Ionicons name="chevron-back" size={24} color={colors.textPrimary} />
      </Pressable>
      <Text style={styles.headerTitle} numberOfLines={1}>{food.name}</Text>
      <Pressable
        onPress={onToggleFav}
        style={styles.headerBtn}
        accessibilityRole="button"
        accessibilityLabel={isFav ? 'Remove from favorites' : 'Add to favorites'}
      >
        <Ionicons
          name={isFav ? 'heart' : 'heart-outline'}
          size={24}
          color={isFav ? colors.accent : colors.textPrimary}
        />
      </Pressable>
    </View>
  );
}

export default function FoodDetailScreen(props) {
  return (
    <ErrorBoundary>
      <FoodDetailScreenInner {...props} />
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
  scroll: {
    paddingHorizontal: spacing.lg,
    paddingBottom: 120,
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
    flex: 1,
    fontSize: fontSize.md,
    fontWeight: fontWeight.semibold,
    color: colors.textPrimary,
    textAlign: 'center',
    marginHorizontal: spacing.sm,
  },
  imageWrap: {
    height: 200,
    borderRadius: radii.lg,
    overflow: 'hidden',
    marginBottom: spacing.md,
  },
  image: {
    width: '100%',
    height: '100%',
    resizeMode: 'cover',
  },
  imageOverlay: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: 80,
  },
  foodName: {
    fontSize: fontSize.xl,
    fontWeight: fontWeight.bold,
    color: colors.textPrimary,
  },
  metaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    marginTop: spacing.xs,
    marginBottom: spacing.md,
  },
  metaText: {
    fontSize: fontSize.sm,
    color: colors.textMuted,
  },
  sourceBadge: {
    backgroundColor: 'rgba(139,92,246,0.12)',
    paddingHorizontal: spacing.sm,
    paddingVertical: 2,
    borderRadius: radii.full,
  },
  sourceText: {
    fontSize: fontSize.xs,
    color: colors.primary,
    fontWeight: fontWeight.medium,
  },
  sectionCard: {
    marginBottom: spacing.md,
  },
  sectionLabel: {
    fontSize: fontSize.sm,
    fontWeight: fontWeight.semibold,
    color: colors.textSecondary,
    marginBottom: spacing.sm,
    textTransform: 'uppercase',
    letterSpacing: 0.8,
  },
  mealRow: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  mealPill: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: radii.full,
    borderWidth: 1,
    borderColor: colors.borderSubtle,
    backgroundColor: 'rgba(255,255,255,0.03)',
    alignItems: 'center',
    minHeight: 44,
    justifyContent: 'center',
  },
  mealPillActive: {
    backgroundColor: 'rgba(245,158,11,0.15)',
    borderColor: colors.nutrition,
  },
  mealText: {
    fontSize: fontSize.xs,
    fontWeight: fontWeight.semibold,
    color: colors.textMuted,
  },
  mealTextActive: {
    color: colors.nutrition,
  },
  bottomBar: {
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    borderTopWidth: 1,
    borderTopColor: colors.borderSubtle,
  },
  logBtn: {
    minHeight: 52,
  },
});
