import React from 'react';
import {
  View,
  Text,
  FlatList,
  Pressable,
  StyleSheet,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { Ionicons } from '@expo/vector-icons';
import Animated, { FadeInRight } from 'react-native-reanimated';
import ErrorBoundary from '../components/ErrorBoundary';
import GlassCard from '../components/GlassCard';
import EmptyState from '../components/EmptyState';
import { useNotificationContext } from '../context/NotificationContext';
import {
  colors,
  spacing,
  fontSize,
  fontWeight,
  radii,
} from '../theme/colors';
import { timeAgo } from '../utils/dateHelpers';

const TYPE_CONFIG = {
  achievement: { icon: 'trophy', color: '#fbbf24' },
  challenge: { icon: 'flag', color: colors.primary },
  friend: { icon: 'person-add', color: '#3b82f6' },
  reminder: { icon: 'alarm', color: colors.warning },
  summary: { icon: 'bar-chart', color: colors.success },
};

function NotificationsInner({ navigation }) {
  const { notifications, unreadCount, markAllRead } = useNotificationContext();

  const renderItem = ({ item, index }) => {
    const config = TYPE_CONFIG[item.type] ?? TYPE_CONFIG.reminder;
    return (
      <Animated.View entering={FadeInRight.delay(index * 40).duration(300)}>
        <GlassCard style={[styles.row, !item.read && styles.rowUnread]}>
          <View style={[styles.iconCircle, { backgroundColor: `${config.color}22` }]}>
            <Ionicons name={config.icon} size={18} color={config.color} />
          </View>
          <View style={styles.content}>
            <Text style={styles.message} numberOfLines={2}>
              {item.message}
            </Text>
            <Text style={styles.time}>{timeAgo(item.timestamp)}</Text>
          </View>
          {!item.read && <View style={styles.dot} />}
        </GlassCard>
      </Animated.View>
    );
  };

  return (
    <LinearGradient
      colors={[colors.deep, colors.surface1, colors.dark]}
      locations={[0, 0.5, 1]}
      style={styles.container}
    >
      <SafeAreaView style={styles.safe} edges={['top']}>
        <View style={styles.header}>
          <Pressable
            onPress={() => navigation.goBack()}
            style={styles.backBtn}
            accessibilityLabel="Go back"
          >
            <Ionicons name="arrow-back" size={24} color={colors.textPrimary} />
          </Pressable>
          <Text style={styles.title}>Notifications</Text>
          {unreadCount > 0 && (
            <Pressable
              onPress={markAllRead}
              style={styles.markRead}
              accessibilityLabel="Mark all as read"
            >
              <Text style={styles.markReadText}>Mark all read</Text>
            </Pressable>
          )}
        </View>

        <FlatList
          data={notifications}
          keyExtractor={(_, i) => String(i)}
          renderItem={renderItem}
          contentContainerStyle={styles.list}
          ListEmptyComponent={
            <EmptyState
              icon="notifications-off-outline"
              title="You're all caught up"
              subtitle="No notifications to show"
            />
          }
        />
      </SafeAreaView>
    </LinearGradient>
  );
}

export default function NotificationsScreen(props) {
  return (
    <ErrorBoundary>
      <NotificationsInner {...props} />
    </ErrorBoundary>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  safe: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
  },
  backBtn: { minWidth: 44, minHeight: 44, justifyContent: 'center' },
  title: {
    flex: 1,
    color: colors.textPrimary,
    fontSize: fontSize.lg,
    fontWeight: fontWeight.bold,
    marginLeft: spacing.sm,
  },
  markRead: { minHeight: 44, justifyContent: 'center' },
  markReadText: {
    color: colors.primary,
    fontSize: fontSize.sm,
    fontWeight: fontWeight.medium,
  },
  list: { padding: spacing.lg, paddingBottom: 120 },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: spacing.sm,
  },
  rowUnread: {
    backgroundColor: `${colors.primary}08`,
  },
  iconCircle: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: spacing.md,
  },
  content: { flex: 1 },
  message: {
    color: colors.textPrimary,
    fontSize: fontSize.sm,
    fontWeight: fontWeight.medium,
    lineHeight: 20,
  },
  time: {
    color: colors.textMuted,
    fontSize: fontSize.xs,
    marginTop: 2,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: colors.primary,
    marginLeft: spacing.sm,
  },
});
