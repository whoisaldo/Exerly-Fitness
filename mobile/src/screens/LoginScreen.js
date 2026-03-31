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
import GlassCard from '../components/GlassCard';
import ActionButton from '../components/ActionButton';
import apiClient from '../api/client';
import { useAuth } from '../context/AuthContext';

export default function LoginScreen({ navigation }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [emailFocused, setEmailFocused] = useState(false);
  const [passwordFocused, setPasswordFocused] = useState(false);
  const { login } = useAuth();
  const passwordRef = useRef(null);

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

  const handleLogin = async () => {
    if (!email || !password) {
      setError('Please enter email and password');
      triggerShake();
      return;
    }

    setLoading(true);
    setError('');

    try {
      const response = await apiClient.post('/login', { email, password });
      if (response.data.token) {
        await login(response.data.token);
      }
    } catch (err) {
      setError(err.message || 'Login failed. Please try again.');
      triggerShake();
    } finally {
      setLoading(false);
    }
  };

  const emailHasValue = email.length > 0;
  const passwordHasValue = password.length > 0;

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
              <Text style={styles.subtitle}>Welcome back</Text>
            </Animated.View>

            {/* Form Card */}
            <Animated.View
              entering={FadeInUp.delay(250).duration(700).springify()}
              style={shakeStyle}
            >
              <GlassCard elevated style={styles.card}>
                <BlurView intensity={20} tint="dark" style={styles.blur}>
                  <View style={styles.cardInner}>
                    <Text style={styles.formTitle}>Sign In</Text>

                    {error ? (
                      <View style={styles.errorBox}>
                        <Text style={styles.errorText}>{error}</Text>
                      </View>
                    ) : null}

                    {/* Email */}
                    <View style={styles.fieldWrap}>
                      <Text
                        style={[
                          styles.floatingLabel,
                          (emailFocused || emailHasValue) && styles.floatingLabelActive,
                        ]}
                      >
                        Email
                      </Text>
                      <TextInput
                        style={[
                          styles.input,
                          emailFocused && styles.inputFocused,
                        ]}
                        value={email}
                        onChangeText={setEmail}
                        onFocus={() => setEmailFocused(true)}
                        onBlur={() => setEmailFocused(false)}
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
                          (passwordFocused || passwordHasValue) && styles.floatingLabelActive,
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
                            passwordFocused && styles.inputFocused,
                          ]}
                          value={password}
                          onChangeText={setPassword}
                          onFocus={() => setPasswordFocused(true)}
                          onBlur={() => setPasswordFocused(false)}
                          secureTextEntry={!showPassword}
                          returnKeyType="go"
                          onSubmitEditing={handleLogin}
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

                    <ActionButton
                      variant="primary"
                      onPress={handleLogin}
                      loading={loading}
                      style={styles.submitBtn}
                    >
                      Sign In
                    </ActionButton>

                    <View style={styles.switchRow}>
                      <Text style={styles.switchText}>
                        Don't have an account?{' '}
                      </Text>
                      <Pressable
                        onPress={() => navigation.navigate('Signup')}
                        hitSlop={8}
                      >
                        <Text style={styles.switchLink}>Sign Up</Text>
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
    marginBottom: spacing.xl,
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
