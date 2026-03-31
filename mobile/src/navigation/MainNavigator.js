import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { colors } from '../theme/colors';
import CustomTabBar from './CustomTabBar';

import HomeScreen from '../screens/HomeScreen';
import ProgressScreen from '../screens/ProgressScreen';
import SocialScreen from '../screens/SocialScreen';
import ProfileScreen from '../screens/ProfileScreen';
import LogActivityScreen from '../screens/LogActivityScreen';
import LogFoodScreen from '../screens/LogFoodScreen';
import LogSleepScreen from '../screens/LogSleepScreen';
import AICoachScreen from '../screens/AICoachScreen';
import NotificationsScreen from '../screens/NotificationsScreen';

const Tab = createBottomTabNavigator();
const RootStack = createNativeStackNavigator();

function TabNavigator() {
  return (
    <Tab.Navigator
      tabBar={(props) => <CustomTabBar {...props} />}
      screenOptions={{
        headerShown: false,
        tabBarStyle: { display: 'none' },
      }}
    >
      <Tab.Screen name="Home" component={HomeScreen} />
      <Tab.Screen name="Progress" component={ProgressScreen} />
      <Tab.Screen name="Social" component={SocialScreen} />
      <Tab.Screen name="Profile" component={ProfileScreen} />
    </Tab.Navigator>
  );
}

export default function MainNavigator() {
  return (
    <RootStack.Navigator
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: colors.deep },
      }}
    >
      <RootStack.Screen name="Tabs" component={TabNavigator} />
      <RootStack.Screen
        name="LogActivity"
        component={LogActivityScreen}
        options={{ presentation: 'modal', animation: 'slide_from_bottom' }}
      />
      <RootStack.Screen
        name="LogFood"
        component={LogFoodScreen}
        options={{ presentation: 'modal', animation: 'slide_from_bottom' }}
      />
      <RootStack.Screen
        name="LogSleep"
        component={LogSleepScreen}
        options={{ presentation: 'modal', animation: 'slide_from_bottom' }}
      />
      <RootStack.Screen
        name="AICoach"
        component={AICoachScreen}
        options={{ animation: 'slide_from_right' }}
      />
      <RootStack.Screen
        name="Notifications"
        component={NotificationsScreen}
        options={{ animation: 'slide_from_right' }}
      />
    </RootStack.Navigator>
  );
}
