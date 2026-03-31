import React, { useState, useCallback, useMemo } from 'react';
import {
  View,
  Text,
  FlatList,
  Pressable,
  StyleSheet,
} from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import * as Haptics from 'expo-haptics';
import Animated, { FadeInUp } from 'react-native-reanimated';
import { colors, gradients, spacing, radii, fontSize, fontWeight } from '../../theme/colors';
import ErrorBoundary from '../../components/ErrorBoundary';
import FoodSearchBar from '../../components/library/FoodSearchBar';
import FoodCard from '../../components/library/FoodCard';
import LoadingSkeleton from '../../components/LoadingSkeleton';
import EmptyState from '../../components/EmptyState';
import ActionButton from '../../components/ActionButton';
import useFoodSearch from '../../hooks/useFoodSearch';
import useFoodLibrary from '../../hooks/useFoodLibrary';

const TABS = ['All', 'Favorites', 'My Foods'];

function FoodLibraryScreenInner({ navigation }) {
  const [activeTab, setActiveTab] = useState(0);
  const search = useFoodSearch();
  const library = useFoodLibrary();

  const favIds = useMemo(
    () => new Set(library.favorites.map((f) => f.id)),
    [library.favorites],
  );

  useFocusEffect(
    useCallback(() => {
      library.refreshAll();
    }, [library.refreshAll]),
  );

  const handleFoodPress = useCallback(
    (food) => {
      navigation.navigate('FoodDetail', { food, mode: 'view' });
    },
    [navigation],
  );

  const handleToggleFavorite = useCallback(
    (food) => library.toggleFavorite(food),
    [library],
  );

  const handleBarcodePress = useCallback(() => {
    navigation.navigate('BarcodeScanner');
  }, [navigation]);

  const handleCreatePress = useCallback(() => {
    navigation.navigate('CreateFood');
  }, [navigation]);

  const selectTab = useCallback((idx) => {
    Haptics.selectionAsync();
    setActiveTab(idx);
    if (idx !== 0) search.reset();
  }, [search]);

  const isSearching = search.query.length >= 2;

  const listData = useMemo(() => {
    if (activeTab === 1) return library.favorites;
    if (activeTab === 2) return library.customFoods;
    if (isSearching) return search.results;
    return [];
  }, [activeTab, library.favorites, library.customFoods, isSearching, search.results]);

  const renderItem = useCallback(
    ({ item }) => (
      <FoodCard
        food={item}
        onPress={handleFoodPress}
        onToggleFavorite={handleToggleFavorite}
        isFavorite={favIds.has(item.id)}
      />
    ),
    [handleFoodPress, handleToggleFavorite, favIds],
  );

  const renderRecents = useCallback(() => {
    if (activeTab !== 0 || isSearching || library.recents.length === 0) return null;
    return (
      <View style={styles.recentsSection}>
        <Text style={styles.sectionTitle}>Recently Logged</Text>
        <FlatList
          data={library.recents.slice(0, 8)}
          horizontal
          showsHorizontalScrollIndicator={false}
          keyExtractor={(item) => item.id}
          renderItem={({ item }) => (
            <FoodCard food={item} onPress={handleFoodPress} compact />
          )}
          contentContainerStyle={styles.recentsScroll}
        />
      </View>
    );
  }, [activeTab, isSearching, library.recents, handleFoodPress]);

  const renderEmpty = useCallback(() => {
    if (search.loading) {
      return <LoadingSkeleton variant="row" count={5} style={styles.skeletons} />;
    }
    if (activeTab === 0 && !isSearching) return null;
    if (activeTab === 0 && isSearching && search.error) {
      return (
        <EmptyState
          icon="cloud-offline-outline"
          title="Connection error"
          subtitle={search.error}
          actionTitle="Retry"
          onAction={search.retry}
        />
      );
    }
    if (activeTab === 0 && isSearching) {
                return (
                  <EmptyState
                    icon="search-outline"
                    title={`No foods found for '${search.query}'`}
                    action={{
                      label: `Create '${search.query}' as custom food`,
                      onPress: () => navigation.navigate('CreateFood', { initialName: search.query.trim() }),
                    }}
                  />
                );
    }
    if (activeTab === 1) {
      return (
        <EmptyState
          icon="heart-outline"
          title="No favorites yet"
          subtitle="Tap the heart icon on any food to save it here"
        />
      );
    }
    return (
      <EmptyState
        icon="restaurant-outline"
        title="No custom foods"
        subtitle="Create your own foods for quick logging"
        actionTitle="Create Food"
        onAction={handleCreatePress}
      />
    );
  }, [search, activeTab, isSearching, handleCreatePress]);

  const renderHeader = useCallback(() => (
    <>
      <Animated.View entering={FadeInUp.delay(50).duration(400)}>
        <View style={styles.headerRow}>
          <View>
            <Text style={styles.title}>Food Library</Text>
            <Text style={styles.subtitle}>3M+ foods · Custom foods · Favorites</Text>
          </View>
          <ActionButton
            title="+ Add"
            variant="secondary"
            onPress={handleCreatePress}
            style={styles.addBtn}
          />
        </View>
      </Animated.View>

      <Animated.View entering={FadeInUp.delay(100).duration(400)}>
        <FoodSearchBar
          value={search.query}
          onChangeText={search.setQuery}
          loading={search.loading && isSearching}
          onBarcodePress={handleBarcodePress}
        />
      </Animated.View>

      <TabRow
        tabs={TABS}
        activeIdx={activeTab}
        onSelect={selectTab}
      />

      {renderRecents()}
    </>
  ), [search, isSearching, activeTab, selectTab, handleBarcodePress, handleCreatePress, renderRecents]);

  return (
    <LinearGradient
      colors={[colors.deep, colors.surface1, colors.dark]}
      locations={[0, 0.5, 1]}
      style={styles.gradient}
    >
      <SafeAreaView style={styles.safe} edges={['top']}>
        <FlatList
          data={listData}
          keyExtractor={(item) => item.id}
          renderItem={renderItem}
          ListHeaderComponent={renderHeader}
          ListEmptyComponent={renderEmpty}
          onEndReached={activeTab === 0 && isSearching ? search.loadMore : undefined}
          onEndReachedThreshold={0.3}
          contentContainerStyle={styles.listContent}
          showsVerticalScrollIndicator={false}
          keyboardShouldPersistTaps="handled"
        />
      </SafeAreaView>
    </LinearGradient>
  );
}

