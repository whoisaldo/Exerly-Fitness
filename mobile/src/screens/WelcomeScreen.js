import React, { useState, useEffect } from 'react';
import {
  StyleSheet,
  Text,
  View,
  TouchableOpacity,
  ActivityIndicator,
  ScrollView,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { colors, spacing, borderRadius, fontSize, fontWeight } from '../theme/colors';
import API_CONFIG from '../config';
import apiClient from '../api/client';

export default function WelcomeScreen({ navigation }) {
  const [connectionStatus, setConnectionStatus] = useState('checking');
  const [serverInfo, setServerInfo] = useState(null);

  useEffect(() => {
    checkBackendConnection();
  }, []);

  const checkBackendConnection = async () => {
    setConnectionStatus('checking');
    try {
      const response = await apiClient.get('/api/health');
      setServerInfo(response.data);
      setConnectionStatus('connected');
    } catch (error) {
      console.log('Connection error:', error.message);
      setConnectionStatus('error');
    }
  };

  return (
    <LinearGradient
      colors={colors.gradientBackground}
      locations={[0, 0.5, 1]}
      style={styles.container}
    >
      <ScrollView 
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        {/* Decorative circles */}
        <View style={styles.decorativeCircles}>
          <LinearGradient
            colors={[colors.primary, colors.accent]}
            style={[styles.circle, styles.circle1]}
          />
          <LinearGradient
            colors={[colors.primary, colors.accent]}
            style={[styles.circle, styles.circle2]}
          />
        </View>

        {/* Logo Section */}
        <View style={styles.logoSection}>
          <View style={styles.logoWrapper}>
            <Text style={styles.logoEmoji}>🏋️</Text>
          </View>
          <Text style={styles.brandName}>Exerly</Text>
          <Text style={styles.brandTagline}>Your AI-Powered Fitness Coach</Text>
        </View>

        {/* Connection Status */}
        <View style={styles.statusCard}>
          <Text style={styles.statusTitle}>Backend Status</Text>
          <Text style={styles.apiUrl}>{API_CONFIG.BASE_URL}</Text>
          
          {connectionStatus === 'checking' && (
            <View style={styles.statusRow}>
              <ActivityIndicator color={colors.primary} size="small" />
              <Text style={styles.statusTextChecking}>Connecting...</Text>
            </View>
          )}
          
          {connectionStatus === 'connected' && (
            <View style={styles.statusRow}>
              <View style={[styles.statusDot, styles.statusDotConnected]} />
              <Text style={styles.statusTextConnected}>Connected</Text>
            </View>
          )}
          
          {connectionStatus === 'error' && (
            <View style={styles.statusRow}>
              <View style={[styles.statusDot, styles.statusDotError]} />
              <Text style={styles.statusTextError}>Connection Failed</Text>
            </View>
          )}
        </View>

        {/* Features */}
        <View style={styles.features}>
          <View style={styles.featureItem}>
            <Text style={styles.featureIcon}>💪</Text>
            <Text style={styles.featureText}>Track Workouts</Text>
          </View>
          <View style={styles.featureItem}>
            <Text style={styles.featureIcon}>🍎</Text>
            <Text style={styles.featureText}>Log Nutrition</Text>
          </View>
          <View style={styles.featureItem}>
            <Text style={styles.featureIcon}>😴</Text>
            <Text style={styles.featureText}>Monitor Sleep</Text>
          </View>
          <View style={styles.featureItem}>
            <Text style={styles.featureIcon}>🤖</Text>
            <Text style={styles.featureText}>AI Coach</Text>
          </View>
        </View>

        {/* Action Buttons */}
        <View style={styles.buttonContainer}>
          <TouchableOpacity 
            style={styles.primaryButtonWrapper}
            activeOpacity={0.8}
            onPress={() => navigation.navigate('Login')}
          >
            <LinearGradient
              colors={colors.gradientPrimary}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.primaryButton}
            >
              <Text style={styles.primaryButtonText}>Login</Text>
            </LinearGradient>
          </TouchableOpacity>
          
          <TouchableOpacity 
            style={styles.secondaryButton}
            activeOpacity={0.8}
            onPress={() => navigation.navigate('Signup')}
          >
            <Text style={styles.secondaryButtonText}>Create Account</Text>
          </TouchableOpacity>

          {connectionStatus === 'error' && (
            <TouchableOpacity 
              style={styles.retryButton}
              onPress={checkBackendConnection}
            >
              <Text style={styles.retryButtonText}>🔄 Retry Connection</Text>
            </TouchableOpacity>
          )}
        </View>
      </ScrollView>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scrollContent: {
    flexGrow: 1,
    padding: spacing.lg,
    paddingTop: 80,
    paddingBottom: 40,
  },
  decorativeCircles: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    overflow: 'hidden',
  },
  circle: {
    position: 'absolute',
    borderRadius: 9999,
    opacity: 0.15,
  },
  circle1: {
    width: 300,
    height: 300,
    top: -150,
    right: -150,
  },
  circle2: {
    width: 200,
    height: 200,
    bottom: -100,
    left: -100,
  },
  logoSection: {
    alignItems: 'center',
    marginBottom: spacing.xl,
  },
  logoWrapper: {
    width: 100,
    height: 100,
    borderRadius: 25,
    backgroundColor: 'rgba(139, 92, 246, 0.2)',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: spacing.md,
  },
  logoEmoji: {
    fontSize: 50,
  },
  brandName: {
    fontSize: 48,
    fontWeight: fontWeight.extrabold,
    color: colors.primary,
    marginBottom: spacing.xs,
  },
  brandTagline: {
    fontSize: fontSize.lg,
    color: colors.textSecondary,
    fontWeight: fontWeight.medium,
    textAlign: 'center',
  },
  statusCard: {
    backgroundColor: 'rgba(139, 92, 246, 0.1)',
    borderRadius: borderRadius.lg,
    borderWidth: 1,
    borderColor: 'rgba(139, 92, 246, 0.2)',
    padding: spacing.md,
    marginBottom: spacing.lg,
    alignItems: 'center',
  },
  statusTitle: {
    fontSize: fontSize.sm,
    fontWeight: fontWeight.semibold,
    color: colors.textSecondary,
    marginBottom: spacing.xs,
  },
  apiUrl: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
    fontFamily: 'monospace',
    marginBottom: spacing.sm,
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: spacing.sm,
  },
  statusDotConnected: {
    backgroundColor: colors.success,
  },
  statusDotError: {
    backgroundColor: colors.error,
  },
  statusTextChecking: {
    color: colors.textSecondary,
    fontSize: fontSize.sm,
    marginLeft: spacing.sm,
  },
  statusTextConnected: {
    color: colors.success,
    fontSize: fontSize.sm,
    fontWeight: fontWeight.semibold,
  },
  statusTextError: {
    color: colors.error,
    fontSize: fontSize.sm,
    fontWeight: fontWeight.semibold,
  },
  features: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    marginBottom: spacing.xl,
    gap: spacing.sm,
  },
  featureItem: {
    width: '48%',
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
    borderRadius: borderRadius.md,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.1)',
    padding: spacing.md,
    alignItems: 'center',
  },
  featureIcon: {
    fontSize: 32,
    marginBottom: spacing.xs,
  },
  featureText: {
    fontSize: fontSize.sm,
    color: colors.textSecondary,
    fontWeight: fontWeight.medium,
  },
  buttonContainer: {
    gap: spacing.md,
  },
  primaryButtonWrapper: {
    borderRadius: borderRadius.lg,
    overflow: 'hidden',
    shadowColor: colors.primary,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 15,
    elevation: 8,
  },
  primaryButton: {
    paddingVertical: 18,
    alignItems: 'center',
    borderRadius: borderRadius.lg,
  },
  primaryButtonText: {
    color: colors.textPrimary,
    fontSize: fontSize.lg,
    fontWeight: fontWeight.bold,
  },
  secondaryButton: {
    backgroundColor: 'transparent',
    paddingVertical: 18,
    borderRadius: borderRadius.lg,
    borderWidth: 2,
    borderColor: colors.primary,
    alignItems: 'center',
  },
  secondaryButtonText: {
    color: colors.primary,
    fontSize: fontSize.lg,
    fontWeight: fontWeight.bold,
  },
  retryButton: {
    paddingVertical: spacing.md,
    alignItems: 'center',
  },
  retryButtonText: {
    color: colors.textMuted,
    fontSize: fontSize.sm,
  },
});

