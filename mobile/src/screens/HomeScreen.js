import React, { useState, useEffect, useCallback, useMemo } from 'react';
import {
  StyleSheet,
  Text,
  View,
  FlatList,
  ScrollView,
  Pressable,
  RefreshControl,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { Ionicons } from '@expo/vector-icons';
import Animated, { FadeInUp, FadeInRight, FadeIn } from 'react-native-reanimated';
import { colors, spacing, radii, fontSize, fontWeight } from '../theme/colors';
import ErrorBoundary from '../components/ErrorBoundary';
import GlassCard from '../components/GlassCard';
import ProgressRing from '../components/ProgressRing';
import StatCard from '../components/StatCard';
import Badge from '../components/Badge';
import EmptyState from '../components/EmptyState';
import LoadingSkeleton from '../components/LoadingSkeleton';
import { useAuth } from '../context/AuthContext';
import { useNotificationContext } from '../context/NotificationContext';
import useStreak from '../hooks/useStreak';
import apiClient from '../api/client';
import { getGreeting } from '../utils/dateHelpers';

const LOG_COLORS = {
  activity: colors.workout,
  food: colors.nutrition,
  sleep: colors.sleep,
};

function HomeScreenInner({ navigation }) {
  const { user } = useAuth();
  const { unreadCount } = useNotificationContext();
  const [dashboardData, setDashboardData] = useState([]);
  const [recentLogs, setRecentLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const logDates = useMemo(
    () => recentLogs
      .filter((l) => l.type === 'activity')
      .map((l) => l.created_at ?? l.date),
    [recentLogs],
  );
  const { currentStreak, longestStreak, nextMilestone } = useStreak(logDates);

  const fetchData = useCallback(async () => {
    try {
      const [dashRes, recentRes] = await Promise.all([
        apiClient.get('/api/dashboard-data'),
        apiClient.get('/api/recent'),
      ]);
      setDashboardData(dashRes.data || []);
      setRecentLogs((recentRes.data || []).slice(0, 8));
    } catch (err) {
      // silent — empty state handles it
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    fetchData();
  }, [fetchData]);

  const firstName = user?.name?.split(' ')[0] || 'Athlete';

  const findVal = (label) => {
    const card = dashboardData.find((c) => c.label === label);
    return card ? parseFloat(String(card.value).replace(/[^0-9.-]/g, '')) || 0 : 0;
  };

  const caloriesConsumed = findVal('Calories Consumed');
  const calorieGoal = findVal('Maintenance (est.)') || 2000;

  const renderLogItem = ({ item, index }) => {
    const color = LOG_COLORS[item.type] || colors.primary;
    const title =
      item.type === 'activity' ? item.activity
        : item.type === 'food' ? item.name
        : `${item.hours}h sleep`;
    const meta =
      item.type === 'activity' ? `${item.duration_min} min \u00B7 ${item.calories} cal`
        : item.type === 'food' ? `${item.calories} cal \u00B7 ${item.protein}g protein`
        : `${item.quality} quality`;

    return (
      <Animated.View entering={FadeInRight.delay(index * 50).duration(350)}>
        <GlassCard style={[styles.logRow, { borderLeftColor: color, borderLeftWidth: 3 }]}>
          <View style={[styles.logDot, { backgroundColor: color }]} />
          <View style={styles.logContent}>
            <Text style={styles.logTitle} numberOfLines={1}>{title}</Text>
            <Text style={styles.logMeta}>{meta}</Text>
          </View>
          {item.type !== 'sleep' && (
            <Text style={[styles.logCal, { color }]}>
              {item.type === 'food' ? '+' : '-'}{item.calories}
            </Text>
          )}
        </GlassCard>
      </Animated.View>
    );
  };

  if (loading) {
    return (
      <LinearGradient colors={[colors.deep, colors.surface1, colors.dark]} locations={[0, 0.5, 1]} style={styles.container}>
        <SafeAreaView style={styles.safe} edges={['top']}>
          <View style={styles.loadingWrap}>
            <LoadingSkeleton variant="card" />
            <LoadingSkeleton variant="stat" count={3} style={styles.skelGap} />
          </View>
        </SafeAreaView>
      </LinearGradient>
    );
  }

  return (
    <LinearGradient colors={[colors.deep, colors.surface1, colors.dark]} locations={[0, 0.5, 1]} style={styles.container}>
      <SafeAreaView style={styles.safe} edges={['top']}>
        <FlatList
          data={recentLogs}
          keyExtractor={(_, i) => String(i)}
          renderItem={renderLogItem}
          contentContainerStyle={styles.listContent}
          showsVerticalScrollIndicator={false}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={colors.primary} />
          }
          ListHeaderComponent={
            <View>
              {/* Header row */}
              <Animated.View entering={FadeInUp.delay(80).duration(500)} style={styles.headerRow}>
                <View style={styles.headerLeft}>
                  <Text style={styles.greeting}>
                    {getGreeting()},{' '}
                    <Text style={styles.greetingName}>{firstName}</Text>
                  </Text>
                  <Text style={styles.dateText}>
                    {new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })}
                  </Text>
                </View>
                <Pressable
                  onPress={() => navigation.navigate('Notifications')}
                  style={styles.bellBtn}
                  accessibilityLabel="Notifications"
                  accessibilityRole="button"
                >
                  <Ionicons name="notifications-outline" size={24} color={colors.textPrimary} />
                  {unreadCount > 0 && <View style={styles.bellDot} />}
                </Pressable>
              </Animated.View>

              {/* Calorie Ring Hero */}
              <Animated.View entering={FadeIn.delay(150).duration(600)}>
                <GlassCard glow style={styles.ringCard}>
                  <ProgressRing
                    size={150}
                    strokeWidth={12}
                    progress={calorieGoal > 0 ? caloriesConsumed / calorieGoal : 0}
                    value={String(caloriesConsumed)}
                    label={`/ ${calorieGoal} cal`}
                  />
                </GlassCard>
              </Animated.View>

              {/* Today Stats */}
              <Animated.View entering={FadeIn.delay(250).duration(500)}>
                <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.statsRow}>
                  <StatCard icon="nutrition" label="Protein" value={`${findVal('Protein') || '--'}g`} color={colors.workout} />
                  <StatCard icon="walk" label="Active Min" value={String(findVal('Active Minutes') || '--')} color={colors.success} />
                  <StatCard icon="water" label="Water" value={`${findVal('Water') || '--'}`} color="#3b82f6" />
                </ScrollView>
              </Animated.View>

              {/* Streak Card */}
              <Animated.View entering={FadeIn.delay(350).duration(500)}>
                <GlassCard style={styles.streakCard}>
                  <View style={styles.streakRow}>
                    <View style={styles.streakLeft}>
                      <Ionicons name="flame" size={24} color={colors.warning} />
                      <View style={styles.streakText}>
                        <Text style={styles.streakValue}>{currentStreak} day streak</Text>
                        <Text style={styles.streakBest}>Personal best: {longestStreak}</Text>
                      </View>
                    </View>
                    <View style={styles.streakProgress}>
                      <View style={[styles.streakFill, { width: `${Math.min((currentStreak / nextMilestone) * 100, 100)}%` }]} />
                    </View>
                  </View>
                </GlassCard>
              </Animated.View>

              {/* AI Insight */}
              <Animated.View entering={FadeIn.delay(450).duration(500)}>
                <Pressable onPress={() => navigation.navigate('AICoach')}>
                  <GlassCard style={styles.aiCard}>
                    <View style={styles.aiRow}>
                      <Ionicons name="bulb-outline" size={20} color={colors.primary} />
                      <View style={styles.aiText}>
                        <Text style={styles.aiTip}>
                          Based on your recent activity, try adding a yoga session for recovery.
                        </Text>
                        <Text style={styles.aiCta}>Ask AI Coach &rarr;</Text>
                      </View>
                    </View>
                  </GlassCard>
                </Pressable>
              </Animated.View>

              {/* Section header */}
              <View style={styles.sectionHeader}>
                <Text style={styles.sectionTitle}>Recent Activity</Text>
                {recentLogs.length > 0 && (
                  <Badge label={`${recentLogs.length} items`} variant="active" />
                )}
              </View>
            </View>
          }
          ListEmptyComponent={
            <EmptyState
              icon="layers-outline"
              title="No activity yet"
              subtitle="Tap the + button below to log your first entry"
            />
          }
        />
      </SafeAreaView>
    </LinearGradient>
  );
}

