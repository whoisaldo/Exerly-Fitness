import React, { useRef, useCallback } from 'react';
import { View, Text, FlatList, StyleSheet } from 'react-native';
import * as Haptics from 'expo-haptics';
import { colors, fontSize, fontWeight } from '../../theme/colors';

const ITEM_H = 48;
const VISIBLE = 5;
const PICKER_H = ITEM_H * VISIBLE;

/**
 * Drum-roll style scroll picker.
 * @param {{ data: (string|number)[], value: string|number, onChange: (v: string|number) => void, suffix?: string }} props
 */
export default function DrumPicker({ data, value, onChange, suffix = '' }) {
  const ref = useRef(null);
  const idx = data.indexOf(value);

  const onViewable = useCallback(({ viewableItems }) => {
    const center = viewableItems.find((v) => v.index != null);
    if (center && data[center.index] !== value) {
      Haptics.selectionAsync();
      onChange(data[center.index]);
    }
  }, [data, value, onChange]);

  const renderItem = useCallback(({ item }) => {
    const active = item === value;
    return (
      <View style={styles.item}>
        <Text style={[styles.itemText, active && styles.itemActive]}>
          {item}{suffix}
        </Text>
      </View>
    );
  }, [value, suffix]);

  return (
    <View style={styles.container}>
      <View style={styles.highlight} pointerEvents="none" />
      <FlatList
        ref={ref}
        data={data}
        keyExtractor={(item) => String(item)}
        renderItem={renderItem}
        getItemLayout={(_, i) => ({ length: ITEM_H, offset: ITEM_H * i, index: i })}
        initialScrollIndex={Math.max(idx, 0)}
        snapToInterval={ITEM_H}
        decelerationRate="fast"
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingVertical: ITEM_H * 2 }}
        onViewableItemsChanged={onViewable}
        viewabilityConfig={{ itemVisiblePercentThreshold: 60 }}
        style={styles.list}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    height: PICKER_H,
    overflow: 'hidden',
  },
  list: {
    height: PICKER_H,
  },
  highlight: {
    position: 'absolute',
    top: ITEM_H * 2,
    left: 0,
    right: 0,
    height: ITEM_H,
    backgroundColor: `${colors.primary}15`,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: `${colors.primary}33`,
    zIndex: 1,
  },
  item: {
    height: ITEM_H,
    alignItems: 'center',
    justifyContent: 'center',
  },
  itemText: {
    color: colors.textMuted,
    fontSize: fontSize.lg,
    fontWeight: fontWeight.medium,
  },
  itemActive: {
    color: colors.textPrimary,
    fontSize: fontSize.xl,
    fontWeight: fontWeight.bold,
  },
});
