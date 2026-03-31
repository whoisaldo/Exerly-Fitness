import React, { useState } from 'react';
import {
  View,
  Text,
  FlatList,
  TextInput,
  Modal,
  Pressable,
  Alert,
  StyleSheet,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import Animated, { FadeInUp } from 'react-native-reanimated';
import GlassCard from '../../components/GlassCard';
import ActionButton from '../../components/ActionButton';
import EmptyState from '../../components/EmptyState';
import Badge from '../../components/Badge';
import { useSocial } from '../../context/SocialContext';
import { colors, spacing, fontSize, fontWeight, radii } from '../../theme/colors';

const TYPES = ['Streak', 'Calories', 'Activity Count'];
const DURATIONS = [7, 14, 30];

export default function ChallengesTab() {
  const { challenges, loading, createChallenge, refresh } = useSocial();
  const [showCreate, setShowCreate] = useState(false);
  const [name, setName] = useState('');
  const [type, setType] = useState('Streak');
  const [duration, setDuration] = useState(7);
  const [creating, setCreating] = useState(false);

  const handleCreate = async () => {
    if (!name.trim()) {
      Alert.alert('Error', 'Please enter a challenge name');
      return;
    }
    setCreating(true);
    try {
      await createChallenge({ name, type, duration, friendIds: [] });
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      setShowCreate(false);
      setName('');
      refresh();
    } catch (err) {
      Alert.alert('Error', err.message || 'Failed to create challenge');
    } finally {
      setCreating(false);
    }
  };

  const renderChallenge = ({ item, index }) => (
    <Animated.View entering={FadeInUp.delay(index * 50).duration(300)}>
      <GlassCard style={styles.card}>
        <View style={styles.cardHeader}>
          <Text style={styles.cardTitle}>{item.name}</Text>
          <Badge label={item.type ?? 'Streak'} variant="active" />
        </View>
        <View style={styles.cardMeta}>
          <View style={styles.metaItem}>
            <Ionicons name="people" size={14} color={colors.textMuted} />
            <Text style={styles.metaText}>{item.participants?.length ?? 0}</Text>
          </View>
          <View style={styles.metaItem}>
            <Ionicons name="calendar" size={14} color={colors.textMuted} />
            <Text style={styles.metaText}>{item.duration ?? 7}d</Text>
          </View>
        </View>
        <View style={styles.progressBar}>
          <View style={[styles.progressFill, { width: '35%' }]} />
        </View>
      </GlassCard>
    </Animated.View>
  );

  return (
    <View style={styles.container}>
      <FlatList
        data={challenges}
        keyExtractor={(item, i) => item._id ?? String(i)}
        renderItem={renderChallenge}
        contentContainerStyle={styles.list}
        ListHeaderComponent={
          <ActionButton
            title="Create Challenge"
            onPress={() => setShowCreate(true)}
            variant="secondary"
            style={styles.createBtn}
          />
        }
        ListEmptyComponent={
          <EmptyState
            icon="flag-outline"
            title="No active challenges"
            subtitle="Create a challenge and invite friends"
          />
        }
      />

      <Modal visible={showCreate} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <View style={styles.modal}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Create Challenge</Text>
              <Pressable
                onPress={() => setShowCreate(false)}
                style={styles.closeBtn}
                accessibilityLabel="Close"
              >
                <Ionicons name="close" size={24} color={colors.textSecondary} />
              </Pressable>
            </View>

            <Text style={styles.label}>Name</Text>
            <TextInput
              style={styles.input}
              placeholder="Challenge name"
              placeholderTextColor={colors.textMuted}
              value={name}
              onChangeText={setName}
            />

            <Text style={styles.label}>Type</Text>
            <View style={styles.pillRow}>
              {TYPES.map((t) => (
                <Pressable
                  key={t}
                  onPress={() => setType(t)}
                  style={[styles.pill, type === t && styles.pillActive]}
                >
                  <Text style={[styles.pillText, type === t && styles.pillTextActive]}>
                    {t}
                  </Text>
                </Pressable>
              ))}
            </View>

            <Text style={styles.label}>Duration</Text>
            <View style={styles.pillRow}>
              {DURATIONS.map((d) => (
                <Pressable
                  key={d}
                  onPress={() => setDuration(d)}
                  style={[styles.pill, duration === d && styles.pillActive]}
                >
                  <Text style={[styles.pillText, duration === d && styles.pillTextActive]}>
                    {d} days
                  </Text>
                </Pressable>
              ))}
            </View>

            <ActionButton
              title="Launch Challenge"
              onPress={handleCreate}
              loading={creating}
              fullWidth
              style={styles.launchBtn}
            />
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  list: { padding: spacing.lg, paddingBottom: 120 },
  createBtn: { marginBottom: spacing.md },
  card: { marginBottom: spacing.sm },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  cardTitle: {
    color: colors.textPrimary,
    fontSize: fontSize.base,
    fontWeight: fontWeight.semibold,
    flex: 1,
    marginRight: 8,
  },
  cardMeta: { flexDirection: 'row', gap: 16, marginBottom: 10 },
  metaItem: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  metaText: { color: colors.textMuted, fontSize: fontSize.xs },
  progressBar: {
    height: 4,
    backgroundColor: colors.surface3,
    borderRadius: 2,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: colors.primary,
    borderRadius: 2,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.7)',
    justifyContent: 'flex-end',
  },
  modal: {
    backgroundColor: colors.surface1,
    borderTopLeftRadius: radii.xl,
    borderTopRightRadius: radii.xl,
    padding: spacing.lg,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.lg,
  },
  modalTitle: {
    color: colors.textPrimary,
    fontSize: fontSize.lg,
    fontWeight: fontWeight.bold,
  },
  closeBtn: { minWidth: 44, minHeight: 44, alignItems: 'center', justifyContent: 'center' },
  label: {
    color: colors.textSecondary,
    fontSize: fontSize.xs,
    textTransform: 'uppercase',
    letterSpacing: 0.8,
    marginBottom: 6,
    marginTop: spacing.md,
  },
  input: {
    backgroundColor: 'rgba(255,255,255,0.04)',
    borderWidth: 1,
    borderColor: colors.borderSubtle,
    borderRadius: radii.md,
    padding: 12,
    color: colors.textPrimary,
    fontSize: fontSize.base,
    minHeight: 44,
  },
  pillRow: { flexDirection: 'row', gap: 8 },
  pill: {
    flex: 1,
    backgroundColor: 'rgba(255,255,255,0.04)',
    borderWidth: 1,
    borderColor: colors.borderSubtle,
    borderRadius: radii.full,
    paddingVertical: 10,
    alignItems: 'center',
    minHeight: 44,
    justifyContent: 'center',
  },
  pillActive: {
    backgroundColor: `${colors.primary}22`,
    borderColor: colors.primary,
  },
  pillText: { color: colors.textMuted, fontSize: fontSize.xs, fontWeight: fontWeight.semibold },
  pillTextActive: { color: colors.primary },
  launchBtn: { marginTop: spacing.xl },
});
