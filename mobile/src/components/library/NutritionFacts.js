import React, { useMemo } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Svg, { Circle } from 'react-native-svg';
import Animated, { FadeIn } from 'react-native-reanimated';
import { calculateNutrition } from '../../services/FoodLibraryService';
import { colors, fontSize, fontWeight, spacing, radii } from '../../theme/colors';

const DV = {
  fat: 78, carbs: 275, protein: 50, fiber: 28,
  sodium: 2300, sugar: 50, saturatedFat: 20,
};

export default function NutritionFacts({ food, grams }) {
  const n = useMemo(() => calculateNutrition(food, grams), [food, grams]);

  const cals = Math.round((food.calories ?? 0) * grams / 100);
  const satFat = Math.round(((food.saturatedFat ?? 0) * grams / 100) * 10) / 10;

  const dvPct = (val, key) => Math.round((val / DV[key]) * 100);

  const totalMacroCal = (n.protein * 4) + (n.carbs * 4) + (n.fat * 9);
  const pPct = totalMacroCal > 0 ? (n.protein * 4) / totalMacroCal : 0.33;
  const cPct = totalMacroCal > 0 ? (n.carbs * 4) / totalMacroCal : 0.33;
  const fPct = totalMacroCal > 0 ? (n.fat * 9) / totalMacroCal : 0.34;

  return (
    <Animated.View entering={FadeIn.duration(400)} style={styles.container}>
      <View style={styles.calRow}>
        <View>
          <Text style={styles.calNumber}>{cals}</Text>
          <Text style={styles.calLabel}>calories per serving</Text>
        </View>
        <MacroRing pPct={pPct} cPct={cPct} fPct={fPct} />
      </View>

      <View style={styles.divider} />

      <NutrientRow label="Total Fat" value={`${n.fat}g`} dv={dvPct(n.fat, 'fat')} bold />
      <NutrientRow label="  Saturated Fat" value={`${satFat}g`} dv={dvPct(satFat, 'saturatedFat')} />
      <NutrientRow label="Total Carbohydrates" value={`${n.carbs}g`} dv={dvPct(n.carbs, 'carbs')} bold />
      <NutrientRow label="  Dietary Fiber" value={`${n.fiber}g`} dv={dvPct(n.fiber, 'fiber')} />
      <NutrientRow label="  Total Sugars" value={`${n.sugar}g`} />
      <NutrientRow label="Protein" value={`${n.protein}g`} dv={dvPct(n.protein, 'protein')} bold />

      <View style={styles.divider} />

      <NutrientRow label="Sodium" value={`${n.sodium}mg`} dv={dvPct(n.sodium, 'sodium')} />

      <Text style={styles.footnote}>* Based on a 2,000 calorie diet</Text>

      <View style={styles.legendRow}>
        <LegendDot color="#60a5fa" label={`Protein ${Math.round(pPct * 100)}%`} />
        <LegendDot color="#fbbf24" label={`Carbs ${Math.round(cPct * 100)}%`} />
        <LegendDot color="#fb7185" label={`Fat ${Math.round(fPct * 100)}%`} />
      </View>
    </Animated.View>
  );
}

function NutrientRow({ label, value, dv, bold = false }) {
  return (
    <View style={styles.nutrientRow}>
      <Text style={[styles.nutrientLabel, bold && styles.nutrientBold]}>{label}</Text>
      <View style={styles.nutrientRight}>
        <Text style={[styles.nutrientValue, bold && styles.nutrientBold]}>{value}</Text>
        {dv != null && (
          <Text style={styles.nutrientDv}>{dv}%</Text>
        )}
      </View>
    </View>
  );
}

function MacroRing({ pPct, cPct, fPct }) {
  const size = 64;
  const stroke = 6;
  const r = (size - stroke) / 2;
  const circumference = 2 * Math.PI * r;

  const pLen = pPct * circumference;
  const cLen = cPct * circumference;
  const fLen = fPct * circumference;

  const pOff = 0;
  const cOff = pLen;
  const fOff = pLen + cLen;

  return (
    <Svg width={size} height={size}>
      <Circle
        cx={size / 2} cy={size / 2} r={r}
        stroke="#fb7185" strokeWidth={stroke} fill="none"
        strokeDasharray={`${fLen} ${circumference - fLen}`}
        strokeDashoffset={-fOff}
        strokeLinecap="round"
        rotation={-90} origin={`${size / 2}, ${size / 2}`}
      />
      <Circle
        cx={size / 2} cy={size / 2} r={r}
        stroke="#fbbf24" strokeWidth={stroke} fill="none"
        strokeDasharray={`${cLen} ${circumference - cLen}`}
        strokeDashoffset={-cOff}
        strokeLinecap="round"
        rotation={-90} origin={`${size / 2}, ${size / 2}`}
      />
      <Circle
        cx={size / 2} cy={size / 2} r={r}
        stroke="#60a5fa" strokeWidth={stroke} fill="none"
        strokeDasharray={`${pLen} ${circumference - pLen}`}
        strokeDashoffset={-pOff}
        strokeLinecap="round"
        rotation={-90} origin={`${size / 2}, ${size / 2}`}
      />
    </Svg>
  );
}

function LegendDot({ color, label }) {
  return (
    <View style={styles.legendItem}>
      <View style={[styles.dot, { backgroundColor: color }]} />
      <Text style={styles.legendText}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    marginTop: spacing.md,
  },
  calRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.md,
  },
  calNumber: {
    fontSize: 48,
    fontWeight: fontWeight.bold,
    color: colors.primary,
  },
  calLabel: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
    marginTop: -4,
  },
  divider: {
    height: 1,
    backgroundColor: colors.borderSubtle,
    marginVertical: spacing.sm,
  },
  nutrientRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: spacing.xs + 2,
  },
  nutrientLabel: {
    fontSize: fontSize.sm,
    color: colors.textSecondary,
  },
  nutrientBold: {
    fontWeight: fontWeight.semibold,
    color: colors.textPrimary,
  },
  nutrientRight: {
    flexDirection: 'row',
    gap: spacing.md,
  },
  nutrientValue: {
    fontSize: fontSize.sm,
    color: colors.textSecondary,
    minWidth: 50,
    textAlign: 'right',
  },
  nutrientDv: {
    fontSize: fontSize.sm,
    color: colors.textMuted,
    minWidth: 36,
    textAlign: 'right',
  },
  footnote: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
    marginTop: spacing.md,
    fontStyle: 'italic',
  },
  legendRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: spacing.lg,
    marginTop: spacing.md,
  },
  legendItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: radii.full,
  },
  legendText: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
  },
});
