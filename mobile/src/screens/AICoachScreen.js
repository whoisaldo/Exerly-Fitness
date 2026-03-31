import React, { useState, useCallback, useRef } from 'react';
import {
  View,
  Text,
  FlatList,
  TextInput,
  Pressable,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { BlurView } from 'expo-blur';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import Animated, { FadeIn, FadeInDown } from 'react-native-reanimated';
import ErrorBoundary from '../components/ErrorBoundary';
import GlassCard from '../components/GlassCard';
import apiClient from '../api/client';
import {
  colors,
  gradients,
  spacing,
  fontSize,
  fontWeight,
  radii,
} from '../theme/colors';

const QUICK_ACTIONS = [
  'Build me a workout plan',
  'What should I eat today?',
  'Analyze my week',
  'Help me sleep better',
];

function AICoachInner({ navigation }) {
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);
  const listRef = useRef(null);

  const send = useCallback(
    async (text) => {
      const userMsg = { role: 'user', content: text, id: Date.now().toString() };
      setMessages((prev) => [...prev, userMsg]);
      setInput('');
      setSending(true);
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);

      try {
        const res = await apiClient.post('/api/ai/generate', { prompt: text });
        const aiMsg = {
          role: 'assistant',
          content: res.data?.response ?? res.data?.message ?? 'No response',
          id: (Date.now() + 1).toString(),
        };
        setMessages((prev) => [...prev, aiMsg]);
      } catch {
        setMessages((prev) => [
          ...prev,
          { role: 'assistant', content: 'Sorry, something went wrong.', id: (Date.now() + 1).toString() },
        ]);
      } finally {
        setSending(false);
      }
    },
    [],
  );

  const handleSend = useCallback(() => {
    if (!input.trim() || sending) return;
    send(input.trim());
  }, [input, sending, send]);

  const renderMessage = ({ item }) => {
    const isUser = item.role === 'user';
    return (
      <Animated.View
        entering={FadeInDown.duration(300)}
        style={[styles.msgRow, isUser && styles.msgRowUser]}
      >
        {!isUser && (
          <View style={styles.aiAvatar}>
            <Ionicons name="sparkles" size={16} color={colors.primary} />
          </View>
        )}
        <View style={[styles.bubble, isUser ? styles.bubbleUser : styles.bubbleAi]}>
          <Text style={[styles.msgText, isUser && styles.msgTextUser]}>
            {item.content}
          </Text>
        </View>
      </Animated.View>
    );
  };

  return (
    <LinearGradient
      colors={[colors.deep, colors.surface1, colors.dark]}
      locations={[0, 0.5, 1]}
      style={styles.container}
    >
      <SafeAreaView style={styles.safe} edges={['top']}>
        <View style={styles.header}>
          <Pressable
            onPress={() => navigation.goBack()}
            style={styles.backBtn}
            accessibilityLabel="Go back"
          >
            <Ionicons name="arrow-back" size={24} color={colors.textPrimary} />
          </Pressable>
          <Text style={styles.title}>AI Coach</Text>
          <View style={styles.creditBadge}>
            <Ionicons name="sparkles" size={12} color={colors.primary} />
          </View>
        </View>

        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
          style={styles.chatArea}
          keyboardVerticalOffset={100}
        >
          <FlatList
            ref={listRef}
            data={messages}
            keyExtractor={(item) => item.id}
            renderItem={renderMessage}
            contentContainerStyle={styles.chatList}
            onContentSizeChange={() => listRef.current?.scrollToEnd({ animated: true })}
            ListEmptyComponent={
              <View style={styles.empty}>
                <Ionicons name="chatbubble-ellipses-outline" size={48} color={`${colors.primary}44`} />
                <Text style={styles.emptyText}>Ask your AI Coach anything</Text>
                <View style={styles.quickActions}>
                  {QUICK_ACTIONS.map((q) => (
                    <Pressable key={q} onPress={() => send(q)} style={styles.quickChip}>
                      <Text style={styles.quickText}>{q}</Text>
                    </Pressable>
                  ))}
                </View>
              </View>
            }
          />

          {sending && (
            <Animated.View entering={FadeIn} style={styles.typing}>
              <Text style={styles.typingText}>AI is thinking...</Text>
            </Animated.View>
          )}

          <BlurView intensity={60} tint="dark" style={styles.inputBar}>
            <TextInput
              style={styles.input}
              placeholder="Message your coach..."
              placeholderTextColor={colors.textMuted}
              value={input}
              onChangeText={setInput}
              multiline
              maxLength={500}
              returnKeyType="send"
              onSubmitEditing={handleSend}
              blurOnSubmit
            />
            <Pressable
              onPress={handleSend}
              disabled={!input.trim() || sending}
              style={[styles.sendBtn, (!input.trim() || sending) && styles.sendDisabled]}
              accessibilityLabel="Send message"
              accessibilityRole="button"
            >
              <Ionicons name="send" size={18} color="#fff" />
            </Pressable>
          </BlurView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </LinearGradient>
  );
}

