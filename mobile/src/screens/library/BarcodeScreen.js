import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  View,
  Text,
  TextInput,
  Pressable,
  ActivityIndicator,
  StyleSheet,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import * as Haptics from 'expo-haptics';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withRepeat,
  withTiming,
  Easing,
  SlideInDown,
} from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { colors, radii, fontSize, fontWeight, spacing } from '../../theme/colors';
import ErrorBoundary from '../../components/ErrorBoundary';
import GlassCard from '../../components/GlassCard';
import ActionButton from '../../components/ActionButton';
import FoodCard from '../../components/library/FoodCard';
import EmptyState from '../../components/EmptyState';
import { fetchByBarcode } from '../../services/OpenFoodFactsService';

function BarcodeScreenInner({ navigation }) {
  const [permission, requestPermission] = useCameraPermissions();
  const [scannedCode, setScannedCode] = useState(null);
  const [product, setProduct] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [manualCode, setManualCode] = useState('');
  const [paused, setPaused] = useState(false);
  const processingRef = useRef(false);

  const scanLineY = useSharedValue(0);

  useEffect(() => {
    scanLineY.value = withRepeat(
      withTiming(1, { duration: 2000, easing: Easing.inOut(Easing.ease) }),
      -1,
      true,
    );
  }, [scanLineY]);

  const scanLineStyle = useAnimatedStyle(() => ({
    top: `${scanLineY.value * 100}%`,
  }));

  const handleBarCodeScanned = useCallback(async ({ data }) => {
    if (processingRef.current || paused) return;
    processingRef.current = true;
    setPaused(true);
    setScannedCode(data);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    await lookupBarcode(data);
    processingRef.current = false;
  }, [paused]);

  const lookupBarcode = async (code) => {
    setLoading(true);
    setError(null);
    setProduct(null);

    try {
      const result = await fetchByBarcode(code);
      if (result) {
        setProduct(result);
      } else {
        setError('not_found');
      }
    } catch {
      setError('network');
    } finally {
      setLoading(false);
    }
  };

  const handleManualSubmit = useCallback(() => {
    if (!manualCode.trim()) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    setPaused(true);
    setScannedCode(manualCode.trim());
    lookupBarcode(manualCode.trim());
  }, [manualCode]);

  const handleScanAnother = useCallback(() => {
    Haptics.selectionAsync();
    setPaused(false);
    setProduct(null);
    setError(null);
    setScannedCode(null);
    setManualCode('');
  }, []);

  const handleFoodPress = useCallback((food) => {
    navigation.navigate('FoodDetail', { food, mode: 'log' });
  }, [navigation]);

  const handleCreateCustom = useCallback(() => {
    navigation.navigate('CreateFood', { barcode: scannedCode });
  }, [navigation, scannedCode]);

  if (!permission) {
    return <View style={styles.container} />;
  }

  if (!permission.granted) {
    return (
      <View style={styles.container}>
        <SafeAreaView style={styles.permissionSafe}>
          <EmptyState
            icon="camera-outline"
            title="Camera access needed"
            subtitle="Allow camera access to scan food barcodes"
            actionTitle="Grant Permission"
            onAction={requestPermission}
          />
          <Pressable
            onPress={() => navigation.goBack()}
            style={styles.backLink}
            accessibilityRole="button"
          >
            <Text style={styles.backLinkText}>Go Back</Text>
          </Pressable>
        </SafeAreaView>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <CameraView
        style={styles.camera}
        barcodeScannerSettings={{ barcodeTypes: ['ean13', 'ean8', 'upc_a', 'upc_e', 'code128'] }}
        onBarcodeScanned={paused ? undefined : handleBarCodeScanned}
      />

      <View style={styles.overlay}>
        <SafeAreaView style={styles.overlaySafe}>
          <View style={styles.topBar}>
            <Pressable
              onPress={() => {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                navigation.goBack();
              }}
              style={styles.closeBtn}
              accessibilityRole="button"
              accessibilityLabel="Close scanner"
            >
              <Ionicons name="close" size={28} color={colors.textPrimary} />
            </Pressable>
            <Text style={styles.topTitle}>Scan a barcode</Text>
            <View style={styles.closeBtn} />
          </View>

          <View style={styles.scanArea}>
            <View style={styles.scanWindow}>
              <ScanCorner position="topLeft" />
              <ScanCorner position="topRight" />
              <ScanCorner position="bottomLeft" />
              <ScanCorner position="bottomRight" />
              <Animated.View style={[styles.scanLine, scanLineStyle]} />
            </View>
          </View>
        </SafeAreaView>
      </View>

      <Animated.View entering={SlideInDown.duration(300)} style={styles.bottomPanel}>
        <GlassCard elevated style={styles.bottomCard}>
          {loading && (
            <View style={styles.loadingWrap}>
              <ActivityIndicator size="small" color={colors.primary} />
              <Text style={styles.loadingText}>Looking up product...</Text>
            </View>
          )}

          {!loading && product && (
            <View>
              <FoodCard food={product} onPress={handleFoodPress} />
              <View style={styles.actionRow}>
                <ActionButton
                  title="Log This Food"
                  variant="primary"
                  onPress={() => handleFoodPress(product)}
                  style={styles.actionBtn}
                />
                <ActionButton
                  title="View Details"
                  variant="secondary"
                  onPress={() => navigation.navigate('FoodDetail', { food: product, mode: 'view' })}
                  style={styles.actionBtn}
                />
              </View>
              <Pressable onPress={handleScanAnother} style={styles.scanAgainBtn}>
                <Text style={styles.scanAgainText}>Scan Another</Text>
              </Pressable>
            </View>
          )}

          {!loading && error === 'not_found' && (
            <View style={styles.errorWrap}>
              <Text style={styles.errorTitle}>Product not found</Text>
              <ActionButton
                title="Create this food manually"
                variant="secondary"
                onPress={handleCreateCustom}
              />
              <Pressable onPress={handleScanAnother} style={styles.scanAgainBtn}>
                <Text style={styles.scanAgainText}>Scan Another</Text>
              </Pressable>
            </View>
          )}

          {!loading && error === 'network' && (
            <View style={styles.errorWrap}>
              <Text style={styles.errorTitle}>Connection error</Text>
              <ActionButton
                title="Retry"
                variant="secondary"
                onPress={() => scannedCode && lookupBarcode(scannedCode)}
              />
            </View>
          )}

          {!loading && !product && !error && (
            <View>
              <Text style={styles.instructionText}>
                Point camera at barcode
              </Text>
              <View style={styles.manualRow}>
                <TextInput
                  style={styles.manualInput}
                  placeholder="Enter barcode manually"
                  placeholderTextColor={colors.textMuted}
                  value={manualCode}
                  onChangeText={setManualCode}
                  keyboardType="numeric"
                  returnKeyType="search"
                  onSubmitEditing={handleManualSubmit}
                />
                <ActionButton
                  title="Go"
                  variant="primary"
                  onPress={handleManualSubmit}
                  disabled={!manualCode.trim()}
                  style={styles.goBtn}
                />
              </View>
            </View>
          )}
        </GlassCard>
      </Animated.View>
    </View>
  );
}

function ScanCorner({ position }) {
  const isTop = position.includes('top');
  const isLeft = position.includes('Left');
  return (
    <View
      style={[
        styles.corner,
        isTop ? styles.cornerTop : styles.cornerBottom,
        isLeft ? styles.cornerLeft : styles.cornerRight,
        {
          borderTopWidth: isTop ? 3 : 0,
          borderBottomWidth: !isTop ? 3 : 0,
          borderLeftWidth: isLeft ? 3 : 0,
          borderRightWidth: !isLeft ? 3 : 0,
        },
      ]}
    />
  );
}

export default function BarcodeScreen(props) {
  return (
    <ErrorBoundary>
      <BarcodeScreenInner {...props} />
    </ErrorBoundary>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.deep,
  },
  permissionSafe: {
    flex: 1,
    justifyContent: 'center',
  },
  camera: {
    flex: 1,
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.5)',
  },
  overlaySafe: {
    flex: 1,
  },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.md,
    paddingTop: spacing.sm,
  },
  closeBtn: {
    minWidth: 44,
    minHeight: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  topTitle: {
    fontSize: fontSize.md,
    fontWeight: fontWeight.semibold,
    color: colors.textPrimary,
  },
  scanArea: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  scanWindow: {
    width: 260,
    height: 160,
    backgroundColor: 'transparent',
    borderRadius: radii.md,
    overflow: 'hidden',
  },
  scanLine: {
    position: 'absolute',
    left: 8,
    right: 8,
    height: 2,
    backgroundColor: colors.primary,
    borderRadius: 1,
    shadowColor: colors.primary,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.8,
    shadowRadius: 8,
  },
  corner: {
    position: 'absolute',
    width: 24,
    height: 24,
    borderColor: colors.primary,
  },
  cornerTop: {
    top: 0,
  },
  cornerBottom: {
    bottom: 0,
  },
  cornerLeft: {
    left: 0,
    borderTopLeftRadius: radii.sm,
    borderBottomLeftRadius: radii.sm,
  },
  cornerRight: {
    right: 0,
    borderTopRightRadius: radii.sm,
    borderBottomRightRadius: radii.sm,
  },
  bottomPanel: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
  },
  bottomCard: {
    borderBottomLeftRadius: 0,
    borderBottomRightRadius: 0,
    paddingBottom: spacing['2xl'],
  },
  loadingWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
    paddingVertical: spacing.md,
  },
  loadingText: {
    fontSize: fontSize.sm,
    color: colors.textSecondary,
  },
  instructionText: {
    fontSize: fontSize.base,
    color: colors.textMuted,
    textAlign: 'center',
    marginBottom: spacing.md,
  },
  manualRow: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  manualInput: {
    flex: 1,
    backgroundColor: 'rgba(255,255,255,0.04)',
    borderWidth: 1,
    borderColor: colors.borderSubtle,
    borderRadius: radii.md,
    paddingHorizontal: spacing.md,
    paddingVertical: 12,
    color: colors.textPrimary,
    fontSize: fontSize.base,
    minHeight: 48,
  },
  goBtn: {
    minWidth: 60,
  },
  actionRow: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginTop: spacing.sm,
  },
  actionBtn: {
    flex: 1,
  },
  scanAgainBtn: {
    alignItems: 'center',
    paddingVertical: spacing.md,
    minHeight: 44,
    justifyContent: 'center',
  },
  scanAgainText: {
    fontSize: fontSize.sm,
    color: colors.primary,
    fontWeight: fontWeight.medium,
  },
  errorWrap: {
    alignItems: 'center',
    gap: spacing.md,
    paddingVertical: spacing.sm,
  },
  errorTitle: {
    fontSize: fontSize.base,
    fontWeight: fontWeight.semibold,
    color: colors.textPrimary,
  },
  backLink: {
    alignItems: 'center',
    paddingVertical: spacing.md,
    minHeight: 44,
  },
  backLinkText: {
    fontSize: fontSize.base,
    color: colors.primary,
    fontWeight: fontWeight.medium,
  },
});
