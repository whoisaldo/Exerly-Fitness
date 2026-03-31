import React from 'react';
import {
  View,
  TextInput,
  Pressable,
  ActivityIndicator,
  StyleSheet,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { colors, radii, fontSize, spacing } from '../../theme/colors';

export default function FoodSearchBar({
  value,
  onChangeText,
  loading = false,
  onBarcodePress,
  placeholder = 'Search 3M+ foods...',
  autoFocus = false,
}) {
  const handleClear = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    onChangeText('');
  };

  const handleBarcode = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    onBarcodePress?.();
  };

  return (
    <View style={styles.container}>
      {loading ? (
        <ActivityIndicator size="small" color={colors.primary} style={styles.icon} />
      ) : (
        <Ionicons name="search" size={20} color={colors.textMuted} style={styles.icon} />
      )}
      <TextInput
        style={styles.input}
        placeholder={placeholder}
        placeholderTextColor={colors.textMuted}
        value={value}
        onChangeText={onChangeText}
        autoFocus={autoFocus}
        returnKeyType="search"
        autoCorrect={false}
        autoCapitalize="none"
      />
      {value?.length > 0 && (
        <Pressable
          onPress={handleClear}
          hitSlop={12}
          style={styles.clearBtn}
          accessibilityRole="button"
          accessibilityLabel="Clear search"
        >
          <Ionicons name="close-circle" size={20} color={colors.textMuted} />
        </Pressable>
      )}
      {onBarcodePress && (
        <Pressable
          onPress={handleBarcode}
          hitSlop={12}
          style={styles.barcodeBtn}
          accessibilityRole="button"
          accessibilityLabel="Scan barcode"
        >
          <Ionicons name="barcode-outline" size={22} color={colors.primary} />
        </Pressable>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.04)',
    borderWidth: 1,
    borderColor: colors.borderSubtle,
    borderRadius: radii.md,
    minHeight: 48,
    paddingHorizontal: spacing.sm,
  },
  icon: {
    marginRight: spacing.sm,
    width: 24,
    alignItems: 'center',
  },
  input: {
    flex: 1,
    color: colors.textPrimary,
    fontSize: fontSize.base,
    paddingVertical: 12,
  },
  clearBtn: {
    minWidth: 44,
    minHeight: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  barcodeBtn: {
    minWidth: 44,
    minHeight: 44,
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: spacing.xs,
    borderLeftWidth: 1,
    borderLeftColor: colors.borderSubtle,
  },
});
