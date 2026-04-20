import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';

import PhoneEntryScreen from '../screens/PhoneEntryScreen';
import OtpScreen from '../screens/OtpScreen';
import ProfileCreationScreen from '../screens/ProfileCreationScreen';
import HomeScreen from '../screens/HomeScreen';
import GroupDetailScreen from '../screens/GroupDetailScreen';
import GroupCreationScreen from '../screens/GroupCreationScreen';
import ProfileScreen from '../screens/ProfileScreen';

// ------------------------------------------------------------------
// Type definitions — every route and its params in one place.
// React Navigation uses these to give you autocomplete + type errors
// when you navigate (e.g., navigate('GroupDetail', { groupId: '...' }))
// ------------------------------------------------------------------
export type AuthStackParamList = {
  PhoneEntry: undefined;           // no params needed
  Otp: { phoneNumber: string };    // OTP screen needs to know which phone to verify
  ProfileCreation: undefined;
};

export type HomeStackParamList = {
  Home: undefined;
  GroupDetail: { groupId: string };
  GroupCreation: undefined;
};

export type TabParamList = {
  HomeTab: undefined;
  ProfileTab: undefined;
};

// ------------------------------------------------------------------
// Stack navigators — screens that slide left-to-right
// ------------------------------------------------------------------
const AuthStack = createNativeStackNavigator<AuthStackParamList>();
const HomeStack = createNativeStackNavigator<HomeStackParamList>();
const Tab = createBottomTabNavigator<TabParamList>();

function AuthNavigator() {
  return (
    <AuthStack.Navigator screenOptions={{ headerShown: false }}>
      <AuthStack.Screen name="PhoneEntry" component={PhoneEntryScreen} />
      <AuthStack.Screen name="Otp" component={OtpScreen} />
      <AuthStack.Screen name="ProfileCreation" component={ProfileCreationScreen} />
    </AuthStack.Navigator>
  );
}

// HomeNavigator is a stack nested inside the Home tab.
// This lets us push GroupDetail on top of the group list
// while keeping the tab bar visible (the tab bar lives one level up).
function HomeNavigator() {
  return (
    <HomeStack.Navigator>
      <HomeStack.Screen name="Home" component={HomeScreen} options={{ title: 'Your Groups' }} />
      <HomeStack.Screen name="GroupDetail" component={GroupDetailScreen} options={{ title: 'Group' }} />
      <HomeStack.Screen name="GroupCreation" component={GroupCreationScreen} options={{ title: 'Create Group' }} />
    </HomeStack.Navigator>
  );
}

function MainTabs() {
  return (
    <Tab.Navigator>
      <Tab.Screen name="HomeTab" component={HomeNavigator} options={{ title: 'Home', headerShown: false }} />
      <Tab.Screen name="ProfileTab" component={ProfileScreen} options={{ title: 'Profile' }} />
    </Tab.Navigator>
  );
}

// ------------------------------------------------------------------
// Root navigator — decides: show auth flow or main app?
// For now, isAuthenticated is hardcoded false so we can see auth screens.
// We'll replace this with real auth state once Clerk is wired up.
// ------------------------------------------------------------------
export default function RootNavigator() {
  const isAuthenticated = false;

  return (
    <NavigationContainer>
      {isAuthenticated ? <MainTabs /> : <AuthNavigator />}
    </NavigationContainer>
  );
}
