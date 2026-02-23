import React, { useState, useEffect, useCallback } from 'react';
import {
  StyleSheet,
  Text,
  View,
  TouchableOpacity,
  ScrollView,
  RefreshControl,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { colors, spacing, borderRadius, fontSize, fontWeight } from '../theme/colors';
import { useAuth } from '../context/AuthContext';
import apiClient from '../api/client';

export default function DashboardScreen({ navigation }) {
  const { user, logout } = useAuth();
  const [dashboardData, setDashboardData] = useState([]);
  const [recentLogs, setRecentLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [resetting, setResetting] = useState(false);

  const fetchData = useCallback(async () => {
    try {
      const [dashboardRes, recentRes] = await Promise.all([
        apiClient.get('/api/dashboard-data'),
        apiClient.get('/api/recent'),
      ]);
      setDashboardData(dashboardRes.data || []);
      setRecentLogs((recentRes.data || []).slice(0, 8));
    } catch (error) {
      console.log('Error fetching dashboard data:', error.message);
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
    Alert.alert(
      'Logout',
      'Are you sure you want to logout?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Logout', style: 'destructive', onPress: () => logout() }
      ]
    );
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
          }
        }
      ]
    );
  };

  const getCardIcon = (label) => {
    const icons = {
      'Total Workouts': '💪',
      'Calories Burned': '🔥',
      'Calories Consumed': '🍎',
      'Sleep (hrs)': '😴',
      'Maintenance (est.)': '⚖️',
      'Net vs. Maint.': '📊',
      'Admin': '⚙️',
    };
    return icons[label] || '📈';
  };

  const getCardStyle = (label) => {
    const styleMap = {
      'Total Workouts': { bg: 'rgba(0, 184, 148, 0.15)', border: colors.workout },
      'Calories Burned': { bg: 'rgba(225, 112, 85, 0.15)', border: colors.burned },
      'Calories Consumed': { bg: 'rgba(253, 203, 110, 0.15)', border: colors.consumed },
      'Sleep (hrs)': { bg: 'rgba(108, 92, 231, 0.15)', border: colors.sleep },
    };
    return styleMap[label] || { bg: 'rgba(139, 92, 246, 0.1)', border: colors.primary };
  };

  const getLogIcon = (type) => {
    const icons = { 'activity': '🏃', 'food': '🍽️', 'sleep': '🛏️' };
    return icons[type] || '📝';
  };

  const getLogBorderColor = (type) => {
    const colorMap = { 'activity': colors.burned, 'food': colors.workout, 'sleep': colors.sleep };
    return colorMap[type] || colors.primary;
  };

  if (loading) {
    return (
      <LinearGradient colors={colors.gradientBackground} locations={[0, 0.5, 1]} style={styles.loadingContainer}>
        <ActivityIndicator size="large" color={colors.primary} />
        <Text style={styles.loadingText}>Loading your dashboard...</Text>
      </LinearGradient>
    );
  }

  return (
    <LinearGradient colors={colors.gradientBackground} locations={[0, 0.5, 1]} style={styles.container}>
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={colors.primary} />
        }
      >
        {/* Header */}
        <View style={styles.header}>
          <View style={styles.headerTop}>
            <View style={styles.headerLeft}>
              <Text style={styles.greeting}>Welcome back,</Text>
              <Text style={styles.userName}>{user?.name || 'Athlete'}</Text>
            </View>
            <TouchableOpacity style={styles.logoutButton} onPress={handleLogout}>
              <Text style={styles.logoutText}>Logout</Text>
            </TouchableOpacity>
          </View>
          <Text style={styles.dateText}>{new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })}</Text>
        </View>

        {/* Stats Cards */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Today's Overview</Text>
          <View style={styles.statsGrid}>
            {dashboardData.length > 0 ? dashboardData.map((card, index) => {
              const style = getCardStyle(card.label);
              return (
                <View key={index} style={[styles.statCard, { backgroundColor: style.bg, borderLeftColor: style.border }]}>
                  <View style={styles.cardIconContainer}>
                    <Text style={styles.cardIcon}>{getCardIcon(card.label)}</Text>
                  </View>
                  <View style={styles.cardContent}>
                    <Text style={styles.cardLabel}>{card.label}</Text>
                    <Text style={styles.cardValue}>{card.value}</Text>
                  </View>
                </View>
              );
            }) : (
              <View style={styles.emptyStats}>
                <Text style={styles.emptyText}>No data yet today</Text>
                <Text style={styles.emptySubtext}>Start logging to see your stats!</Text>
              </View>
            )}
          </View>
        </View>

        {/* Quick Actions */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Quick Actions</Text>
          <View style={styles.actionsGrid}>
            <TouchableOpacity style={styles.actionCard} onPress={() => navigation.navigate('LogActivity')} activeOpacity={0.8}>
              <LinearGradient colors={colors.gradientWorkout} style={styles.actionGradient}>
                <Text style={styles.actionIcon}>🏃</Text>
                <Text style={styles.actionText}>Log Activity</Text>
              </LinearGradient>
            </TouchableOpacity>

            <TouchableOpacity style={styles.actionCard} onPress={() => navigation.navigate('LogFood')} activeOpacity={0.8}>
              <LinearGradient colors={[colors.consumed, '#e17055']} style={styles.actionGradient}>
                <Text style={styles.actionIcon}>🍎</Text>
                <Text style={styles.actionText}>Log Food</Text>
              </LinearGradient>
            </TouchableOpacity>

            <TouchableOpacity style={styles.actionCard} onPress={() => navigation.navigate('LogSleep')} activeOpacity={0.8}>
              <LinearGradient colors={colors.gradientSleep} style={styles.actionGradient}>
                <Text style={styles.actionIcon}>😴</Text>
                <Text style={styles.actionText}>Log Sleep</Text>
              </LinearGradient>
            </TouchableOpacity>

            <TouchableOpacity style={styles.actionCard} onPress={() => Alert.alert('AI Coach', 'AI Coach coming soon!')} activeOpacity={0.8}>
              <LinearGradient colors={colors.gradientPrimary} style={styles.actionGradient}>
                <Text style={styles.actionIcon}>🤖</Text>
                <Text style={styles.actionText}>AI Coach</Text>
              </LinearGradient>
            </TouchableOpacity>
          </View>
        </View>

        {/* Recent Activity */}
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>Recent Activity</Text>
            {recentLogs.length > 0 && (
              <View style={styles.logCount}>
                <Text style={styles.logCountText}>{recentLogs.length} items</Text>
              </View>
            )}
          </View>
          <View style={styles.recentContainer}>
            {recentLogs.length === 0 ? (
              <View style={styles.emptyState}>
                <Text style={styles.emptyIcon}>📝</Text>
                <Text style={styles.emptyText}>No activity logged today</Text>
                <Text style={styles.emptySubtext}>Tap a quick action above to get started!</Text>
              </View>
            ) : (
              recentLogs.map((log, index) => (
                <View key={index} style={[styles.logEntry, { borderLeftColor: getLogBorderColor(log.type) }]}>
                  <View style={styles.logIcon}>
                    <Text style={styles.logIconText}>{getLogIcon(log.type)}</Text>
                  </View>
                  <View style={styles.logContent}>
                    <Text style={styles.logTitle}>
                      {log.type === 'activity' ? log.activity : 
                       log.type === 'food' ? log.name : 
                       `${log.hours}h sleep - ${log.quality}`}
                    </Text>
                    <Text style={styles.logMeta}>
                      {log.type === 'activity' ? `${log.duration_min} min • ${log.calories} cal burned` :
                       log.type === 'food' ? `${log.calories} cal • ${log.protein}g protein` :
                       log.quality + ' quality'}
                    </Text>
                  </View>
                  {log.type !== 'sleep' && (
                    <Text style={[styles.logCalories, log.type === 'food' ? styles.caloriesPositive : styles.caloriesNegative]}>
                      {log.type === 'food' ? '+' : '-'}{log.calories}
                    </Text>
                  )}
                </View>
              ))
            )}
          </View>
        </View>

        {/* Reset Today Button */}
        <TouchableOpacity 
          style={styles.resetButton} 
          onPress={handleResetToday}
          disabled={resetting}
        >
          {resetting ? (
            <ActivityIndicator color={colors.warning} size="small" />
          ) : (
            <Text style={styles.resetButtonText}>🔄 Reset Today's Data</Text>
          )}
        </TouchableOpacity>

        {/* Footer */}
        <View style={styles.footer}>
          <Text style={styles.footerText}>Exerly Fitness v1.0.0</Text>
        </View>
      </ScrollView>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  loadingContainer: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  loadingText: { color: colors.textSecondary, marginTop: spacing.md, fontSize: fontSize.md },
  scrollContent: { padding: spacing.lg, paddingTop: 60, paddingBottom: 40 },
  
  // Header
  header: { marginBottom: spacing.lg },
  headerTop: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' },
  headerLeft: { flex: 1 },
  greeting: { fontSize: fontSize.md, color: colors.textSecondary },
  userName: { fontSize: 28, fontWeight: fontWeight.extrabold, color: colors.textPrimary },
  dateText: { fontSize: fontSize.sm, color: colors.textMuted, marginTop: spacing.xs },
  logoutButton: {
    backgroundColor: 'rgba(239, 68, 68, 0.15)',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: borderRadius.md,
    borderWidth: 1,
    borderColor: 'rgba(239, 68, 68, 0.3)',
  },
  logoutText: { color: colors.error, fontSize: fontSize.sm, fontWeight: fontWeight.semibold },

  // Sections
  section: { marginBottom: spacing.lg },
  sectionHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: spacing.md },
  sectionTitle: { fontSize: fontSize.lg, fontWeight: fontWeight.bold, color: colors.textPrimary, marginBottom: spacing.md },
  logCount: { backgroundColor: 'rgba(139, 92, 246, 0.2)', paddingHorizontal: spacing.sm, paddingVertical: 4, borderRadius: borderRadius.full },
  logCountText: { color: colors.secondary, fontSize: fontSize.xs, fontWeight: fontWeight.semibold },

  // Stats Grid
  statsGrid: { gap: spacing.sm },
  statCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    borderRadius: borderRadius.lg,
    borderLeftWidth: 4,
    gap: spacing.md,
  },
  cardIconContainer: { width: 48, height: 48, borderRadius: borderRadius.md, backgroundColor: 'rgba(255,255,255,0.1)', alignItems: 'center', justifyContent: 'center' },
  cardIcon: { fontSize: 24 },
  cardContent: { flex: 1 },
  cardLabel: { fontSize: fontSize.sm, color: colors.textMuted, marginBottom: 2 },
  cardValue: { fontSize: fontSize.xl, fontWeight: fontWeight.bold, color: colors.textPrimary },
  emptyStats: { padding: spacing.xl, alignItems: 'center' },

  // Actions Grid
  actionsGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  actionCard: { width: '48%', borderRadius: borderRadius.lg, overflow: 'hidden', shadowColor: '#000', shadowOffset: { width: 0, height: 2 }, shadowOpacity: 0.2, shadowRadius: 4, elevation: 3 },
  actionGradient: { padding: spacing.lg, alignItems: 'center', justifyContent: 'center', minHeight: 100 },
  actionIcon: { fontSize: 36, marginBottom: spacing.xs },
  actionText: { fontSize: fontSize.md, fontWeight: fontWeight.semibold, color: '#fff' },

  // Recent Logs
  recentContainer: {
    backgroundColor: 'rgba(139, 92, 246, 0.08)',
    borderRadius: borderRadius.lg,
    borderWidth: 1,
    borderColor: 'rgba(139, 92, 246, 0.15)',
    overflow: 'hidden',
  },
  emptyState: { alignItems: 'center', padding: spacing.xl },
  emptyIcon: { fontSize: 48, marginBottom: spacing.md, opacity: 0.7 },
  emptyText: { fontSize: fontSize.md, color: colors.textSecondary, fontWeight: fontWeight.semibold },
  emptySubtext: { fontSize: fontSize.sm, color: colors.textMuted, textAlign: 'center', marginTop: spacing.xs },
  logEntry: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255, 255, 255, 0.05)',
    borderLeftWidth: 3,
  },
  logIcon: { width: 44, height: 44, borderRadius: borderRadius.md, backgroundColor: 'rgba(255, 255, 255, 0.1)', alignItems: 'center', justifyContent: 'center', marginRight: spacing.md },
  logIconText: { fontSize: 22 },
  logContent: { flex: 1 },
  logTitle: { fontSize: fontSize.md, fontWeight: fontWeight.semibold, color: colors.textPrimary, marginBottom: 2 },
  logMeta: { fontSize: fontSize.sm, color: colors.textMuted },
  logCalories: { fontSize: fontSize.md, fontWeight: fontWeight.bold },
  caloriesPositive: { color: colors.consumed },
  caloriesNegative: { color: colors.burned },

  // Reset Button
  resetButton: {
    backgroundColor: 'rgba(245, 158, 11, 0.1)',
    borderWidth: 1,
    borderColor: 'rgba(245, 158, 11, 0.3)',
    borderRadius: borderRadius.md,
    padding: spacing.md,
    alignItems: 'center',
    marginTop: spacing.md,
  },
  resetButtonText: { color: colors.warning, fontSize: fontSize.sm, fontWeight: fontWeight.semibold },

  // Footer
  footer: { alignItems: 'center', marginTop: spacing.xl, paddingTop: spacing.lg },
  footerText: { fontSize: fontSize.xs, color: colors.textMuted },
});