export default function AICoachScreen(props) {
  return (
    <ErrorBoundary>
      <AICoachInner {...props} />
    </ErrorBoundary>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  safe: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
  },
  backBtn: { minWidth: 44, minHeight: 44, justifyContent: 'center' },
  title: {
    flex: 1,
    color: colors.textPrimary,
    fontSize: fontSize.lg,
    fontWeight: fontWeight.bold,
    marginLeft: spacing.sm,
  },
  creditBadge: {
    backgroundColor: `${colors.primary}22`,
    borderRadius: radii.full,
    padding: 8,
  },
  chatArea: { flex: 1 },
  chatList: { padding: spacing.lg, paddingBottom: 80 },
  empty: { alignItems: 'center', paddingTop: 60 },
  emptyText: {
    color: colors.textMuted,
    fontSize: fontSize.base,
    marginTop: spacing.md,
    marginBottom: spacing.lg,
  },
  quickActions: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, justifyContent: 'center' },
  quickChip: {
    backgroundColor: `${colors.primary}18`,
    borderWidth: 1,
    borderColor: `${colors.primary}33`,
    borderRadius: radii.full,
    paddingHorizontal: 14,
    paddingVertical: 8,
    minHeight: 36,
  },
  quickText: { color: colors.primary, fontSize: fontSize.xs },
  msgRow: { flexDirection: 'row', marginBottom: spacing.md, alignItems: 'flex-end' },
  msgRowUser: { justifyContent: 'flex-end' },
  aiAvatar: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: `${colors.primary}22`,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 8,
  },
  bubble: {
    maxWidth: '78%',
    borderRadius: radii.lg,
    padding: 12,
  },
  bubbleUser: {
    backgroundColor: colors.primary,
    borderBottomRightRadius: 4,
  },
  bubbleAi: {
    backgroundColor: colors.glassBg,
    borderWidth: 1,
    borderColor: colors.glassBorder,
    borderLeftWidth: 3,
    borderLeftColor: colors.primary,
    borderBottomLeftRadius: 4,
  },
  msgText: { color: colors.textPrimary, fontSize: fontSize.sm, lineHeight: 20 },
  msgTextUser: { color: '#fff' },
  typing: { paddingHorizontal: spacing.lg, paddingBottom: 4 },
  typingText: { color: colors.textMuted, fontSize: fontSize.xs },
  inputBar: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    paddingHorizontal: spacing.md,
    paddingVertical: 8,
    borderTopWidth: 1,
    borderTopColor: colors.glassBorder,
  },
  input: {
    flex: 1,
    color: colors.textPrimary,
    fontSize: fontSize.base,
    maxHeight: 100,
    paddingVertical: 10,
    paddingHorizontal: 12,
  },
  sendBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: 8,
  },
  sendDisabled: { opacity: 0.4 },
});