function TabRow({ tabs, activeIdx, onSelect }) {
  return (
    <View style={styles.tabRow}>
      {tabs.map((tab, idx) => {
        const active = idx === activeIdx;
        return (
          <Pressable
            key={tab}
            onPress={() => onSelect(idx)}
            style={[styles.tabPill, active && styles.tabPillActive]}
            accessibilityRole="tab"
            accessibilityState={{ selected: active }}
          >
            <Text style={[styles.tabText, active && styles.tabTextActive]}>{tab}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

export default function FoodLibraryScreen(props) {
  return (
    <ErrorBoundary>
      <FoodLibraryScreenInner {...props} />
    </ErrorBoundary>
  );
}

const styles = StyleSheet.create({
  gradient: {
    flex: 1,
  },
  safe: {
    flex: 1,
  },
  listContent: {
    paddingHorizontal: spacing.lg,
    paddingBottom: 120,
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginTop: spacing.md,
    marginBottom: spacing.md,
  },
  title: {
    fontSize: fontSize['2xl'],
    fontWeight: fontWeight.bold,
    color: colors.textPrimary,
  },
  subtitle: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
    marginTop: 2,
  },
  addBtn: {
    minHeight: 36,
    height: 36,
  },
  tabRow: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginTop: spacing.md,
    marginBottom: spacing.md,
  },
  tabPill: {
    flex: 1,
    paddingVertical: spacing.sm,
    borderRadius: radii.full,
    borderWidth: 1,
    borderColor: colors.borderSubtle,
    backgroundColor: 'rgba(255,255,255,0.03)',
    alignItems: 'center',
    minHeight: 44,
    justifyContent: 'center',
  },
  tabPillActive: {
    backgroundColor: 'rgba(139,92,246,0.15)',
    borderColor: colors.primary,
  },
  tabText: {
    fontSize: fontSize.sm,
    fontWeight: fontWeight.semibold,
    color: colors.textMuted,
  },
  tabTextActive: {
    color: colors.primary,
  },
  recentsSection: {
    marginBottom: spacing.md,
  },
  sectionTitle: {
    fontSize: fontSize.base,
    fontWeight: fontWeight.semibold,
    color: colors.textPrimary,
    marginBottom: spacing.sm,
  },
  recentsScroll: {
    paddingRight: spacing.lg,
  },
  skeletons: {
    marginTop: spacing.md,
  },
});
