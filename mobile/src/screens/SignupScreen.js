import React, { useState, useRef } from 'react';
import {
  StyleSheet,
  Text,
  View,
  TextInput,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  Pressable,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { BlurView } from 'expo-blur';
import Animated, {
  FadeInUp,
  useSharedValue,
  useAnimatedStyle,
  withSequence,
  withTiming,
} from 'react-native-reanimated';
import { colors, gradients, spacing, radii, fontSize, fontWeight } from '../theme/colors';
import { GlassCard } from '../components/GlassCard';
import { ActionButton } from '../components/ActionButton';
import apiClient from '../api/client';
import { useAuth } from '../context/AuthContext';

export default function SignupScreen({ navigation }) {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [focused, setFocused] = useState({});
  const { login } = useAuth();

  const emailRef = useRef(null);
  const passwordRef = useRef(null);
  const confirmRef = useRef(null);

  const shakeX = useSharedValue(0);
  const shakeStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: shakeX.value }],
  }));

  const triggerShake = () => {
    shakeX.value = withSequence(
      withTiming(12, { duration: 50 }),
      withTiming(-12, { duration: 50 }),
      withTiming(8, { duration: 50 }),
      withTiming(-8, { duration: 50 }),
      withTiming(4, { duration: 50 }),
      withTiming(0, { duration: 50 }),
    );
  };

  const handleSignup = async () => {
    if (!name || !email || !password) {
      setError('Please fill in all fields');
      triggerShake();
      return;
    }
    if (password !== confirmPassword) {
      setError('Passwords do not match');
      triggerShake();
      return;
    }
    if (password.length < 6) {
      setError('Password must be at least 6 characters');
      triggerShake();
      return;
    }

    setLoading(true);
    setError('');

    try {
      const response = await apiClient.post('/signup', { name, email, password });
      if (response.data.token) {
        await login(response.data.token);
      }
    } catch (err) {
      setError(err.message || 'Signup failed. Please try again.');
      triggerShake();
    } finally {
      setLoading(false);
    }
  };

  const setFieldFocused = (field, value) =>
    setFocused((prev) => ({ ...prev, [field]: value }));

  const isActive = (field, val) => focused[field] || val.length > 0;

  return (
    <LinearGradient
      colors={[colors.deep, colors.surface1, colors.dark]}
      locations={[0, 0.5, 1]}
      style={styles.container}
    >
      <SafeAreaView style={styles.safe} edges={['top', 'bottom']}>
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          style={styles.kav}
        >
          <ScrollView
            contentContainerStyle={styles.scroll}
            showsVerticalScrollIndicator={false}
            keyboardShouldPersistTaps="handled"
          >
            {/* Header */}
            <Animated.View
              entering={FadeInUp.delay(100).duration(600).springify()}
              style={styles.header}
            >
              <Text style={styles.brand}>Exerly</Text>
              <Text style={styles.subtitle}>Start your journey</Text>
            </Animated.View>

            {/* Form Card */}
            <Animated.View
              entering={FadeInUp.delay(250).duration(700).springify()}
              style={shakeStyle}
            >
              <GlassCard elevated style={styles.card}>
                <BlurView intensity={20} tint="dark" style={styles.blur}>
                  <View style={styles.cardInner}>
                    <Text style={styles.formTitle}>Create Account</Text>

                    {error ? (
                      <View style={styles.errorBox}>
                        <Text style={styles.errorText}>{error}</Text>
                      </View>
                    ) : null}

                    {/* Name */}
                    <View style={styles.fieldWrap}>
                      <Text
                        style={[
                          styles.floatingLabel,
                          isActive('name', name) && styles.floatingLabelActive,
                        ]}
                      >
                        Full Name
                      </Text>
                      <TextInput
                        style={[
                          styles.input,
                          focused.name && styles.inputFocused,
                        ]}
                        value={name}
                        onChangeText={setName}
                        onFocus={() => setFieldFocused('name', true)}
                        onBlur={() => setFieldFocused('name', false)}
                        autoCapitalize="words"
                        returnKeyType="next"
                        onSubmitEditing={() => emailRef.current?.focus()}
                        placeholderTextColor="transparent"
                      />
                    </View>

                    {/* Email */}
                    <View style={styles.fieldWrap}>
                      <Text
                        style={[
                          styles.floatingLabel,
                          isActive('email', email) && styles.floatingLabelActive,
                        ]}
                      >
                        Email
                      </Text>
                      <TextInput
                        ref={emailRef}
                        style={[
                          styles.input,
                          focused.email && styles.inputFocused,
                        ]}
                        value={email}
                        onChangeText={setEmail}
                        onFocus={() => setFieldFocused('email', true)}
                        onBlur={() => setFieldFocused('email', false)}
                        keyboardType="email-address"
                        autoCapitalize="none"
                        autoCorrect={false}
                        returnKeyType="next"
                        onSubmitEditing={() => passwordRef.current?.focus()}
                        placeholderTextColor="transparent"
                      />
                    </View>

                    {/* Password */}
                    <View style={styles.fieldWrap}>
                      <Text
                        style={[
                          styles.floatingLabel,
                          isActive('password', password) && styles.floatingLabelActive,
                        ]}
                      >
                        Password
                      </Text>
                      <View style={styles.passwordRow}>
                        <TextInput
                          ref={passwordRef}
                          style={[
                            styles.input,
                            styles.passwordInput,
                            focused.password && styles.inputFocused,
                          ]}
                          value={password}
                          onChangeText={setPassword}
                          onFocus={() => setFieldFocused('password', true)}
                          onBlur={() => setFieldFocused('password', false)}
                          secureTextEntry={!showPassword}
                          returnKeyType="next"
                          onSubmitEditing={() => confirmRef.current?.focus()}
                          placeholderTextColor="transparent"
                        />
                        <Pressable
                          onPress={() => setShowPassword(!showPassword)}
                          style={styles.eyeButton}
                          hitSlop={8}
                        >
                          <Text style={styles.eyeIcon}>
                            {showPassword ? 'Hide' : 'Show'}
                          </Text>
                        </Pressable>
                      </View>
                    </View>

                    {/* Confirm Password */}
                    <View style={styles.fieldWrap}>
                      <Text
                        style={[
                          styles.floatingLabel,
                          isActive('confirm', confirmPassword) && styles.floatingLabelActive,
                        ]}
                      >
                        Confirm Password
                      </Text>
                      <TextInput
                        ref={confirmRef}
                        style={[
                          styles.input,
                          focused.confirm && styles.inputFocused,
                        ]}
                        value={confirmPassword}
                        onChangeText={setConfirmPassword}
                        onFocus={() => setFieldFocused('confirm', true)}
                        onBlur={() => setFieldFocused('confirm', false)}
                        secureTextEntry={!showPassword}
                        returnKeyType="go"
                        onSubmitEditing={handleSignup}
                        placeholderTextColor="transparent"
                      />
                    </View>

                    <ActionButton
                      variant="primary"
                      onPress={handleSignup}
                      loading={loading}
                      style={styles.submitBtn}
                    >
                      Create Account
                    </ActionButton>

                    <View style={styles.switchRow}>
                      <Text style={styles.switchText}>
                        Already have an account?{' '}
                      </Text>
                      <Pressable
                        onPress={() => navigation.navigate('Login')}
                        hitSlop={8}
                      >
                        <Text style={styles.switchLink}>Sign In</Text>
                      </Pressable>
                    </View>
                  </View>
                </BlurView>
              </GlassCard>
            </Animated.View>
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  safe: {
    flex: 1,
  },
  kav: {
    flex: 1,
  },
  scroll: {
    flexGrow: 1,
    justifyContent: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.xl,
  },
  header: {
    alignItems: 'center',
    marginBottom: spacing.lg,
  },
  brand: {
    fontSize: fontSize['3xl'],
    fontWeight: fontWeight.extrabold,
    color: colors.textPrimary,
    letterSpacing: -1,
  },
  subtitle: {
    fontSize: fontSize.base,
    color: colors.textSecondary,
    marginTop: spacing.xs,
  },
  card: {
    padding: 0,
    overflow: 'hidden',
  },
  blur: {
    overflow: 'hidden',
    borderRadius: radii.lg,
  },
  cardInner: {
    padding: spacing.lg,
  },
  formTitle: {
    fontSize: fontSize.xl,
    fontWeight: fontWeight.bold,
    color: colors.textPrimary,
    marginBottom: spacing.lg,
  },
  errorBox: {
    backgroundColor: colors.errorGlow,
    borderWidth: 1,
    borderColor: 'rgba(239,68,68,0.3)',
    borderRadius: radii.sm,
    padding: spacing.md,
    marginBottom: spacing.md,
  },
  errorText: {
    color: colors.error,
    fontSize: fontSize.sm,
    textAlign: 'center',
  },
  fieldWrap: {
    marginBottom: spacing.md,
    position: 'relative',
  },
  floatingLabel: {
    position: 'absolute',
    left: spacing.md,
    top: 16,
    fontSize: fontSize.base,
    color: colors.textMuted,
    zIndex: 1,
  },
  floatingLabelActive: {
    top: 6,
    fontSize: fontSize.xs,
    color: colors.primaryBright,
  },
  input: {
    backgroundColor: 'rgba(255,255,255,0.04)',
    borderWidth: 1,
    borderColor: colors.borderSubtle,
    borderRadius: radii.md,
    paddingHorizontal: spacing.md,
    paddingTop: 22,
    paddingBottom: 10,
    color: colors.textPrimary,
    fontSize: fontSize.base,
    minHeight: 52,
  },
  inputFocused: {
    borderColor: colors.borderAccent,
  },
  passwordRow: {
    position: 'relative',
  },
  passwordInput: {
    paddingRight: 64,
  },
  eyeButton: {
    position: 'absolute',
    right: 0,
    top: 0,
    bottom: 0,
    justifyContent: 'center',
    paddingHorizontal: spacing.md,
    minWidth: 44,
    minHeight: 44,
  },
  eyeIcon: {
    color: colors.textSecondary,
    fontSize: fontSize.sm,
    fontWeight: fontWeight.medium,
  },
  submitBtn: {
    marginTop: spacing.sm,
    minHeight: 50,
  },
  switchRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginTop: spacing.lg,
    paddingTop: spacing.md,
    borderTopWidth: 1,
    borderTopColor: colors.borderSubtle,
  },
  switchText: {
    color: colors.textMuted,
    fontSize: fontSize.sm,
  },
  switchLink: {
    color: colors.secondary,
    fontSize: fontSize.sm,
    fontWeight: fontWeight.semibold,
  },
});
