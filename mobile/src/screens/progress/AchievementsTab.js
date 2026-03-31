import React from 'react';
import { View, Text, FlatList, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import Animated, { FadeInUp } from 'react-native-reanimated';
import GlassCard from '../../components/GlassCard';
import { useAchievementContext } from '../../context/AchievementContext';
import { colors, spacing, fontSize, fontWeight, radii } from '../../theme/colors';

export default function AchievementsTab() {
  const { achievements, unlocked, getProgress } = useAchievementContext();

  const renderItem = ({ item, index }) => {
    const isUnlocked = unlocked.includes(item.id);
    const progress = getProgress(item.id, { unlockedCount: unlocked.length });

    return (
      <Animated.View entering={FadeInUp.delay(index * 40).duration(400)}>
        <GlassCard
          style={[styles.card, isUnlocked && styles.cardUnlocked]}
        >
          <View style={styles.row}>
            <View style={[styles.iconWrap, isUnlocked && styles.iconUnlocked]}>
              <Ionicons
                name={item.icon}
                size={24}
                color={isUnlocked ? '#fbbf24' : colors.textMuted}
              />
            </View>
            <View style={styles.info}>
              <Text style={[styles.title, !isUnlocked && styles.titleLocked]}>
                {item.title}
              </Text>
              <Text style={styles.desc}>{item.desc}</Text>
              {!isUnlocked && (
                <View style={styles.progressBar}>
                  <View
                    style={[
                      styles.progressFill,
                      { width: `${progress.percent * 100}%` },
                    ]}
                  />
                </View>
              )}
              {!isUnlocked && (
                <Text style={styles.progressText}>
                  {progress.current} / {progress.target}
                </Text>
              )}
            </View>
          </View>
        </GlassCard>
      </Animated.View>
    );
  };

  return (
    <FlatList
      data={achievements}
      keyExtractor={(item) => item.id}
      renderItem={renderItem}
      contentContainerStyle={styles.list}
      showsVerticalScrollIndicator={false}
    />
  );
}

const styles = StyleSheet.create({
  list: { padding: spacing.lg, paddingBottom: 120 },
  card: { marginBottom: spacing.sm },
  cardUnlocked: {
    borderColor: 'rgba(251,191,36,0.4)',
  },
  row: { flexDirection: 'row', alignItems: 'center' },
  iconWrap: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: colors.surface2,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: spacing.md,
  },
  iconUnlocked: {
    backgroundColor: 'rgba(251,191,36,0.15)',
    shadowColor: '#fbbf24',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 4,
  },
  info: { flex: 1 },
  title: {
    color: colors.textPrimary,
    fontSize: fontSize.base,
    fontWeight: fontWeight.semibold,
  },
  titleLocked: { color: colors.textSecondary },
  desc: {
    color: colors.textMuted,
    fontSize: fontSize.xs,
    marginTop: 2,
  },
  progressBar: {
    height: 4,
    backgroundColor: colors.surface3,
    borderRadius: 2,
    marginTop: 8,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: colors.primary,
    borderRadius: 2,
  },
  progressText: {
    color: colors.textMuted,
    fontSize: 10,
    marginTop: 2,
  },
});
