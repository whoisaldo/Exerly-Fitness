import React, { useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  Pressable,
  Alert,
  Platform,
  StyleSheet,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import AsyncStorage from '@react-native-async-storage/async-storage';
import ErrorBoundary from '../components/ErrorBoundary';
import GlassCard from '../components/GlassCard';
import StatCard from '../components/StatCard';
import Toggle from '../components/Toggle';
import ActionButton from '../components/ActionButton';
import { useAuth } from '../context/AuthContext';
import {
  colors,
  gradients,
  spacing,
  fontSize,
  fontWeight,
  radii,
} from '../theme/colors';

function SettingRow({ icon, label, right, onPress }) {
  return (
    <Pressable
      onPress={onPress}
      style={styles.settingRow}
      accessibilityRole={onPress ? 'button' : 'text'}
      accessibilityLabel={label}
    >
      <Ionicons name={icon} size={20} color={colors.textSecondary} />
      <Text style={styles.settingLabel}>{label}</Text>
      <View style={styles.settingRight}>
        {right ?? <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />}
      </View>
    </Pressable>
  );
}

function ProfileScreenInner() {
  const { user, logout } = useAuth();
  const [dailyReminder, setDailyReminder] = useState(true);
  const [weeklySummary, setWeeklySummary] = useState(true);
  const [achievementAlerts, setAchievementAlerts] = useState(true);
  const [streakAlerts, setStreakAlerts] = useState(true);
  const [challengeUpdates, setChallengeUpdates] = useState(true);
  const [useMetric, setUseMetric] = useState(false);

  const initials = (user?.name ?? 'U')
    .split(' ')
    .map((w) => w[0])
    .join('')
    .slice(0, 2)
    .toUpperCase();

  const handleLogout = () => {
    Alert.alert('Logout', 'Are you sure?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Logout', style: 'destructive', onPress: logout },
    ]);
  };

  return (
    <LinearGradient
      colors={[colors.deep, colors.surface1, colors.dark]}
      locations={[0, 0.5, 1]}
      style={styles.container}
    >
      <SafeAreaView style={styles.safe} edges={['top']}>
        <ScrollView
          contentContainerStyle={styles.scroll}
          showsVerticalScrollIndicator={false}
        >
          <View style={styles.header}>
            <LinearGradient
              colors={gradients.primary}
              style={styles.avatar}
            >
              <Text style={styles.avatarText}>{initials}</Text>
            </LinearGradient>
            <Text style={styles.name}>{user?.name ?? 'User'}</Text>
            <Text style={styles.email}>{user?.email}</Text>
          </View>

          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.statsRow}
          >
            <StatCard icon="fitness" label="Activities" value="--" />
            <StatCard icon="flame" label="Streak" value="--" color={colors.warning} />
            <StatCard icon="barbell" label="Workouts" value="--" color={colors.success} />
          </ScrollView>

          <Text style={styles.sectionTitle}>Account</Text>
          <GlassCard style={styles.section}>
            <SettingRow icon="person-outline" label="Edit Profile" onPress={() => {}} />
            <SettingRow
              icon="swap-horizontal"
              label="Units"
              right={
                <View style={styles.unitRow}>
                  <Text style={styles.unitLabel}>{useMetric ? 'Metric' : 'Imperial'}</Text>
                  <Toggle value={useMetric} onValueChange={setUseMetric} />
                </View>
              }
            />
          </GlassCard>

          <Text style={styles.sectionTitle}>Notifications</Text>
          <GlassCard style={styles.section}>
            <SettingRow
              icon="alarm-outline"
              label="Daily Reminder"
              right={<Toggle value={dailyReminder} onValueChange={setDailyReminder} />}
            />
            <SettingRow
              icon="calendar-outline"
              label="Weekly Summary"
              right={<Toggle value={weeklySummary} onValueChange={setWeeklySummary} />}
            />
            <SettingRow
              icon="trophy-outline"
              label="Achievement Alerts"
              right={<Toggle value={achievementAlerts} onValueChange={setAchievementAlerts} />}
            />
            <SettingRow
              icon="flame-outline"
              label="Streak at Risk"
              right={<Toggle value={streakAlerts} onValueChange={setStreakAlerts} />}
            />
            <SettingRow
              icon="flag-outline"
              label="Challenge Updates"
              right={<Toggle value={challengeUpdates} onValueChange={setChallengeUpdates} />}
            />
          </GlassCard>

          {Platform.OS !== 'web' && (
            <>
              <Text style={styles.sectionTitle}>Integrations</Text>
              <GlassCard style={styles.section}>
                {Platform.OS === 'ios' && (
                  <SettingRow
                    icon="heart-outline"
                    label="Apple Health"
                    right={<Toggle value={false} onValueChange={() => {}} />}
                  />
                )}
                {Platform.OS === 'android' && (
                  <SettingRow
                    icon="fitness-outline"
                    label="Google Fit"
                    right={<Toggle value={false} onValueChange={() => {}} />}
                  />
                )}
              </GlassCard>
            </>
          )}

          <Text style={styles.sectionTitle}>Developer</Text>
          <GlassCard style={styles.section}>
            <SettingRow
              icon="refresh-outline"
              label="Reset Onboarding (DEV)"
              onPress={() =>
                Alert.alert('Reset Onboarding', 'This will show the setup wizard again on next launch.', [
                  { text: 'Cancel', style: 'cancel' },
                  {
                    text: 'Reset',
                    style: 'destructive',
                    onPress: async () => {
                      await AsyncStorage.removeItem('onboarding_complete');
                      await AsyncStorage.removeItem('onboarding_progress');
                      await AsyncStorage.removeItem('starter_workout_plan');
                      Alert.alert('Done', 'Force-close and reopen the app to see the wizard.');
                    },
                  },
                ])
              }
            />
          </GlassCard>

          <Text style={styles.sectionTitle}>Data</Text>
          <GlassCard style={styles.section}>
            <SettingRow icon="download-outline" label="Export My Data" onPress={() => {}} />
            <SettingRow
              icon="trash-outline"
              label="Delete Account"
              onPress={() =>
                Alert.alert('Delete Account', 'This action cannot be undone.', [
                  { text: 'Cancel', style: 'cancel' },
                  { text: 'Delete', style: 'destructive' },
                ])
              }
            />
          </GlassCard>

          <ActionButton
            title="Log Out"
            onPress={handleLogout}
            variant="destructive"
            fullWidth
            style={styles.logoutBtn}
          />
        </ScrollView>
      </SafeAreaView>
    </LinearGradient>
  );
}