export default function HomeScreen(props) {
  return (
    <ErrorBoundary>
      <HomeScreenInner {...props} />
    </ErrorBoundary>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  safe: { flex: 1 },
  loadingWrap: { flex: 1, padding: spacing.lg, paddingTop: spacing['2xl'] },
  skelGap: { marginTop: spacing.md },
  listContent: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
    paddingBottom: 120,
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: spacing.lg,
  },
  headerLeft: { flex: 1 },
  greeting: {
    fontSize: fontSize['2xl'],
    fontWeight: fontWeight.bold,
    color: colors.textPrimary,
  },
  greetingName: { color: colors.primaryBright },
  dateText: {
    fontSize: fontSize.sm,
    color: colors.textMuted,
    marginTop: spacing.xs,
  },
  bellBtn: {
    minWidth: 44,
    minHeight: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  bellDot: {
    position: 'absolute',
    top: 10,
    right: 10,
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: colors.primary,
  },
  ringCard: {
    alignItems: 'center',
    marginBottom: spacing.lg,
  },
  statsRow: {
    gap: spacing.sm,
    paddingBottom: spacing.lg,
  },
  streakCard: { marginBottom: spacing.lg },
  streakRow: { gap: 10 },
  streakLeft: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  streakText: { flex: 1 },
  streakValue: {
    color: colors.textPrimary,
    fontSize: fontSize.base,
    fontWeight: fontWeight.bold,
  },
  streakBest: {
    color: colors.textMuted,
    fontSize: fontSize.xs,
    marginTop: 2,
  },
  streakProgress: {
    height: 4,
    backgroundColor: colors.surface3,
    borderRadius: 2,
    overflow: 'hidden',
    marginTop: 8,
  },
  streakFill: {
    height: '100%',
    backgroundColor: colors.warning,
    borderRadius: 2,
  },
  aiCard: {
    borderLeftWidth: 3,
    borderLeftColor: colors.primary,
    marginBottom: spacing.lg,
  },
  aiRow: { flexDirection: 'row', gap: 12 },
  aiText: { flex: 1 },
  aiTip: {
    color: colors.textSecondary,
    fontSize: fontSize.sm,
    lineHeight: 20,
  },
  aiCta: {
    color: colors.primary,
    fontSize: fontSize.xs,
    fontWeight: fontWeight.semibold,
    marginTop: 6,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.md,
  },
  sectionTitle: {
    fontSize: fontSize.lg,
    fontWeight: fontWeight.bold,
    color: colors.textPrimary,
  },
  logRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: spacing.sm,
    paddingVertical: 4,
  },
  logDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: spacing.md,
  },
  logContent: { flex: 1 },
  logTitle: {
    fontSize: fontSize.base,
    fontWeight: fontWeight.semibold,
    color: colors.textPrimary,
  },
  logMeta: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
    marginTop: 2,
  },
  logCal: {
    fontSize: fontSize.sm,
    fontWeight: fontWeight.bold,
    marginLeft: spacing.sm,
  },
});
