import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  FlatList,
  Image,
  Pressable,
  Modal,
  StyleSheet,
  Dimensions,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as ImagePicker from 'expo-image-picker';
import * as Haptics from 'expo-haptics';
import AsyncStorage from '@react-native-async-storage/async-storage';
import EmptyState from '../../components/EmptyState';
import { colors, spacing, fontSize, fontWeight, radii } from '../../theme/colors';

const STORAGE_KEY = 'exerly_progress_photos';
const COL = 3;
const GAP = 4;
const ITEM_W = (Dimensions.get('window').width - spacing.lg * 2 - GAP * (COL - 1)) / COL;

export default function PhotosTab() {
  const [photos, setPhotos] = useState([]);
  const [selected, setSelected] = useState(null);
  const [loaded, setLoaded] = useState(false);

  const load = useCallback(async () => {
    const raw = await AsyncStorage.getItem(STORAGE_KEY);
    setPhotos(raw ? JSON.parse(raw) : []);
    setLoaded(true);
  }, []);

  React.useEffect(() => { load(); }, [load]);

  const addPhoto = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      quality: 0.7,
    });
    if (result.canceled) return;
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    const entry = { uri: result.assets[0].uri, date: new Date().toISOString() };
    const updated = [entry, ...photos];
    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(updated));
    setPhotos(updated);
  };

  const renderItem = ({ item }) => (
    <Pressable
      onPress={() => setSelected(item)}
      style={styles.cell}
      accessibilityLabel={`Progress photo from ${new Date(item.date).toLocaleDateString()}`}
    >
      <Image source={{ uri: item.uri }} style={styles.thumb} />
      <Text style={styles.cellDate}>
        {new Date(item.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
      </Text>
    </Pressable>
  );

  return (
    <View style={styles.container}>
      <FlatList
        data={photos}
        keyExtractor={(_, i) => String(i)}
        renderItem={renderItem}
        numColumns={COL}
        columnWrapperStyle={styles.row}
        contentContainerStyle={styles.list}
        ListEmptyComponent={
          loaded ? (
            <EmptyState
              icon="camera-outline"
              title="No progress photos"
              subtitle="Take photos to visually track changes"
              actionTitle="Add Photo"
              onAction={addPhoto}
            />
          ) : null
        }
      />

      <Pressable
        onPress={addPhoto}
        style={styles.fab}
        accessibilityRole="button"
        accessibilityLabel="Add progress photo"
      >
        <Ionicons name="add" size={28} color="#fff" />
      </Pressable>

      <Modal visible={!!selected} transparent animationType="fade">
        <Pressable
          style={styles.overlay}
          onPress={() => setSelected(null)}
          accessibilityLabel="Close photo"
        >
          {selected && (
            <View style={styles.fullWrap}>
              <Image source={{ uri: selected.uri }} style={styles.fullImage} resizeMode="contain" />
              <Text style={styles.fullDate}>
                {new Date(selected.date).toLocaleDateString()}
              </Text>
            </View>
          )}
        </Pressable>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  list: { padding: spacing.lg, paddingBottom: 120 },
  row: { gap: GAP, marginBottom: GAP },
  cell: {
    width: ITEM_W,
    height: ITEM_W * 1.3,
    borderRadius: radii.md,
    overflow: 'hidden',
    backgroundColor: colors.surface2,
  },
  thumb: { width: '100%', height: '100%' },
  cellDate: {
    position: 'absolute',
    bottom: 4,
    left: 4,
    right: 4,
    color: '#fff',
    fontSize: 10,
    textAlign: 'center',
    backgroundColor: 'rgba(0,0,0,0.5)',
    borderRadius: 4,
    paddingVertical: 2,
  },
  fab: {
    position: 'absolute',
    bottom: 100,
    right: spacing.lg,
    width: 52,
    height: 52,
    borderRadius: 26,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: colors.primary,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
    elevation: 8,
  },
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.9)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  fullWrap: { alignItems: 'center' },
  fullImage: {
    width: Dimensions.get('window').width - 40,
    height: Dimensions.get('window').height * 0.7,
  },
  fullDate: {
    color: colors.textSecondary,
    fontSize: fontSize.sm,
    marginTop: spacing.md,
  },
});