export default function ProfileScreen() {
  return (
    <ErrorBoundary>
      <ProfileScreenInner />
    </ErrorBoundary>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  safe: { flex: 1 },
  scroll: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
    paddingBottom: 120,
  },
  header: { alignItems: 'center', marginBottom: spacing.lg },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    color: '#fff',
    fontSize: fontSize['2xl'],
    fontWeight: fontWeight.bold,
  },
  name: {
    color: colors.textPrimary,
    fontSize: fontSize.xl,
    fontWeight: fontWeight.bold,
    marginTop: spacing.md,
  },
  email: {
    color: colors.textMuted,
    fontSize: fontSize.sm,
    marginTop: 2,
  },
  statsRow: { gap: spacing.sm, marginBottom: spacing.lg },
  sectionTitle: {
    color: colors.textSecondary,
    fontSize: fontSize.xs,
    fontWeight: fontWeight.semibold,
    textTransform: 'uppercase',
    letterSpacing: 1.2,
    marginTop: spacing.lg,
    marginBottom: spacing.sm,
  },
  section: { padding: 0, overflow: 'hidden' },
  settingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
    paddingHorizontal: 16,
    minHeight: 48,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.borderSubtle,
  },
  settingLabel: {
    flex: 1,
    color: colors.textPrimary,
    fontSize: fontSize.base,
    marginLeft: 12,
  },
  settingRight: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  unitRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  unitLabel: { color: colors.textMuted, fontSize: fontSize.xs },
  logoutBtn: { marginTop: spacing.xl },
});
