import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  FlatList,
  TextInput,
  Modal,
  Pressable,
  StyleSheet,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import AsyncStorage from '@react-native-async-storage/async-storage';
import GlassCard from '../../components/GlassCard';
import ActionButton from '../../components/ActionButton';
import EmptyState from '../../components/EmptyState';
import Badge from '../../components/Badge';
import { colors, spacing, fontSize, fontWeight, radii } from '../../theme/colors';

const STORAGE_KEY = 'exerly_measurements';
const FIELDS = ['weight', 'bodyFat', 'chest', 'waist', 'hips', 'arms', 'thighs'];

export default function MeasurementsTab() {
  const [entries, setEntries] = useState([]);
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState({});
  const [loaded, setLoaded] = useState(false);

  const load = useCallback(async () => {
    const raw = await AsyncStorage.getItem(STORAGE_KEY);
    setEntries(raw ? JSON.parse(raw) : []);
    setLoaded(true);
  }, []);

  React.useEffect(() => { load(); }, [load]);

  const handleSave = async () => {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    const entry = { ...form, date: new Date().toISOString() };
    const updated = [entry, ...entries];
    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(updated));
    setEntries(updated);
    setForm({});
    setShowModal(false);
  };

  const renderEntry = ({ item, index }) => (
    <GlassCard style={[styles.row, index === 0 && styles.rowFirst]}>
      <Text style={styles.date}>
        {new Date(item.date).toLocaleDateString()}
      </Text>
      <View style={styles.pills}>
        {FIELDS.filter((f) => item[f]).map((f) => (
          <Badge key={f} label={`${f}: ${item[f]}`} variant="active" />
        ))}
      </View>
    </GlassCard>
  );

  return (
    <View style={styles.container}>
      <FlatList
        data={entries}
        keyExtractor={(_, i) => String(i)}
        renderItem={renderEntry}
        contentContainerStyle={styles.list}
        ListHeaderComponent={
          <ActionButton
            title="Add Measurement"
            onPress={() => setShowModal(true)}
            variant="secondary"
            style={styles.addBtn}
          />
        }
        ListEmptyComponent={
          loaded ? (
            <EmptyState
              icon="body-outline"
              title="No measurements yet"
              subtitle="Track your body changes over time"
            />
          ) : null
        }
      />

      <Modal visible={showModal} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <View style={styles.modal}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Add Measurement</Text>
              <Pressable
                onPress={() => setShowModal(false)}
                accessibilityLabel="Close"
                style={styles.closeBtn}
              >
                <Ionicons name="close" size={24} color={colors.textSecondary} />
              </Pressable>
            </View>
            {FIELDS.map((f) => (
              <View key={f} style={styles.field}>
                <Text style={styles.fieldLabel}>{f}</Text>
                <TextInput
                  style={styles.input}
                  keyboardType="numeric"
                  placeholderTextColor={colors.textMuted}
                  placeholder="0"
                  value={form[f] ?? ''}
                  onChangeText={(v) => setForm((p) => ({ ...p, [f]: v }))}
                />
              </View>
            ))}
            <ActionButton title="Save" onPress={handleSave} fullWidth />
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  list: { padding: spacing.lg, paddingBottom: 120 },
  addBtn: { marginBottom: spacing.md },
  row: { marginBottom: spacing.sm },
  rowFirst: { borderColor: colors.borderAccent },
  date: {
    color: colors.textSecondary,
    fontSize: fontSize.xs,
    marginBottom: 6,
  },
  pills: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 },
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
    maxHeight: '80%',
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
  field: { marginBottom: spacing.sm },
  fieldLabel: {
    color: colors.textSecondary,
    fontSize: fontSize.xs,
    textTransform: 'capitalize',
    marginBottom: 4,
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
});
