import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { colors, fontSize, fontWeight, radii, spacing } from '../../theme/colors';

const DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const KEYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

/**
 * 7-day workout calendar visualization.
 * @param {{ plan: Record<string, { type: string }> }} props
 */
export default function WeeklyCalendar({ plan }) {
  return (
    <View style={styles.row}>
      {DAYS.map((day, i) => {
        const entry = plan?.[KEYS[i]];
        const isWorkout = entry && entry.type !== 'Rest';
        return (
          <View key={day} style={styles.col}>
            <View style={[styles.circle, isWorkout && styles.active]}>
              <Text style={[styles.initial, isWorkout && styles.activeText]}>
                {day[0]}
              </Text>
            </View>
            <Text style={styles.label}>{day}</Text>
            <Text style={[styles.type, isWorkout && styles.typeActive]} numberOfLines={1}>
              {entry?.type ?? 'Rest'}
            </Text>
          </View>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  col: {
    alignItems: 'center',
    flex: 1,
  },
  circle: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: colors.surface2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  active: {
    backgroundColor: colors.primary,
  },
  initial: {
    color: colors.textMuted,
    fontSize: fontSize.sm,
    fontWeight: fontWeight.semibold,
  },
  activeText: {
    color: '#fff',
  },
  label: {
    color: colors.textMuted,
    fontSize: 9,
    marginTop: 4,
  },
  type: {
    color: colors.textMuted,
    fontSize: 8,
    marginTop: 1,
  },
  typeActive: {
    color: colors.primary,
    fontWeight: fontWeight.medium,
  },
});
