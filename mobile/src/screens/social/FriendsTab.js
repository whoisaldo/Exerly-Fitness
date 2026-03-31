import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  FlatList,
  TextInput,
  Pressable,
  Alert,
  StyleSheet,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import Animated, { FadeInRight } from 'react-native-reanimated';
import GlassCard from '../../components/GlassCard';
import ActionButton from '../../components/ActionButton';
import EmptyState from '../../components/EmptyState';
import LoadingSkeleton from '../../components/LoadingSkeleton';
import { useSocial } from '../../context/SocialContext';
import { colors, spacing, fontSize, fontWeight, radii } from '../../theme/colors';

export default function FriendsTab() {
  const { friends, loading, searchUser, addFriend, refresh } = useSocial();
  const [query, setQuery] = useState('');
  const [adding, setAdding] = useState(false);

  const handleSearch = useCallback(async () => {
    if (!query.trim()) return;
    setAdding(true);
    try {
      await addFriend(query.trim());
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      setQuery('');
      refresh();
    } catch (err) {
      Alert.alert('Error', err.message || 'Could not add friend');
    } finally {
      setAdding(false);
    }
  }, [query, addFriend, refresh]);

  const renderFriend = ({ item, index }) => {
    const initials = (item.name ?? 'U')
      .split(' ')
      .map((w) => w[0])
      .join('')
      .slice(0, 2)
      .toUpperCase();

    return (
      <Animated.View entering={FadeInRight.delay(index * 50).duration(300)}>
        <GlassCard style={styles.friendRow}>
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>{initials}</Text>
          </View>
          <View style={styles.friendInfo}>
            <Text style={styles.friendName}>{item.name}</Text>
            {item.streak > 0 && (
              <Text style={styles.friendStreak}>{item.streak} day streak</Text>
            )}
          </View>
          <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
        </GlassCard>
      </Animated.View>
    );
  };

  if (loading) return <LoadingSkeleton variant="row" count={5} style={styles.loader} />;

  return (
    <View style={styles.container}>
      <View style={styles.searchRow}>
        <View style={styles.searchWrap}>
          <Ionicons name="search" size={18} color={colors.textMuted} />
          <TextInput
            style={styles.searchInput}
            placeholder="Add friend by email..."
            placeholderTextColor={colors.textMuted}
            value={query}
            onChangeText={setQuery}
            onSubmitEditing={handleSearch}
            autoCapitalize="none"
            keyboardType="email-address"
            returnKeyType="send"
          />
        </View>
        <ActionButton
          title="Add"
          onPress={handleSearch}
          loading={adding}
          variant="secondary"
          style={styles.addBtn}
        />
      </View>

      <FlatList
        data={friends}
        keyExtractor={(item, i) => item._id ?? String(i)}
        renderItem={renderFriend}
        contentContainerStyle={styles.list}
        ListEmptyComponent={
          <EmptyState
            icon="people-outline"
            title="No friends yet"
            subtitle="Invite someone to join Exerly!"
          />
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  loader: { padding: spacing.lg },
  searchRow: {
    flexDirection: 'row',
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
    gap: spacing.sm,
  },
  searchWrap: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.04)',
    borderWidth: 1,
    borderColor: colors.borderSubtle,
    borderRadius: radii.md,
    paddingHorizontal: 12,
    minHeight: 44,
  },
  searchInput: {
    flex: 1,
    color: colors.textPrimary,
    fontSize: fontSize.sm,
    marginLeft: 8,
    paddingVertical: 10,
  },
  addBtn: { height: 44 },
  list: { padding: spacing.lg, paddingBottom: 120 },
  friendRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: spacing.sm,
  },
  avatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: `${colors.primary}33`,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: spacing.md,
  },
  avatarText: {
    color: colors.primary,
    fontSize: fontSize.sm,
    fontWeight: fontWeight.bold,
  },
  friendInfo: { flex: 1 },
  friendName: {
    color: colors.textPrimary,
    fontSize: fontSize.base,
    fontWeight: fontWeight.semibold,
  },
  friendStreak: {
    color: colors.warning,
    fontSize: fontSize.xs,
    marginTop: 2,
  },
});
