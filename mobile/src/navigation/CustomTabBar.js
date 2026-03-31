import React, { useCallback } from 'react';
import { View, Pressable, Text, StyleSheet, Platform } from 'react-native';
import { BlurView } from 'expo-blur';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
  interpolate,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { colors, radii } from '../theme/colors';

const TAB_ITEMS = [
  { name: 'Home', icon: 'home-outline', iconActive: 'home' },
  { name: 'Progress', icon: 'trending-up-outline', iconActive: 'trending-up' },
  { name: 'Track', icon: 'add', isFab: true },
  { name: 'Social', icon: 'people-outline', iconActive: 'people' },
  { name: 'Profile', icon: 'person-outline', iconActive: 'person' },
];

const FAB_ACTIONS = [
  { key: 'LogActivity', icon: 'fitness-outline', label: 'Activity' },
  { key: 'LogFood', icon: 'restaurant-outline', label: 'Food' },
  { key: 'LogSleep', icon: 'moon-outline', label: 'Sleep' },
];

function FabMenu({ expanded, onSelect }) {
  return FAB_ACTIONS.map((action, i) => {
    const angle = -Math.PI / 2 + ((i - 1) * Math.PI) / 4;
    const dist = 80;
    const tx = Math.cos(angle) * dist;
    const ty = Math.sin(angle) * dist;

    return (
      <FabMenuItem
        key={action.key}
        action={action}
        expanded={expanded}
        tx={tx}
        ty={ty}
        delay={i * 40}
        onSelect={onSelect}
      />
    );
  });
}

function FabMenuItem({ action, expanded, tx, ty, delay, onSelect }) {
  const progress = useSharedValue(0);

  React.useEffect(() => {
    progress.value = withSpring(expanded ? 1 : 0, {
      damping: 14,
      stiffness: 160,
      mass: 0.8,
    });
  }, [expanded, progress]);

  const animStyle = useAnimatedStyle(() => ({
    opacity: progress.value,
    transform: [
      { translateX: interpolate(progress.value, [0, 1], [0, tx]) },
      { translateY: interpolate(progress.value, [0, 1], [0, ty]) },
      { scale: interpolate(progress.value, [0, 1], [0.4, 1]) },
    ],
  }));

  return (
    <Animated.View style={[styles.fabAction, animStyle]}>
      <Pressable
        onPress={() => onSelect(action.key)}
        style={styles.fabActionBtn}
        accessibilityRole="button"
        accessibilityLabel={action.label}
      >
        <Ionicons name={action.icon} size={22} color="#fff" />
      </Pressable>
      <Text style={styles.fabLabel}>{action.label}</Text>
    </Animated.View>
  );
}

export default function CustomTabBar({ state, navigation }) {
  const insets = useSafeAreaInsets();
  const fabOpen = useSharedValue(0);
  const [expanded, setExpanded] = React.useState(false);

  const toggleFab = useCallback(() => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    const next = !expanded;
    setExpanded(next);
    fabOpen.value = withSpring(next ? 1 : 0, { damping: 14, stiffness: 160 });
  }, [expanded, fabOpen]);

  const fabRotate = useAnimatedStyle(() => ({
    transform: [{ rotate: `${interpolate(fabOpen.value, [0, 1], [0, 45])}deg` }],
  }));

  const handleFabSelect = useCallback(
    (screen) => {
      setExpanded(false);
      fabOpen.value = withTiming(0, { duration: 200 });
      navigation.navigate(screen);
    },
    [navigation, fabOpen],
  );

  const handleTabPress = useCallback(
    (routeName, index) => {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      if (expanded) {
        setExpanded(false);
        fabOpen.value = withTiming(0, { duration: 200 });
      }
      const event = navigation.emit({ type: 'tabPress', target: state.routes[index]?.key });
      if (!event.defaultPrevented) {
        navigation.navigate(routeName);
      }
    },
    [navigation, state.routes, expanded, fabOpen],
  );

  const pb = Math.max(insets.bottom, 8);

  return (
    <View style={[styles.wrapper, { paddingBottom: pb }]}>
      <BlurView intensity={80} tint="dark" style={StyleSheet.absoluteFill} />
      <View style={styles.row}>
        {TAB_ITEMS.map((tab, i) => {
          if (tab.isFab) {
            return (
              <View key="fab" style={styles.fabContainer}>
                <FabMenu expanded={expanded} onSelect={handleFabSelect} />
                <Pressable
                  onPress={toggleFab}
                  style={styles.fab}
                  accessibilityRole="button"
                  accessibilityLabel="Log new entry"
                >
                  <Animated.View style={fabRotate}>
                    <Ionicons name="add" size={28} color="#fff" />
                  </Animated.View>
                </Pressable>
              </View>
            );
          }

          const tabIndex = i > 2 ? i - 1 : i;
          const focused = state.index === tabIndex;

          return (
            <Pressable
              key={tab.name}
              onPress={() => handleTabPress(tab.name, tabIndex)}
              style={styles.tab}
              accessibilityRole="tab"
              accessibilityState={{ selected: focused }}
              accessibilityLabel={tab.name}
            >
              {focused && <View style={styles.indicator} />}
              <Ionicons
                name={focused ? tab.iconActive : tab.icon}
                size={24}
                color={focused ? colors.primary : colors.textMuted}
              />
              <Text style={[styles.tabLabel, focused && styles.tabLabelActive]}>
                {tab.name}
              </Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    borderTopWidth: 1,
    borderTopColor: colors.glassBorder,
    backgroundColor: 'rgba(8,8,16,0.75)',
  },
  row: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'space-around',
    paddingTop: 8,
  },
  tab: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 6,
    minWidth: 56,
    minHeight: 44,
  },
  indicator: {
    width: 20,
    height: 3,
    borderRadius: 2,
    backgroundColor: colors.primary,
    marginBottom: 4,
  },
  tabLabel: {
    fontSize: 10,
    color: colors.textMuted,
    marginTop: 2,
  },
  tabLabelActive: {
    color: colors.primary,
  },
  fabContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: -24,
  },
  fab: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: colors.primary,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
    elevation: 8,
    zIndex: 10,
  },
  fabAction: {
    position: 'absolute',
    alignItems: 'center',
    zIndex: 20,
  },
  fabActionBtn: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: colors.secondary,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: colors.secondary,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 6,
  },
  fabLabel: {
    color: colors.textSecondary,
    fontSize: 10,
    marginTop: 4,
  },
});
