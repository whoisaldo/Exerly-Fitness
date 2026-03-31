import React, { useState, useEffect, useCallback, useRef } from 'react';
import { View, ActivityIndicator, StyleSheet } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { StatusBar } from 'expo-status-bar';
import { useAuth } from '../context/AuthContext';
import { isOnboardingComplete, loadProgress } from '../services/WizardService';
import { colors } from '../theme/colors';
import AuthStack from './AuthStack';
import MainNavigator from './MainNavigator';
import OnboardingWizard from '../screens/onboarding/OnboardingWizard';

export default function RootNavigator() {
  const { isLoading, isLoggedIn } = useAuth();
  const [onboardingDone, setOnboardingDone] = useState(null);
  const [resumeData, setResumeData] = useState(null);
  const checkedRef = useRef(false);

  useEffect(() => {
    if (!isLoggedIn || checkedRef.current) return;
    checkedRef.current = true;

    (async () => {
      const done = await isOnboardingComplete();
      if (done) {
        setOnboardingDone(true);
      } else {
        const progress = await loadProgress();
        setResumeData(progress);
        setOnboardingDone(false);
      }
    })();
  }, [isLoggedIn]);

  // Reset check when logged out so re-login re-checks
  useEffect(() => {
    if (!isLoggedIn) {
      checkedRef.current = false;
      setOnboardingDone(null);
      setResumeData(null);
    }
  }, [isLoggedIn]);

  const handleOnboardingComplete = useCallback(() => {
    setOnboardingDone(true);
  }, []);

  if (isLoading) {
    return (
      <View style={styles.loader}>
        <ActivityIndicator size="large" color={colors.primary} />
      </View>
    );
  }

  if (!isLoggedIn) {
    return (
      <NavigationContainer>
        <StatusBar style="light" />
        <AuthStack />
      </NavigationContainer>
    );
  }

  if (onboardingDone === null) {
    return (
      <View style={styles.loader}>
        <ActivityIndicator size="large" color={colors.primary} />
      </View>
    );
  }

  if (!onboardingDone) {
    return (
      <>
        <StatusBar style="light" />
        <OnboardingWizard
          initialStep={resumeData?.step ?? 0}
          initialData={resumeData?.data}
          onComplete={handleOnboardingComplete}
        />
      </>
    );
  }

  return (
    <NavigationContainer>
      <StatusBar style="light" />
      <MainNavigator />
    </NavigationContainer>
  );
}

const styles = StyleSheet.create({
  loader: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: colors.deep,
  },
});
