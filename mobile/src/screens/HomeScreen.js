import React, { useState, useEffect } from 'react';
import {
  StyleSheet,
  Text,
  View,
  TouchableOpacity,
  ActivityIndicator,
  ScrollView,
  Dimensions,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { colors, spacing, borderRadius, fontSize, fontWeight } from '../theme/colors';
import API_CONFIG from '../config';
import apiClient from '../api/client';

const { width } = Dimensions.get('window');

export default function HomeScreen({ navigation }) {
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
        {/* Decorative circles (matching web) */}
        <View style={styles.decorativeCircles}>
          <LinearGradient
            colors={[colors.primary, colors.accent]}
            style={[styles.circle, styles.circle1]}
          />
          <LinearGradient
            colors={[colors.primary, colors.accent]}
            style={[styles.circle, styles.circle2]}
          />
          <LinearGradient
            colors={[colors.primary, colors.accent]}
            style={[styles.circle, styles.circle3]}
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

        {/* Connection Status Card */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Backend Connection</Text>
          <Text style={styles.apiUrl}>{API_CONFIG.BASE_URL}</Text>
          
          <View style={styles.statusContainer}>
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

          {serverInfo && (
            <View style={styles.serverInfo}>
              <View style={styles.infoRow}>
                <Text style={styles.infoLabel}>Status:</Text>
                <Text style={styles.infoValue}>{serverInfo.status}</Text>
              </View>
              <View style={styles.infoRow}>
                <Text style={styles.infoLabel}>Database:</Text>
                <Text style={styles.infoValue}>{serverInfo.database?.type || serverInfo.database?.status}</Text>
              </View>
              <View style={styles.infoRow}>
                <Text style={styles.infoLabel}>Mode:</Text>
                <Text style={styles.infoValue}>{serverInfo.mode || 'Production'}</Text>
              </View>
            </View>
          )}
        </View>

        {/* Quick Stats Preview */}
        <View style={styles.statsPreview}>
          <View style={styles.statCard}>
            <Text style={styles.statEmoji}>💪</Text>
            <Text style={styles.statLabel}>Workouts</Text>
          </View>
          <View style={styles.statCard}>
            <Text style={styles.statEmoji}>🍎</Text>
            <Text style={styles.statLabel}>Nutrition</Text>
          </View>
          <View style={styles.statCard}>
            <Text style={styles.statEmoji}>😴</Text>
            <Text style={styles.statLabel}>Sleep</Text>
          </View>
        </View>

        {/* Action Buttons */}
        <View style={styles.buttonContainer}>
          <TouchableOpacity 
            style={styles.primaryButtonWrapper}
            activeOpacity={0.8}
            onPress={() => {/* Navigate to Login */}}
          >
            <LinearGradient
              colors={colors.gradientPrimary}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.primaryButton}
            >
              <Text style={styles.primaryButtonText}>Get Started</Text>
            </LinearGradient>
          </TouchableOpacity>
          
          <TouchableOpacity 
            style={styles.secondaryButton}
            activeOpacity={0.8}
            onPress={checkBackendConnection}
          >
            <Text style={styles.secondaryButtonText}>Retry Connection</Text>
          </TouchableOpacity>
        </View>

        {/* Dev Info */}
        <View style={styles.devInfo}>
          <Text style={styles.devText}>📱 Mobile App v1.0.0</Text>
          <Text style={styles.devText}>
            {__DEV__ ? '🔧 Development Mode' : '🚀 Production Mode'}
          </Text>
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
    paddingTop: 60,
    paddingBottom: 40,
  },
  
  // Decorative circles
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
  circle3: {
    width: 150,
    height: 150,
    top: '50%',
    left: -75,
  },

  // Logo Section
  logoSection: {
    alignItems: 'center',
    marginBottom: spacing.xl,
  },
  logoWrapper: {
    width: 80,
    height: 80,
    borderRadius: 20,
    backgroundColor: 'rgba(139, 92, 246, 0.2)',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: spacing.md,
    shadowColor: colors.primary,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 12,
  },
  logoEmoji: {
    fontSize: 40,
  },
  brandName: {
    fontSize: 40,
    fontWeight: fontWeight.extrabold,
    color: colors.primary,
    marginBottom: spacing.xs,
  },
  brandTagline: {
    fontSize: fontSize.md,
    color: colors.textSecondary,
    fontWeight: fontWeight.medium,
  },

  // Card
  card: {
    backgroundColor: 'rgba(139, 92, 246, 0.1)',
    borderRadius: borderRadius.xl,
    borderWidth: 1,
    borderColor: 'rgba(139, 92, 246, 0.2)',
    padding: spacing.lg,
    marginBottom: spacing.lg,
  },
  cardTitle: {
    fontSize: fontSize.lg,
    fontWeight: fontWeight.semibold,
    color: colors.textPrimary,
    marginBottom: spacing.xs,
  },
  apiUrl: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
    fontFamily: 'monospace',
    marginBottom: spacing.md,
  },
  
  // Status
  statusContainer: {
    marginTop: spacing.sm,
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginRight: spacing.sm,
  },
  statusDotConnected: {
    backgroundColor: colors.success,
    shadowColor: colors.success,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.8,
    shadowRadius: 4,
  },
  statusDotError: {
    backgroundColor: colors.error,
    shadowColor: colors.error,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.8,
    shadowRadius: 4,
  },
  statusTextChecking: {
    color: colors.textSecondary,
    fontSize: fontSize.md,
    marginLeft: spacing.sm,
  },
  statusTextConnected: {
    color: colors.success,
    fontSize: fontSize.md,
    fontWeight: fontWeight.semibold,
  },
  statusTextError: {
    color: colors.error,
    fontSize: fontSize.md,
    fontWeight: fontWeight.semibold,
  },

  // Server Info
  serverInfo: {
    marginTop: spacing.md,
    paddingTop: spacing.md,
    borderTopWidth: 1,
    borderTopColor: 'rgba(139, 92, 246, 0.2)',
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: spacing.xs,
  },
  infoLabel: {
    fontSize: fontSize.sm,
    color: colors.textMuted,
  },
  infoValue: {
    fontSize: fontSize.sm,
    color: colors.textSecondary,
    fontWeight: fontWeight.medium,
  },

  // Stats Preview
  statsPreview: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: spacing.xl,
    gap: spacing.sm,
  },
  statCard: {
    flex: 1,
    backgroundColor: 'rgba(255, 255, 255, 0.05)',
    borderRadius: borderRadius.lg,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.1)',
    padding: spacing.md,
    alignItems: 'center',
  },
  statEmoji: {
    fontSize: 28,
    marginBottom: spacing.xs,
  },
  statLabel: {
    fontSize: fontSize.xs,
    color: colors.textMuted,
    fontWeight: fontWeight.medium,
  },

  // Buttons
  buttonContainer: {
    gap: spacing.md,
    marginBottom: spacing.xl,
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
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.lg,
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
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.lg,
    borderRadius: borderRadius.lg,
    borderWidth: 1,
    borderColor: colors.primary,
    alignItems: 'center',
  },
  secondaryButtonText: {
    color: colors.primary,
    fontSize: fontSize.md,
    fontWeight: fontWeight.semibold,
  },

  // Dev Info
  devInfo: {
    alignItems: 'center',
    marginTop: 'auto',
    paddingTop: spacing.lg,
  },
  devText: {
    fontSize: fontSize.xs,
    color: 'rgba(167, 139, 250, 0.5)',
    marginBottom: spacing.xs,
  },
});
