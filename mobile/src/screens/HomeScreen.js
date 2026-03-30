import React, { useState, useEffect, useCallback } from 'react';
import {
  StyleSheet,
  Text,
  View,
  FlatList,
  ScrollView,
  Pressable,
  RefreshControl,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import Animated, { FadeInUp, FadeInRight, FadeIn } from 'react-native-reanimated';
import { colors, gradients, spacing, radii, fontSize, fontWeight } from '../theme/colors';
import { GlassCard } from '../components/GlassCard';
import { Badge } from '../components/Badge';
import { EmptyState } from '../components/EmptyState';
import { LoadingSkeleton } from '../components/LoadingSkeleton';
import { useAuth } from '../context/AuthContext';
import apiClient from '../api/client';

function getGreeting() {
  const h = new Date().getHours();
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

const LOG_ICONS = { activity: '\u{1F3C3}', food: '\u{1F37D}', sleep: '\u{1F6CF}' };
const LOG_COLORS = {
  activity: colors.workout,
  food: colors.nutrition,
  sleep: colors.sleep,
};

export default function HomeScreen({ navigation }) {
  const { user } = useAuth();
  const [dashboardData, setDashboardData] = useState([]);
  const [recentLogs, setRecentLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const fetchData = useCallback(async () => {
    try {
      const [dashRes, recentRes] = await Promise.all([
        apiClient.get('/api/dashboard-data'),
        apiClient.get('/api/recent'),
      ]);
      setDashboardData(dashRes.data || []);
      setRecentLogs((recentRes.data || []).slice(0, 8));
    } catch (err) {
      console.log('Home fetch error:', err.message);
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

  const firstName = user?.name?.split(' ')[0] || 'Athlete';

  const statChips = dashboardData.slice(0, 3).map((card, i) => ({
    key: String(i),
    label: card.label,
    value: card.value,
  }));

  const handleFabPress = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    navigation.navigate('LogActivity');
  };

  const renderLogItem = ({ item, index }) => {
    const color = LOG_COLORS[item.type] || colors.primary;
    const title =
      item.type === 'activity'
        ? item.activity
        : item.type === 'food'
        ? item.name
        : `${item.hours}h sleep`;
    const meta =
      item.type === 'activity'
        ? `${item.duration_min} min \u00B7 ${item.calories} cal`
        : item.type === 'food'
        ? `${item.calories} cal \u00B7 ${item.protein}g protein`
        : `${item.quality} quality`;

    return (
      <Animated.View entering={FadeInRight.delay(index * 60).duration(400)}>
        <View style={[styles.logRow, { borderLeftColor: color }]}>
          <View style={[styles.logDot, { backgroundColor: color }]} />
          <View style={styles.logContent}>
            <Text style={styles.logTitle} numberOfLines={1}>
              {title}
            </Text>
            <Text style={styles.logMeta}>{meta}</Text>
          </View>
          {item.type !== 'sleep' && (
            <Text
              style={[
                styles.logCal,
                { color: item.type === 'food' ? colors.nutrition : colors.workout },
              ]}
            >
              {item.type === 'food' ? '+' : '-'}
              {item.calories}
            </Text>
          )}
        </View>
      </Animated.View>
    );
  };

  if (loading) {
    return (
      <LinearGradient
        colors={[colors.deep, colors.surface1, colors.dark]}
        locations={[0, 0.5, 1]}
        style={styles.container}
      >
        <SafeAreaView style={styles.safe} edges={['top']}>
          <View style={styles.loadingWrap}>
            <LoadingSkeleton variant="stat" count={3} />
          </View>
        </SafeAreaView>
      </LinearGradient>
    );
  }

  return (
    <LinearGradient
      colors={[colors.deep, colors.surface1, colors.dark]}
      locations={[0, 0.5, 1]}
      style={styles.container}
    >
      <SafeAreaView style={styles.safe} edges={['top']}>
        <FlatList
          data={recentLogs}
          keyExtractor={(_, i) => String(i)}
          renderItem={renderLogItem}
          contentContainerStyle={styles.listContent}
          showsVerticalScrollIndicator={false}
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={onRefresh}
              tintColor={colors.primary}
            />
          }
          ListHeaderComponent={
            <View>
              {/* Greeting */}
              <Animated.View
                entering={FadeInUp.delay(100).duration(600)}
                style={styles.greetingSection}
              >
                <Text style={styles.greeting}>
                  {getGreeting()},{' '}
                  <Text style={styles.greetingName}>{firstName}</Text>
                </Text>
                <Text style={styles.dateText}>
                  {new Date().toLocaleDateString('en-US', {
                    weekday: 'long',
                    month: 'long',
                    day: 'numeric',
                  })}
                </Text>
              </Animated.View>

              {/* Stat Chips */}
              {statChips.length > 0 && (
                <Animated.View entering={FadeIn.delay(250).duration(500)}>
                  <ScrollView
                    horizontal
                    showsHorizontalScrollIndicator={false}
                    contentContainerStyle={styles.chipsRow}
                  >
                    {statChips.map((chip) => (
                      <GlassCard key={chip.key} style={styles.chipCard}>
                        <Text style={styles.chipValue}>{chip.value}</Text>
                        <Text style={styles.chipLabel}>{chip.label}</Text>
                      </GlassCard>
                    ))}
                  </ScrollView>
                </Animated.View>
              )}

              {/* Section header */}
              <View style={styles.sectionHeader}>
                <Text style={styles.sectionTitle}>Recent Activity</Text>
                {recentLogs.length > 0 && (
                  <Badge variant="intensity">{recentLogs.length} items</Badge>
                )}
              </View>
            </View>
          }
          ListEmptyComponent={
            <EmptyState
              title="No activity yet"
              message="Tap the + button to log your first entry"
            />
          }
        />

        {/* FAB */}
        <Animated.View entering={FadeIn.delay(600).duration(400)}>
          <Pressable
            onPress={handleFabPress}
            style={({ pressed }) => [
              styles.fab,
              pressed && styles.fabPressed,
            ]}
          >
            <LinearGradient
              colors={gradients.primary}
              style={styles.fabGradient}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
            >
              <Text style={styles.fabIcon}>+</Text>
            </LinearGradient>
          </Pressable>
        </Animated.View>
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
  listContent: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
    paddingBottom: 100,
  },
  greetingSection: {
    marginBottom: spacing.lg,
  },
  greeting: {
    fontSize: fontSize['2xl'],
    fontWeight: fontWeight.bold,
    color: colors.textPrimary,
  },
  greetingName: {
    color: colors.primaryBright,
  },
  dateText: {
    fontSize: fontSize.sm,
    color: colors.textMuted,
    marginTop: spacing.xs,
  },
  chipsRow: {
    paddingBottom: spacing.lg,
    gap: spacing.sm,
  },
  chipCard: {
    width: 140,
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.md,
  },
  chipValue: {
    fontSize: fontSize.xl,
    fontWeight: fontWeight.bold,
    color: colors.textPrimary,
    marginBottom: 2,
  },
  chipLabel: {
    fontSize: fontSize.xs,
    color: colors.textSecondary,
    textTransform: 'uppercase',
    letterSpacing: 1,
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
    backgroundColor: colors.glassBg,
    borderRadius: radii.md,
    borderLeftWidth: 3,
    padding: spacing.md,
    marginBottom: spacing.sm,
  },
  logDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: spacing.md,
  },
  logContent: {
    flex: 1,
  },
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
  fab: {
    position: 'absolute',
    bottom: spacing.lg,
    right: spacing.lg,
    width: 60,
    height: 60,
    borderRadius: 30,
    overflow: 'hidden',
    shadowColor: colors.primary,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.4,
    shadowRadius: 16,
    elevation: 10,
  },
  fabPressed: {
    opacity: 0.85,
    transform: [{ scale: 0.93 }],
  },
  fabGradient: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  fabIcon: {
    fontSize: 28,
    fontWeight: fontWeight.light,
    color: '#fff',
    marginTop: -2,
  },
});
