import React, { useState } from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import ErrorBoundary from '../components/ErrorBoundary';
import MeasurementsTab from './progress/MeasurementsTab';
import PhotosTab from './progress/PhotosTab';
import AchievementsTab from './progress/AchievementsTab';
import { colors, spacing, fontSize, fontWeight, radii } from '../theme/colors';

const TABS = ['Measurements', 'Photos', 'Achievements'];

function ProgressScreenInner() {
  const [activeTab, setActiveTab] = useState(0);

  const handleTab = (i) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setActiveTab(i);
  };

  return (
    <LinearGradient
      colors={[colors.deep, colors.surface1, colors.dark]}
      locations={[0, 0.5, 1]}
      style={styles.container}
    >
      <SafeAreaView style={styles.safe} edges={['top']}>
        <Text style={styles.title}>Progress</Text>
        <View style={styles.tabBar}>
          {TABS.map((tab, i) => (
            <Pressable
              key={tab}
              onPress={() => handleTab(i)}
              style={[styles.tab, activeTab === i && styles.tabActive]}
              accessibilityRole="tab"
              accessibilityState={{ selected: activeTab === i }}
              accessibilityLabel={tab}
            >
              <Text style={[styles.tabText, activeTab === i && styles.tabTextActive]}>
                {tab}
              </Text>
            </Pressable>
          ))}
        </View>
        <View style={styles.content}>
          {activeTab === 0 && <MeasurementsTab />}
          {activeTab === 1 && <PhotosTab />}
          {activeTab === 2 && <AchievementsTab />}
        </View>
      </SafeAreaView>
    </LinearGradient>
  );
}

export default function ProgressScreen() {
  return (
    <ErrorBoundary>
      <ProgressScreenInner />
    </ErrorBoundary>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  safe: { flex: 1 },
  title: {
    fontSize: fontSize['2xl'],
    fontWeight: fontWeight.bold,
    color: colors.textPrimary,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
  },
  tabBar: {
    flexDirection: 'row',
    marginHorizontal: spacing.lg,
    marginTop: spacing.md,
    backgroundColor: colors.surface1,
    borderRadius: radii.md,
    padding: 3,
  },
  tab: {
    flex: 1,
    paddingVertical: 10,
    alignItems: 'center',
    borderRadius: radii.sm,
    minHeight: 44,
    justifyContent: 'center',
  },
  tabActive: {
    backgroundColor: colors.surface2,
  },
  tabText: {
    fontSize: fontSize.sm,
    fontWeight: fontWeight.medium,
    color: colors.textMuted,
  },
  tabTextActive: {
    color: colors.primary,
    fontWeight: fontWeight.semibold,
  },
  content: { flex: 1 },
});
