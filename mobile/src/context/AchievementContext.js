import React, { createContext, useContext, useState, useCallback, useMemo } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Animated, {
  FadeIn,
  FadeOut,
  ZoomIn,
} from 'react-native-reanimated';
import * as Haptics from 'expo-haptics';
import { Ionicons } from '@expo/vector-icons';
import useAchievements from '../hooks/useAchievements';
import { colors, fontSize, fontWeight, radii } from '../theme/colors';

const AchievementContext = createContext(null);

export function AchievementProvider({ children }) {
  const achievementData = useAchievements();
  const [overlay, setOverlay] = useState(null);

  const checkAndNotify = useCallback(
    async (userData) => {
      const fresh = await achievementData.checkAchievements(userData);
      if (fresh.length > 0) {
        const a = achievementData.achievements.find((x) => x.id === fresh[0]);
        if (a) {
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
          setOverlay(a);
          setTimeout(() => setOverlay(null), 3500);
        }
      }
      return fresh;
    },
    [achievementData.checkAchievements, achievementData.achievements],
  );

  const value = useMemo(
    () => ({
      achievements: achievementData.achievements,
      unlocked: achievementData.unlocked,
      newUnlocks: achievementData.newUnlocks,
      getProgress: achievementData.getProgress,
      checkAchievements: checkAndNotify,
    }),
    [achievementData, checkAndNotify],
  );

  return (
    <AchievementContext.Provider value={value}>
      {children}
      {overlay && <UnlockOverlay achievement={overlay} />}
    </AchievementContext.Provider>
  );
}

function UnlockOverlay({ achievement }) {
  return (
    <Animated.View
      entering={FadeIn.duration(300)}
      exiting={FadeOut.duration(300)}
      style={styles.overlay}
      pointerEvents="none"
    >
      <Animated.View entering={ZoomIn.springify()} style={styles.card}>
        <Ionicons name="trophy" size={36} color="#fbbf24" />
        <Text style={styles.title}>Achievement Unlocked!</Text>
        <Text style={styles.name}>{achievement.title}</Text>
        <Text style={styles.desc}>{achievement.desc}</Text>
      </Animated.View>
    </Animated.View>
  );
}

export function useAchievementContext() {
  const ctx = useContext(AchievementContext);
  if (!ctx) throw new Error('useAchievementContext must be inside AchievementProvider');
  return ctx;
}

const styles = StyleSheet.create({
  overlay: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0,0,0,0.6)',
    zIndex: 999,
  },
  card: {
    backgroundColor: colors.surface1,
    borderRadius: radii.xl,
    padding: 32,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: 'rgba(251,191,36,0.4)',
    shadowColor: '#fbbf24',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.3,
    shadowRadius: 24,
    elevation: 10,
    maxWidth: 280,
  },
  title: {
    color: '#fbbf24',
    fontSize: fontSize.sm,
    fontWeight: fontWeight.semibold,
    marginTop: 12,
    textTransform: 'uppercase',
    letterSpacing: 1.5,
  },
  name: {
    color: colors.textPrimary,
    fontSize: fontSize.xl,
    fontWeight: fontWeight.bold,
    marginTop: 8,
    textAlign: 'center',
  },
  desc: {
    color: colors.textSecondary,
    fontSize: fontSize.sm,
    marginTop: 4,
    textAlign: 'center',
  },
});
