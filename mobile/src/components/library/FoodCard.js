import React, { useState, useCallback } from 'react';
import { View, Text, Image, Pressable, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { colors, radii, fontSize, fontWeight, spacing } from '../../theme/colors';
import GlassCard from '../GlassCard';
import MacroPills from './MacroPills';

export default function FoodCard({
  food,
  onPress,
  onLongPress,
  onToggleFavorite,
  isFavorite = false,
  compact = false,
}) {
  const [imgError, setImgError] = useState(false);

  const handleFavToggle = useCallback(() => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    onToggleFavorite?.(food);
  }, [food, onToggleFavorite]);

  const handlePress = useCallback(() => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    onPress?.(food);
  }, [food, onPress]);

  const handleLongPress = useCallback(() => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    onLongPress?.(food);
  }, [food, onLongPress]);

  const initial = (food.name ?? '?').charAt(0).toUpperCase();
  const showImg = food.imageUrl && !imgError;

  if (compact) {
    return (
      <Pressable
        onPress={handlePress}
        accessibilityRole="button"
        accessibilityLabel={food.name}
      >
        <GlassCard style={styles.compactCard}>
          <FoodThumb
            showImg={showImg}
            imageUrl={food.imageUrl}
            initial={initial}
            onImgError={() => setImgError(true)}
            compact
          />
          <Text style={styles.compactName} numberOfLines={1}>{food.name}</Text>
          <Text style={styles.compactCal}>{food.calories ?? 0} kcal</Text>
        </GlassCard>
      </Pressable>
    );
  }

  return (
    <Pressable
      onPress={handlePress}
      onLongPress={handleLongPress}
      delayLongPress={400}
      accessibilityRole="button"
      accessibilityLabel={`${food.name}, ${food.calories} calories`}
      style={({ pressed }) => pressed && styles.pressed}
    >
      <GlassCard style={styles.card}>
        <View style={styles.row}>
          <FoodThumb
            showImg={showImg}
            imageUrl={food.imageUrl}
            initial={initial}
            onImgError={() => setImgError(true)}
          />
          <View style={styles.center}>
            <Text style={styles.name} numberOfLines={1}>{food.name}</Text>
            {food.brand ? (
              <Text style={styles.brand} numberOfLines={1}>{food.brand}</Text>
            ) : null}
            <MacroPills
              protein={food.protein ?? 0}
              carbs={food.carbs ?? 0}
              fat={food.fat ?? 0}
            />
          </View>
          <View style={styles.right}>
            <Text style={styles.calories}>{food.calories ?? 0}</Text>
            <Text style={styles.kcalLabel}>kcal</Text>
            {onToggleFavorite && (
              <Pressable
                onPress={handleFavToggle}
                hitSlop={12}
                style={styles.heartBtn}
                accessibilityRole="button"
                accessibilityLabel={isFavorite ? 'Remove from favorites' : 'Add to favorites'}
              >
                <Ionicons
                  name={isFavorite ? 'heart' : 'heart-outline'}
                  size={20}
                  color={isFavorite ? colors.accent : colors.textMuted}
                />
              </Pressable>
            )}
          </View>
        </View>
      </GlassCard>
    </Pressable>
  );
}

function FoodThumb({ showImg, imageUrl, initial, onImgError, compact = false }) {
  const size = compact ? 40 : 48;

  if (showImg) {
    return (
      <Image
        source={{ uri: imageUrl }}
        style={[styles.thumb, { width: size, height: size }]}
        onError={onImgError}
      />
    );
  }

  return (
    <View
      style={[
        styles.thumbFallback,
        { width: size, height: size },
      ]}
    >
      <Text style={styles.thumbInitial}>{initial}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    padding: 0,
    marginBottom: spacing.sm,
  },
  pressed: {
    opacity: 0.85,
    transform: [{ scale: 0.98 }],
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
  },
  thumb: {
    borderRadius: radii.sm,
    backgroundColor: colors.surface2,
  },
  thumbFallback: {
    borderRadius: radii.sm,
    backgroundColor: 'rgba(139,92,246,0.15)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  thumbInitial: {
    fontSize: fontSize.lg,
    fontWeight: fontWeight.bold,
    color: colors.primary,
  },
  center: {
    flex: 1,
    marginLeft: spacing.md,
    gap: 4,
  },
  name: {
    fontSize: fontSize.base,
    fontWeight: fontWeight.bold,
    color: colors.textPrimary,
  },
  brand: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
  },
  right: {
    alignItems: 'flex-end',
    marginLeft: spacing.sm,
  },
  calories: {
    fontSize: fontSize.lg,
    fontWeight: fontWeight.bold,
    color: colors.primary,
  },
  kcalLabel: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
    marginTop: -2,
  },
  heartBtn: {
    minWidth: 44,
    minHeight: 44,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 2,
  },
  compactCard: {
    padding: 0,
    width: 120,
    marginRight: spacing.sm,
  },
  compactName: {
    fontSize: fontSize.xs,
    fontWeight: fontWeight.semibold,
    color: colors.textPrimary,
    paddingHorizontal: spacing.sm,
    marginTop: spacing.xs,
  },
  compactCal: {
    fontSize: fontSize.xs,
    color: colors.primary,
    paddingHorizontal: spacing.sm,
    paddingBottom: spacing.sm,
    fontWeight: fontWeight.medium,
  },
});
