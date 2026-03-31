import React, { useState, useMemo, useEffect, useCallback } from 'react';
import { View, Text, Pressable, TextInput, StyleSheet } from 'react-native';
import * as Haptics from 'expo-haptics';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
} from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { colors, radii, fontSize, fontWeight, spacing } from '../../theme/colors';

export default function ServingSelector({ food, onChange }) {
  const units = useMemo(() => buildUnits(food), [food]);
  const [unitIdx, setUnitIdx] = useState(0);
  const [amount, setAmount] = useState(1);
  const [customGrams, setCustomGrams] = useState('100');
  const [editing, setEditing] = useState(false);
  const scale = useSharedValue(1);

  const unit = units[unitIdx];

  const totalGrams = useMemo(() => {
    if (unit.custom) return parseFloat(customGrams) || 0;
    return Math.round(amount * unit.grams * 10) / 10;
  }, [amount, unit, customGrams]);

  useEffect(() => {
    onChange?.(totalGrams);
  }, [totalGrams, onChange]);

  const animStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const bump = useCallback(() => {
    scale.value = withSpring(1, { damping: 8 }, () => {
      scale.value = 1;
    });
    scale.value = 1.1;
  }, [scale]);

  const stepSize = unit.custom ? 5 : 0.5;
  const minVal = unit.custom ? 1 : 0.5;
  const maxVal = unit.custom ? 9999 : 99;

  const clampValue = useCallback((value) => {
    const parsed = parseFloat(value);
    if (Number.isNaN(parsed)) return minVal;
    return Math.max(minVal, Math.min(maxVal, parsed));
  }, [maxVal, minVal]);

  const decrement = useCallback(() => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (unit.custom) {
      setCustomGrams((prev) => {
        const next = Math.max(minVal, (parseFloat(prev) || 0) - stepSize);
        return String(next);
      });
    } else {
      setAmount((prev) => Math.max(minVal, prev - stepSize));
    }
    bump();
  }, [unit, bump, minVal, stepSize]);

  const increment = useCallback(() => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (unit.custom) {
      setCustomGrams((prev) => {
        const next = Math.min(maxVal, (parseFloat(prev) || 0) + stepSize);
        return String(next);
      });
    } else {
      setAmount((prev) => Math.min(maxVal, prev + stepSize));
    }
    bump();
  }, [unit, bump, maxVal, stepSize]);

  const selectUnit = useCallback((idx) => {
    Haptics.selectionAsync();
    setUnitIdx(idx);
    setAmount(1);
    setCustomGrams('100');
  }, []);

  const displayVal = unit.custom
    ? customGrams
    : amount % 1 === 0 ? String(amount) : amount.toFixed(1);

  return (
    <View style={styles.container}>
      <Text style={styles.label}>Serving size</Text>

      <View style={styles.stepperRow}>
        <Pressable
          onPress={decrement}
          style={styles.stepBtn}
          accessibilityRole="button"
          accessibilityLabel="Decrease serving"
        >
          <Ionicons name="remove" size={20} color={colors.textPrimary} />
        </Pressable>

        <Animated.View style={[styles.amountWrap, animStyle]}>
          {editing ? (
            <TextInput
              style={styles.amountInput}
              value={displayVal}
              onChangeText={(t) => {
                if (unit.custom) setCustomGrams(t.replace(/[^0-9.]/g, ''));
                else {
                  const n = parseFloat(t);
                  if (t === '') {
                    setAmount(minVal);
                  } else if (!isNaN(n)) {
                    setAmount(Math.max(minVal, Math.min(maxVal, n)));
                  }
                }
              }}
              onBlur={() => {
                if (unit.custom) {
                  setCustomGrams(String(clampValue(customGrams)));
                } else {
                  setAmount((prev) => clampValue(prev));
                }
                setEditing(false);
              }}
              keyboardType="decimal-pad"
              autoFocus
              selectTextOnFocus
            />
          ) : (
            <Pressable onPress={() => setEditing(true)}>
              <Text style={styles.amountText}>{displayVal}</Text>
            </Pressable>
          )}
        </Animated.View>

        <Pressable
          onPress={increment}
          style={styles.stepBtn}
          accessibilityRole="button"
          accessibilityLabel="Increase serving"
        >
          <Ionicons name="add" size={20} color={colors.textPrimary} />
        </Pressable>
      </View>

      <View style={styles.unitRow}>
        {units.map((u, idx) => {
          const active = idx === unitIdx;
          return (
            <Pressable
              key={u.label}
              onPress={() => selectUnit(idx)}
              style={[styles.unitPill, active && styles.unitPillActive]}
              accessibilityRole="button"
              accessibilityState={{ selected: active }}
            >
              <Text style={[styles.unitText, active && styles.unitTextActive]}>
                {u.label}
              </Text>
            </Pressable>
          );
        })}
      </View>

      <Text style={styles.gramsChip}>{Math.round(totalGrams)}g total</Text>
    </View>
  );
}

function buildUnits(food) {
  const units = [];
  if (food?.servingSize && food.servingGrams && food.servingGrams !== 100) {
    units.push({
      label: food.servingSize,
      grams: food.servingGrams,
    });
  }
  units.push({ label: '100g', grams: 100 });
  units.push({ label: 'oz', grams: 28.35 });
  units.push({ label: 'g (custom)', grams: 1, custom: true });
  return units;
}

const styles = StyleSheet.create({
  container: {
    marginVertical: spacing.md,
  },
  label: {
    fontSize: fontSize.sm,
    fontWeight: fontWeight.semibold,
    color: colors.textSecondary,
    marginBottom: spacing.sm,
    textTransform: 'uppercase',
    letterSpacing: 0.8,
  },
  stepperRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.md,
    marginBottom: spacing.md,
  },
  stepBtn: {
    width: 44,
    height: 44,
    borderRadius: radii.full,
    backgroundColor: 'rgba(255,255,255,0.06)',
    borderWidth: 1,
    borderColor: colors.borderSubtle,
    alignItems: 'center',
    justifyContent: 'center',
  },
  amountWrap: {
    minWidth: 60,
    alignItems: 'center',
  },
  amountText: {
    fontSize: fontSize.xl,
    fontWeight: fontWeight.bold,
    color: colors.textPrimary,
  },
  amountInput: {
    fontSize: fontSize.xl,
    fontWeight: fontWeight.bold,
    color: colors.textPrimary,
    textAlign: 'center',
    minWidth: 60,
    padding: 0,
  },
  unitRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  unitPill: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: radii.full,
    borderWidth: 1,
    borderColor: colors.borderSubtle,
    backgroundColor: 'rgba(255,255,255,0.03)',
    minHeight: 44,
    justifyContent: 'center',
  },
  unitPillActive: {
    backgroundColor: 'rgba(139,92,246,0.15)',
    borderColor: colors.primary,
  },
  unitText: {
    fontSize: fontSize.sm,
    color: colors.textMuted,
    fontWeight: fontWeight.medium,
  },
  unitTextActive: {
    color: colors.primary,
  },
  gramsChip: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
    marginTop: spacing.sm,
    textAlign: 'center',
  },
});
