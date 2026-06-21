import React, { useContext, useEffect, useMemo, useRef, useState } from 'react';
import {
  Animated,
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { ThemeContext, getThemeForHour } from './LifePlan2027';

const RULES = [
  'Use the phone only for productive work.',
  'All 7 prayers. Tahajjud to Isha.',
  'Stay healthy.',
  'TIA Portal 2 hours every morning.',
  'Make 7 lakh rupees minimum in a week.',
];

const DAILY_TARGET = 10000;
const MONTHLY_TARGET = 300000;
const TAB_ITEMS = ['Today', 'Goals', 'Habits', 'Workout', 'Income'];
const TAB_ICONS = {
  Today: '🏠',
  Goals: '🎯',
  Habits: '📈',
  Workout: '🏋️',
  Income: '💰',
};

const IncomeScreen = ({ onTabChange }) => {
  const [now, setNow] = useState(new Date());
  const [theme, setTheme] = useState(getThemeForHour(new Date().getHours()));
  const themeTransition = useRef(new Animated.Value(1)).current;
  const previousTheme = useRef(theme);

  useEffect(() => {
    const clockInterval = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(clockInterval);
  }, []);

  useEffect(() => {
    const refreshTheme = () => {
      const nextTheme = getThemeForHour(new Date().getHours());
      setTheme(current => {
        if (current.id === nextTheme.id) {
          return current;
        }
        previousTheme.current = current;
        themeTransition.setValue(0);
        Animated.timing(themeTransition, {
          toValue: 1,
          duration: 900,
          useNativeDriver: false,
        }).start();
        return nextTheme;
      });
    };

    refreshTheme();
    const themeInterval = setInterval(refreshTheme, 60000);
    return () => clearInterval(themeInterval);
  }, [themeTransition]);

  const animatedBackground = themeTransition.interpolate({
    inputRange: [0, 1],
    outputRange: [previousTheme.current.background, theme.background],
  });

  const animatedAccent1 = themeTransition.interpolate({
    inputRange: [0, 1],
    outputRange: [previousTheme.current.accent1, theme.accent1],
  });

  const animatedCardBg = themeTransition.interpolate({
    inputRange: [0, 1],
    outputRange: [previousTheme.current.cardBg, theme.cardBg],
  });

  const styles = useMemo(() => createStyles(theme), [theme]);

  return (
    <ThemeContext.Provider value={theme}>
      <Animated.View style={[styles.screen, { backgroundColor: animatedBackground }]}> 
        <StatusBar
          barStyle={theme.id === 'morning' || theme.id === 'afternoon' ? 'dark-content' : 'light-content'}
          backgroundColor={theme.background}
        />
        <SafeAreaView style={styles.safeArea}>
          <ScrollView contentContainerStyle={styles.container} showsVerticalScrollIndicator={false}>
            <Text style={styles.pageTitle}>Rs 10K/day Plan</Text>
            <Text style={styles.pageSubtitle}>Automation career to Rs 3 lakhs/month</Text>

            <Animated.View style={[styles.heroCard, { backgroundColor: animatedCardBg }]}> 
              <Animated.Text style={[styles.heroAmount, { color: animatedAccent1 }]}>Rs {DAILY_TARGET.toLocaleString()}</Animated.Text>
              <Text style={styles.heroSubtitle}>per day – Rs {MONTHLY_TARGET.toLocaleString()} per month</Text>
            </Animated.View>

            <Text style={styles.sectionLabel}>NON-NEGOTIABLE RULES</Text>

            <ScrollView
              style={styles.rulesScroll}
              contentContainerStyle={styles.rulesContent}
              nestedScrollEnabled
              showsVerticalScrollIndicator={false}
            >
              {RULES.map((rule, index) => (
                <RuleCard key={rule} index={index + 1} rule={rule} />
              ))}
            </ScrollView>
          </ScrollView>

          <View style={[styles.tabBar, { backgroundColor: theme.cardBg }]}> 
            {TAB_ITEMS.map(tab => (
              <TabItem
                key={tab}
                label={tab}
                icon={TAB_ICONS[tab]}
                active={tab === 'Income'}
                onPress={() => {
                  if (tab === 'Income') {
                    onTabChange?.('income');
                  } else if (tab === 'Today') {
                    onTabChange?.('today');
                  }
                }}
              />
            ))}
          </View>
        </SafeAreaView>
      </Animated.View>
    </ThemeContext.Provider>
  );
};

const RuleCard = ({ index, rule }) => {
  const theme = useContext(ThemeContext);
  const styles = createStyles(theme);

  return (
    <View style={styles.ruleCard}>
      <View style={[styles.ruleBadge, { backgroundColor: theme.accent1 + '33' }]}> 
        <Text style={[styles.ruleNumber, { color: theme.accent1 }]}>{index}</Text>
      </View>
      <Text style={styles.ruleText}>{rule}</Text>
    </View>
  );
};

const TabItem = ({ label, icon, active, onPress }) => {
  const theme = useContext(ThemeContext);
  const styles = createStyles(theme);

  return (
    <TouchableOpacity style={styles.tabItem} activeOpacity={0.8} onPress={onPress}>
      <Text style={[styles.tabIcon, { color: active ? theme.accent1 : theme.mutedText }]}>{icon}</Text>
      <Text style={[styles.tabLabel, { color: active ? theme.accent1 : theme.mutedText }]}>{label}</Text>
      {active ? <View style={[styles.tabDot, { backgroundColor: theme.accent1 }]} /> : null}
    </TouchableOpacity>
  );
};

const createStyles = theme =>
  StyleSheet.create({
    screen: {
      flex: 1,
    },
    safeArea: {
      flex: 1,
    },
    container: {
      paddingHorizontal: 24,
      paddingTop: 24,
      paddingBottom: 18,
    },
    pageTitle: {
      fontSize: 32,
      fontWeight: '800',
      color: theme.primaryText,
      marginTop: 24,
      marginBottom: 8,
      textAlign: 'center',
    },
    pageSubtitle: {
      fontSize: 14,
      color: theme.mutedText,
      marginBottom: 24,
      textAlign: 'center',
    },
    heroCard: {
      borderRadius: 20,
      paddingVertical: 32,
      paddingHorizontal: 24,
      alignItems: 'center',
      justifyContent: 'center',
      marginBottom: 28,
    },
    heroAmount: {
      fontSize: 52,
      fontWeight: '800',
      textAlign: 'center',
    },
    heroSubtitle: {
      marginTop: 8,
      fontSize: 14,
      color: theme.mutedText,
      textAlign: 'center',
    },
    sectionLabel: {
      fontSize: 11,
      letterSpacing: 3,
      textTransform: 'uppercase',
      color: theme.mutedText,
      marginBottom: 14,
    },
    rulesScroll: {
      marginBottom: 24,
    },
    rulesContent: {
      paddingBottom: 24,
    },
    ruleCard: {
      flexDirection: 'row',
      alignItems: 'center',
      backgroundColor: theme.cardBg,
      borderRadius: 16,
      paddingVertical: 14,
      paddingHorizontal: 16,
      marginBottom: 12,
    },
    ruleBadge: {
      width: 32,
      height: 32,
      borderRadius: 8,
      justifyContent: 'center',
      alignItems: 'center',
    },
    ruleNumber: {
      fontSize: 14,
      fontWeight: '700',
    },
    ruleText: {
      flex: 1,
      marginLeft: 14,
      color: theme.primaryText,
      fontSize: 15,
      lineHeight: 22,
    },
    tabBar: {
      position: 'absolute',
      left: 12,
      right: 12,
      bottom: 18,
      borderRadius: 22,
      flexDirection: 'row',
      justifyContent: 'space-between',
      alignItems: 'center',
      paddingVertical: 12,
      paddingHorizontal: 12,
      borderWidth: 1,
      borderColor: theme.cardBg,
    },
    tabItem: {
      flex: 1,
      alignItems: 'center',
    },
    tabIcon: {
      fontSize: 18,
      marginBottom: 4,
    },
    tabLabel: {
      fontSize: 10,
      fontWeight: '700',
      letterSpacing: 0.5,
    },
    tabDot: {
      width: 6,
      height: 6,
      borderRadius: 3,
      marginTop: 6,
    },
  });

export default IncomeScreen;
