import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import StepContainer from '../../../components/onboarding/StepContainer';
import GlassCard from '../../../components/GlassCard';
import Toggle from '../../../components/Toggle';
import { colors, spacing, fontSize, fontWeight, radii } from '../../../theme/colors';

function NotifRow({ icon, iconColor, title, description, value, onChange }) {
  return (
    <View style={styles.row}>
      <View style={[styles.iconCircle, { backgroundColor: `${iconColor}22` }]}>
        <Ionicons name={icon} size={18} color={iconColor} />
      </View>
      <View style={styles.rowText}>
        <Text style={styles.rowTitle}>{title}</Text>
        <Text style={styles.rowDesc}>{description}</Text>
      </View>
      <Toggle value={value} onValueChange={onChange} />
    </View>
  );
}

export default function Step11Notifications({ data, update }) {
  const notif = data.notifications ?? {
    dailyReminder: true,
    reminderTime: '20:00',
    weeklyReport: true,
    streakAlerts: true,
    achievementAlerts: true,
  };

  const set = (key, val) => {
    update({ notifications: { ...notif, [key]: val } });
  };

  const rh = parseInt((notif.reminderTime ?? '20:00').split(':')[0], 10);

  return (
    <StepContainer title="Last step — stay on track">
      <GlassCard style={styles.card}>
        <NotifRow
          icon="alarm-outline"
          iconColor={colors.primary}
          title="Daily Check-in Reminder"
          description={`Remind me at ${rh > 12 ? rh - 12 : rh}:00 ${rh >= 12 ? 'PM' : 'AM'}`}
          value={notif.dailyReminder ?? true}
          onChange={(v) => set('dailyReminder', v)}
        />

        {notif.dailyReminder && (
          <View style={styles.timeRow}>
            <Pressable
              onPress={() => { Haptics.selectionAsync(); set('reminderTime', `${String(Math.max(rh - 1, 6)).padStart(2, '0')}:00`); }}
              style={styles.timeBtn}
              accessibilityLabel="Earlier reminder"
            >
              <Text style={styles.timeBtnText}>-</Text>
            </Pressable>
            <Text style={styles.timeValue}>
              {rh > 12 ? rh - 12 : rh}:00 {rh >= 12 ? 'PM' : 'AM'}
            </Text>
            <Pressable
              onPress={() => { Haptics.selectionAsync(); set('reminderTime', `${String(Math.min(rh + 1, 22)).padStart(2, '0')}:00`); }}
              style={styles.timeBtn}
              accessibilityLabel="Later reminder"
            >
              <Text style={styles.timeBtnText}>+</Text>
            </Pressable>
          </View>
        )}

        <NotifRow
          icon="bar-chart-outline"
          iconColor={colors.success}
          title="Weekly Progress Report"
          description="Every Sunday at 8 PM — your week in review"
          value={notif.weeklyReport ?? true}
          onChange={(v) => set('weeklyReport', v)}
        />

        <NotifRow
          icon="flame-outline"
          iconColor={colors.warning}
          title="Streak Protection Alerts"
          description="Alert me if I haven't logged by 7 PM"
          value={notif.streakAlerts ?? true}
          onChange={(v) => set('streakAlerts', v)}
        />

        <NotifRow
          icon="trophy-outline"
          iconColor="#fbbf24"
          title="Achievement Celebrations"
          description="Notify me when I unlock achievements"
          value={notif.achievementAlerts ?? true}
          onChange={(v) => set('achievementAlerts', v)}
        />
      </GlassCard>
    </StepContainer>
  );
}

export function validate() { return true; }

const styles = StyleSheet.create({
  card: { padding: 0, overflow: 'hidden' },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
    paddingHorizontal: 16,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.borderSubtle,
  },
  iconCircle: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  rowText: { flex: 1, marginRight: 12 },
  rowTitle: { color: colors.textPrimary, fontSize: fontSize.sm, fontWeight: fontWeight.semibold },
  rowDesc: { color: colors.textMuted, fontSize: fontSize.xs, marginTop: 2 },
  timeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: spacing.sm,
    gap: spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.borderSubtle,
  },
  timeBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: colors.surface2,
    alignItems: 'center',
    justifyContent: 'center',
    minWidth: 44,
    minHeight: 44,
  },
  timeBtnText: { color: colors.primary, fontSize: fontSize.base, fontWeight: fontWeight.bold },
  timeValue: { color: colors.textPrimary, fontSize: fontSize.lg, fontWeight: fontWeight.bold, minWidth: 80, textAlign: 'center' },
});
