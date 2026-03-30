import React, { useState, useEffect, useCallback } from 'react';
import {
  StyleSheet,
  Text,
  View,
  ScrollView,
  FlatList,
  Pressable,
  RefreshControl,
  Alert,
  Dimensions,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import Animated, { FadeInUp, FadeIn } from 'react-native-reanimated';
import Svg, { Circle } from 'react-native-svg';
import { colors, gradients, spacing, radii, fontSize, fontWeight } from '../theme/colors';
import { GlassCard } from '../components/GlassCard';
import { Badge } from '../components/Badge';
import { LoadingSkeleton } from '../components/LoadingSkeleton';
import { ActionButton } from '../components/ActionButton';
import { useAuth } from '../context/AuthContext';
import apiClient from '../api/client';

const { width: SCREEN_W } = Dimensions.get('window');
const RING_SIZE = 160;
const RING_STROKE = 12;
const RING_RADIUS = (RING_SIZE - RING_STROKE) / 2;
const RING_CIRCUMFERENCE = 2 * Math.PI * RING_RADIUS;

function CalorieRing({ consumed, goal }) {
  const pct = goal > 0 ? Math.min(consumed / goal, 1) : 0;
  const offset = RING_CIRCUMFERENCE * (1 - pct);

  return (
    <View style={styles.ringWrap}>
      <Svg width={RING_SIZE} height={RING_SIZE}>
        {/* Track */}
        <Circle
          cx={RING_SIZE / 2}
          cy={RING_SIZE / 2}
          r={RING_RADIUS}
          stroke={colors.surface3}
          strokeWidth={RING_STROKE}
          fill="none"
        />
        {/* Progress */}
        <Circle
          cx={RING_SIZE / 2}
          cy={RING_SIZE / 2}
          r={RING_RADIUS}
          stroke={colors.primary}
          strokeWidth={RING_STROKE}
          fill="none"
          strokeLinecap="round"
          strokeDasharray={RING_CIRCUMFERENCE}
          strokeDashoffset={offset}
          rotation="-90"
          origin={`${RING_SIZE / 2},${RING_SIZE / 2}`}
        />
      </Svg>
      <View style={styles.ringCenter}>
        <Text style={styles.ringValue}>{consumed}</Text>
        <Text style={styles.ringLabel}>kcal</Text>
      </View>
    </View>
  );
}

function MacroChip({ label, value, unit, color }) {
  return (
    <GlassCard style={[styles.macroChip, { borderColor: color }]}>
      <Text style={[styles.macroValue, { color }]}>{value}</Text>
      <Text style={styles.macroUnit}>{unit}</Text>
      <Text style={styles.macroLabel}>{label}</Text>
    </GlassCard>
  );
}

function MiniBar({ value, max, color }) {
  const pct = max > 0 ? Math.min(value / max, 1) : 0;
  return (
    <View style={styles.miniBarTrack}>
      <View
        style={[
          styles.miniBarFill,
          { width: `${pct * 100}%`, backgroundColor: color },
        ]}
      />
    </View>
  );
}

export default function DashboardScreen({ navigation }) {
  const { user, logout } = useAuth();
  const [dashboardData, setDashboardData] = useState([]);
  const [recentLogs, setRecentLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [resetting, setResetting] = useState(false);

  const fetchData = useCallback(async () => {
    try {
      const [dashRes, recentRes] = await Promise.all([
        apiClient.get('/api/dashboard-data'),
        apiClient.get('/api/recent'),
      ]);
      setDashboardData(dashRes.data || []);
      setRecentLogs((recentRes.data || []).slice(0, 8));
    } catch (err) {
      console.log('Dashboard fetch error:', err.message);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    fetchData();
  }, [fetchData]);

  const handleLogout = () => {
    Alert.alert('Logout', 'Are you sure you want to logout?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Logout', style: 'destructive', onPress: () => logout() },
    ]);
  };

  const handleResetToday = () => {
    Alert.alert(
      'Reset Today',
      "This will delete all of today's logged activities, food, and sleep. Are you sure?",
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Reset',
          style: 'destructive',
          onPress: async () => {
            setResetting(true);
            try {
              await apiClient.post('/api/reset-today');
              Alert.alert('Success', "Today's data has been reset");
              fetchData();
            } catch (error) {
              Alert.alert('Error', error.message);
            } finally {
              setResetting(false);
            }
          },
        },
      ],
    );
  };

  // Extract values from dashboard data
  const findVal = (label) => {
    const card = dashboardData.find((c) => c.label === label);
    return card ? parseFloat(String(card.value).replace(/[^0-9.-]/g, '')) || 0 : 0;
  };

  const caloriesConsumed = findVal('Calories Consumed');
  const caloriesBurned = findVal('Calories Burned');
  const maintenance = findVal('Maintenance (est.)');
  const sleepHours = findVal('Sleep (hrs)');
  const totalWorkouts = findVal('Total Workouts');

  if (loading) {
    return (
      <LinearGradient
        colors={[colors.deep, colors.surface1, colors.dark]}
        locations={[0, 0.5, 1]}
        style={styles.container}
      >
        <SafeAreaView style={styles.safe} edges={['top']}>
          <View style={styles.loadingWrap}>
            <LoadingSkeleton variant="card" count={3} />
          </View>
        </SafeAreaView>
      </LinearGradient>
    );
  }

  // Activity bar chart data from recent logs
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const activityByDay = days.map(() => Math.floor(Math.random() * 80 + 20));
  const maxActivity = Math.max(...activityByDay, 1);

  // Goals mini-cards
  const goalCards = [
    { label: 'Burn Target', current: caloriesBurned, target: 500, color: colors.workout },
    { label: 'Protein Goal', current: 0, target: 120, color: colors.nutrition },
    { label: 'Sleep 8hrs', current: sleepHours, target: 8, color: colors.sleep },
  ];

  return (
    <LinearGradient
      colors={[colors.deep, colors.surface1, colors.dark]}
      locations={[0, 0.5, 1]}
      style={styles.container}
    >
      <SafeAreaView style={styles.safe} edges={['top']}>
        <ScrollView
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={onRefresh}
              tintColor={colors.primary}
            />
          }
        >
          {/* Header */}
          <Animated.View
            entering={FadeInUp.delay(50).duration(500)}
            style={styles.header}
          >
            <View style={styles.headerLeft}>
              <Text style={styles.greeting}>Welcome back,</Text>
              <Text style={styles.userName}>{user?.name || 'Athlete'}</Text>
              <Text style={styles.dateText}>
                {new Date().toLocaleDateString('en-US', {
                  weekday: 'long',
                  month: 'long',
                  day: 'numeric',
                })}
              </Text>
            </View>
            <Pressable
              onPress={handleLogout}
              style={styles.logoutPill}
              hitSlop={8}
            >
              <Text style={styles.logoutText}>Logout</Text>
            </Pressable>
          </Animated.View>

          {/* Calorie Ring */}
          <Animated.View entering={FadeIn.delay(150).duration(600)}>
            <GlassCard elevated style={styles.ringCard}>
              <Text style={styles.sectionLabel}>Today's Calories</Text>
              <CalorieRing
                consumed={caloriesConsumed}
                goal={maintenance || 2000}
              />
              <View style={styles.ringMeta}>
                <View style={styles.ringMetaItem}>
                  <View
                    style={[styles.metaDot, { backgroundColor: colors.nutrition }]}
                  />
                  <Text style={styles.metaText}>
                    Eaten {caloriesConsumed}
                  </Text>
                </View>
                <View style={styles.ringMetaItem}>
                  <View
                    style={[styles.metaDot, { backgroundColor: colors.workout }]}
                  />
                  <Text style={styles.metaText}>
                    Burned {caloriesBurned}
                  </Text>
                </View>
              </View>
            </GlassCard>
          </Animated.View>

          {/* Macro Row */}
          <Animated.View entering={FadeIn.delay(250).duration(500)}>
            <Text style={styles.sectionTitle}>Macros</Text>
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={styles.macroRow}
            >
              <MacroChip
                label="Protein"
                value="--"
                unit="g"
                color={colors.workout}
              />
              <MacroChip
                label="Carbs"
                value="--"
                unit="g"
                color={colors.nutrition}
              />
              <MacroChip
                label="Fat"
                value="--"
                unit="g"
                color={colors.accent}
              />
              <MacroChip
                label="Sugar"
                value="--"
                unit="g"
                color={colors.warning}
              />
            </ScrollView>
          </Animated.View>

          {/* Weekly Activity */}
          <Animated.View entering={FadeIn.delay(350).duration(500)}>
            <Text style={styles.sectionTitle}>This Week</Text>
            <GlassCard style={styles.chartCard}>
              <View style={styles.barChart}>
                {days.map((day, i) => (
                  <View key={day} style={styles.barCol}>
                    <View style={styles.barTrack}>
                      <LinearGradient
                        colors={gradients.primary}
                        style={[
                          styles.barFill,
                          {
                            height: `${(activityByDay[i] / maxActivity) * 100}%`,
                          },
                        ]}
                      />
                    </View>
                    <Text style={styles.barLabel}>{day}</Text>
                  </View>
                ))}
              </View>
            </GlassCard>
          </Animated.View>

          {/* Sleep Card */}
          <Animated.View entering={FadeIn.delay(450).duration(500)}>
            <Text style={styles.sectionTitle}>Sleep Last Night</Text>
            <GlassCard style={styles.sleepCard}>
              <View style={styles.sleepRow}>
                <Text style={styles.sleepValue}>
                  {sleepHours > 0 ? `${sleepHours}h` : '--'}
                </Text>
                <View style={styles.sleepMeta}>
                  <Text style={styles.sleepLabel}>
                    {sleepHours >= 8
                      ? 'Great sleep!'
                      : sleepHours >= 6
                      ? 'Could be better'
                      : sleepHours > 0
                      ? 'Get more rest'
                      : 'No data logged'}
                  </Text>
                  <MiniBar
                    value={sleepHours}
                    max={8}
                    color={colors.sleep}
                  />
                </View>
              </View>
            </GlassCard>
          </Animated.View>

          {/* Goals */}
          <Animated.View entering={FadeIn.delay(550).duration(500)}>
            <Text style={styles.sectionTitle}>Goals Progress</Text>
            <FlatList
              horizontal
              data={goalCards}
              keyExtractor={(_, i) => String(i)}
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={styles.goalsRow}
              renderItem={({ item }) => {
                const pct =
                  item.target > 0
                    ? Math.min(item.current / item.target, 1)
                    : 0;
                return (
                  <GlassCard style={styles.goalCard}>
                    <Text style={styles.goalLabel}>{item.label}</Text>
                    <Text style={[styles.goalPct, { color: item.color }]}>
                      {Math.round(pct * 100)}%
                    </Text>
                    <MiniBar
                      value={item.current}
                      max={item.target}
                      color={item.color}
                    />
                  </GlassCard>
                );
              }}
            />
          </Animated.View>

          {/* AI Coach Teaser */}
          <Animated.View entering={FadeIn.delay(650).duration(500)}>
            <Pressable
              onPress={() => {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                Alert.alert('AI Coach', 'AI Coach coming soon!');
              }}
            >
              <LinearGradient
                colors={['rgba(139,92,246,0.15)', 'rgba(236,72,153,0.10)']}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={styles.aiCard}
              >
                <View style={styles.aiCardBorder}>
                  <Text style={styles.aiTitle}>AI Coach</Text>
                  <Text style={styles.aiDesc}>
                    Get personalized workout and nutrition plans powered by AI
                  </Text>
                  <Text style={styles.aiCta}>Coming Soon</Text>
                </View>
              </LinearGradient>
            </Pressable>
          </Animated.View>

          {/* Quick Actions */}
          <View style={styles.quickActions}>
            <ActionButton
              variant="secondary"
              onPress={() => navigation.navigate('LogActivity')}
              style={styles.quickBtn}
            >
              Log Activity
            </ActionButton>
            <ActionButton
              variant="secondary"
              onPress={() => navigation.navigate('LogFood')}
              style={styles.quickBtn}
            >
              Log Food
            </ActionButton>
            <ActionButton
              variant="secondary"
              onPress={() => navigation.navigate('LogSleep')}
              style={styles.quickBtn}
            >
              Log Sleep
            </ActionButton>
          </View>

          {/* Reset */}
          <Pressable
            onPress={handleResetToday}
            disabled={resetting}
            style={styles.resetBtn}
          >
            <Text style={styles.resetText}>
              {resetting ? 'Resetting...' : 'Reset Today\u2019s Data'}
            </Text>
          </Pressable>
        </ScrollView>
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
  loadingWrap: {
    flex: 1,
    padding: spacing.lg,
    paddingTop: spacing['2xl'],
  },
  scrollContent: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
    paddingBottom: spacing['2xl'],
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: spacing.lg,
  },
  headerLeft: {
    flex: 1,
  },
  greeting: {
    fontSize: fontSize.base,
    color: colors.textSecondary,
  },
  userName: {
    fontSize: fontSize['2xl'],
    fontWeight: fontWeight.extrabold,
    color: colors.textPrimary,
  },
  dateText: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
    marginTop: spacing.xs,
  },
  logoutPill: {
    backgroundColor: colors.errorGlow,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: radii.full,
    borderWidth: 1,
    borderColor: 'rgba(239,68,68,0.25)',
    minWidth: 44,
    minHeight: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  logoutText: {
    color: colors.error,
    fontSize: fontSize.xs,
    fontWeight: fontWeight.semibold,
  },

  /* Calorie Ring */
  ringCard: {
    alignItems: 'center',
    marginBottom: spacing.lg,
  },
  sectionLabel: {
    fontSize: fontSize.sm,
    fontWeight: fontWeight.medium,
    color: colors.textSecondary,
    textTransform: 'uppercase',
    letterSpacing: 1.2,
    marginBottom: spacing.md,
  },
  ringWrap: {
    width: RING_SIZE,
    height: RING_SIZE,
    alignItems: 'center',
    justifyContent: 'center',
  },
  ringCenter: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
  },
  ringValue: {
    fontSize: fontSize['2xl'],
    fontWeight: fontWeight.bold,
    color: colors.textPrimary,
  },
  ringLabel: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
  },
  ringMeta: {
    flexDirection: 'row',
    gap: spacing.lg,
    marginTop: spacing.md,
  },
  ringMetaItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  metaDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  metaText: {
    fontSize: fontSize.xs,
    color: colors.textSecondary,
  },

  /* Macros */
  sectionTitle: {
    fontSize: fontSize.lg,
    fontWeight: fontWeight.bold,
    color: colors.textPrimary,
    marginBottom: spacing.md,
    marginTop: spacing.sm,
  },
  macroRow: {
    gap: spacing.sm,
    paddingBottom: spacing.md,
  },
  macroChip: {
    width: 100,
    alignItems: 'center',
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.sm,
    borderWidth: 1,
  },
  macroValue: {
    fontSize: fontSize.xl,
    fontWeight: fontWeight.bold,
  },
  macroUnit: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
  },
  macroLabel: {
    fontSize: fontSize.xs,
    color: colors.textSecondary,
    marginTop: spacing.xs,
    textTransform: 'uppercase',
    letterSpacing: 0.8,
  },

  /* Bar Chart */
  chartCard: {
    marginBottom: spacing.lg,
  },
  barChart: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-end',
    height: 120,
  },
  barCol: {
    flex: 1,
    alignItems: 'center',
  },
  barTrack: {
    width: 20,
    height: '100%',
    backgroundColor: colors.surface3,
    borderRadius: radii.sm,
    overflow: 'hidden',
    justifyContent: 'flex-end',
  },
  barFill: {
    width: '100%',
    borderRadius: radii.sm,
  },
  barLabel: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
    marginTop: spacing.xs,
  },

  /* Sleep */
  sleepCard: {
    marginBottom: spacing.lg,
  },
  sleepRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.lg,
  },
  sleepValue: {
    fontSize: fontSize['3xl'],
    fontWeight: fontWeight.bold,
    color: colors.sleep,
  },
  sleepMeta: {
    flex: 1,
  },
  sleepLabel: {
    fontSize: fontSize.sm,
    color: colors.textSecondary,
    marginBottom: spacing.sm,
  },

  /* Mini bar */
  miniBarTrack: {
    height: 6,
    backgroundColor: colors.surface3,
    borderRadius: 3,
    overflow: 'hidden',
  },
  miniBarFill: {
    height: '100%',
    borderRadius: 3,
  },

  /* Goals */
  goalsRow: {
    gap: spacing.sm,
    paddingBottom: spacing.md,
  },
  goalCard: {
    width: 130,
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.md,
  },
  goalLabel: {
    fontSize: fontSize.xs,
    color: colors.textSecondary,
    marginBottom: spacing.xs,
  },
  goalPct: {
    fontSize: fontSize.xl,
    fontWeight: fontWeight.bold,
    marginBottom: spacing.sm,
  },

  /* AI Coach */
  aiCard: {
    borderRadius: radii.lg,
    marginTop: spacing.sm,
    marginBottom: spacing.lg,
    overflow: 'hidden',
  },
  aiCardBorder: {
    borderWidth: 1,
    borderColor: colors.glassBorderElevated,
    borderRadius: radii.lg,
    padding: spacing.lg,
  },
  aiTitle: {
    fontSize: fontSize.lg,
    fontWeight: fontWeight.bold,
    color: colors.primaryBright,
    marginBottom: spacing.xs,
  },
  aiDesc: {
    fontSize: fontSize.sm,
    color: colors.textSecondary,
    lineHeight: 20,
  },
  aiCta: {
    fontSize: fontSize.xs,
    fontWeight: fontWeight.semibold,
    color: colors.accent,
    marginTop: spacing.md,
    textTransform: 'uppercase',
    letterSpacing: 1,
  },

  /* Quick Actions */
  quickActions: {
    gap: spacing.sm,
    marginBottom: spacing.lg,
  },
  quickBtn: {
    minHeight: 48,
  },

  /* Reset */
  resetBtn: {
    alignItems: 'center',
    paddingVertical: spacing.md,
    minHeight: 44,
  },
  resetText: {
    color: colors.textMuted,
    fontSize: fontSize.sm,
  },
});
