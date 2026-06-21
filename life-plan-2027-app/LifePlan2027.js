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

const ThemeContext = React.createContext(null);

const themeMap = [
  {
    id: 'dawn',
    range: [4, 6],
    background: '#1A1040',
    primaryText: '#C9B8FF',
    accent1: '#7C5CBF',
    accent2: '#A78BFA',
    mutedText: 'rgba(201,184,255,0.55)',
    cardBg: 'rgba(255,255,255,0.08)',
    tealAccent: '#2DD4BF',
  },
  {
    id: 'morning',
    range: [6, 12],
    background: '#FFFFFF',
    primaryText: '#1A1A2E',
    accent1: '#F59E0B',
    accent2: '#38BDF8',
    mutedText: 'rgba(26,26,46,0.55)',
    cardBg: 'rgba(255,255,255,0.08)',
    tealAccent: '#2DD4BF',
  },
  {
    id: 'afternoon',
    range: [12, 16],
    background: '#F3F4F6',
    primaryText: '#111827',
    accent1: '#F97316',
    accent2: '#6B7280',
    mutedText: 'rgba(17,24,39,0.55)',
    cardBg: 'rgba(255,255,255,0.08)',
    tealAccent: '#2DD4BF',
  },
  {
    id: 'evening',
    range: [16, 19],
    background: '#1A1A3E',
    primaryText: '#FCD34D',
    accent1: '#F97316',
    accent2: '#3B82F6',
    mutedText: 'rgba(252,211,77,0.55)',
    cardBg: 'rgba(255,255,255,0.08)',
    tealAccent: '#2DD4BF',
  },
  {
    id: 'night',
    range: [19, 24],
    background: '#12122A',
    primaryText: '#FCD34D',
    accent1: '#2DD4BF',
    accent2: '#1E3A5F',
    mutedText: 'rgba(252,211,77,0.55)',
    cardBg: 'rgba(255,255,255,0.08)',
    tealAccent: '#2DD4BF',
  },
];

const getThemeForHour = hour => {
  const normalizedHour = hour < 0 ? 0 : hour;
  const foundTheme = themeMap.find(({ range }) => normalizedHour >= range[0] && normalizedHour < range[1]);
  if (foundTheme) {
    return foundTheme;
  }
  return themeMap[4];
};

const formatClock = now => {
  const hour = now.getHours();
  const minute = now.getMinutes();
  const period = hour >= 12 ? 'PM' : 'AM';
  const readableHour = hour % 12 === 0 ? 12 : hour % 12;
  return `${readableHour}:${String(minute).padStart(2, '0')} ${period}`;
};

const formatDateLine = now => {
  const weekday = now.toLocaleDateString('en-US', { weekday: 'long' });
  const day = String(now.getDate()).padStart(2, '0');
  const month = now.toLocaleDateString('en-US', { month: 'short' });
  const year = now.getFullYear();
  return { weekday, prettyDate: `${day} ${month} ${year}` };
};

const getDaysTo2027 = now => {
  const target = new Date('2027-01-01T00:00:00');
  const diffMs = target.getTime() - now.getTime();
  return diffMs > 0 ? Math.ceil(diffMs / (1000 * 60 * 60 * 24)) : 0;
};

const prayerItems = [
  { id: 'Tahajjud', icon: '☪' },
  { id: 'Fajr', icon: '🌙' },
  { id: 'Dhuha', icon: '☀' },
  { id: 'Dhuhr', icon: '🕛' },
  { id: 'Asr', icon: '🕓' },
  { id: 'Maghrib', icon: '🌅' },
  { id: 'Isha', icon: '🌃' },
];

const tabItems = ['Today', 'Goals', 'Habits', 'Workout', 'Income'];

const LifePlan2027 = ({ onTabChange }) => {
  const [now, setNow] = useState(new Date());
  const [completedPrayers, setCompletedPrayers] = useState([]);
  const [theme, setTheme] = useState(getThemeForHour(new Date().getHours()));
  const themeTransition = useRef(new Animated.Value(1)).current;
  const previousTheme = useRef(theme);
  const progressAnimation = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    const clockInterval = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(clockInterval);
  }, []);

  useEffect(() => {
    const themeCheck = () => {
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
    themeCheck();
    const interval = setInterval(themeCheck, 60000);
    return () => clearInterval(interval);
  }, [themeTransition]);

  useEffect(() => {
    const progress = completedPrayers.length / prayerItems.length;
    Animated.timing(progressAnimation, {
      toValue: progress,
      duration: 700,
      useNativeDriver: false,
    }).start();
  }, [completedPrayers.length, progressAnimation]);

  const animatedBackground = themeTransition.interpolate({
    inputRange: [0, 1],
    outputRange: [previousTheme.current.background, theme.background],
  });

  const animatedAccent1 = themeTransition.interpolate({
    inputRange: [0, 1],
    outputRange: [previousTheme.current.accent1, theme.accent1],
  });

  const animatedAccent2 = themeTransition.interpolate({
    inputRange: [0, 1],
    outputRange: [previousTheme.current.accent2, theme.accent2],
  });

  const animatedCardBg = themeTransition.interpolate({
    inputRange: [0, 1],
    outputRange: [previousTheme.current.cardBg, theme.cardBg],
  });

  const { weekday, prettyDate } = formatDateLine(now);
  const daysTo2027 = getDaysTo2027(now);
  const prayerProgress = completedPrayers.length;
  const tasksValue = '0/6 today';
  const prayersValue = `${prayerProgress}/7 completed`;

  const styles = useMemo(() => createStyles(theme), [theme]);

  const togglePrayer = id => {
    setCompletedPrayers(prev =>
      prev.includes(id) ? prev.filter(item => item !== id) : [...prev, id]
    );
  };

  return (
    <ThemeContext.Provider value={theme}>
      <Animated.View style={[styles.screen, { backgroundColor: animatedBackground }]}> 
        <StatusBar
          barStyle={theme.background === '#FFFFFF' || theme.id === 'afternoon' ? 'dark-content' : 'light-content'}
          backgroundColor={theme.background}
        />
        <SafeAreaView style={styles.safeArea}>
          <ScrollView contentContainerStyle={styles.scrollArea} showsVerticalScrollIndicator={false}>
            <Text style={styles.bismillahLabel}>BISMILLAH</Text>
            <Animated.Text style={[styles.nameHeader, { color: animatedAccent1 }]}>Rayees</Animated.Text>
            <Text style={styles.subtitle}>Life Plan 2027</Text>

            <Animated.View style={[styles.card, { backgroundColor: animatedCardBg }]}> 
              <View style={styles.clockRow}>
                <Animated.Text style={[styles.clockTime, { color: animatedAccent1 }]}> {formatClock(now)}</Animated.Text>
                <View style={styles.clockMeta}>
                  <Text style={styles.clockLabel}>{weekday}</Text>
                  <Text style={styles.clockLabel}>{prettyDate}</Text>
                </View>
              </View>
            </Animated.View>

            <View style={[styles.card, styles.countdownCard]}>
              <Animated.Text style={[styles.countdownNumber, { color: animatedAccent1 }]}> {daysTo2027} </Animated.Text>
              <Text style={styles.countdownLabel}>DAYS TO 2027</Text>
              <Text style={styles.countdownSubtitle}>Target: 1 January 2027</Text>
            </View>

            <View style={styles.statsRow}>
              <View style={styles.statCard}>
                <Text style={styles.statLabel}>TASKS</Text>
                <Text style={styles.taskValue}>{tasksValue}</Text>
              </View>
              <View style={styles.statCard}>
                <Text style={styles.statLabel}>PRAYERS</Text>
                <Text style={styles.prayerValue}>{prayersValue}</Text>
              </View>
            </View>

            <View style={[styles.card, styles.progressCard]}>
              <View style={styles.progressHeader}>
                <Text style={styles.progressText}>Daily Progress</Text>
                <Text style={styles.progressText}>{Math.round((prayerProgress / prayerItems.length) * 100)}%</Text>
              </View>
              <View style={styles.progressTrack}>
                <Animated.View
                  style={[
                    styles.progressFill,
                    {
                      backgroundColor: animatedAccent1,
                      width: progressAnimation.interpolate({
                        inputRange: [0, 1],
                        outputRange: ['0%', '100%'],
                      }),
                    },
                  ]}
                />
              </View>
            </View>

            <View style={styles.sectionHeader}>
              <Text style={styles.sectionTitle}>Prayer Progress</Text>
            </View>

            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={styles.prayerScroll}
            >
              {prayerItems.map(item => {
                const completed = completedPrayers.includes(item.id);
                return (
                  <PrayerChip
                    key={item.id}
                    prayer={item}
                    completed={completed}
                    onPress={() => togglePrayer(item.id)}
                  />
                );
              })}
            </ScrollView>
          </ScrollView>

          <View style={[styles.tabBar, { backgroundColor: theme.cardBg }]}> 
            {tabItems.map(tab => (
              <TabItem
                key={tab}
                label={tab}
                active={tab === 'Today'}
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

const PrayerChip = ({ prayer, completed, onPress }) => {
  const theme = useContext(ThemeContext);
  const styles = createStyles(theme);

  return (
    <TouchableOpacity
      activeOpacity={0.85}
      onPress={onPress}
      style={[
        styles.prayerChip,
        completed && { borderColor: theme.accent1, backgroundColor: theme.cardBg },
      ]}
    >
      <Text style={[styles.prayerIcon, completed && { color: theme.accent1 }]}>{prayer.icon}</Text>
      <Text style={styles.prayerLabel}>{prayer.id}</Text>
      {completed ? <Text style={styles.checkmark}>✓</Text> : null}
    </TouchableOpacity>
  );
};

const TabItem = ({ label, active, onPress }) => {
  const theme = useContext(ThemeContext);
  const styles = createStyles(theme);
  return (
    <TouchableOpacity style={styles.tabItem} activeOpacity={0.75} onPress={onPress}>
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
    scrollArea: {
      paddingHorizontal: 24,
      paddingBottom: 100,
    },
    bismillahLabel: {
      marginTop: 24,
      fontSize: 11,
      letterSpacing: 4,
      textAlign: 'center',
      color: theme.accent1,
    },
    nameHeader: {
      marginTop: 4,
      fontSize: 42,
      fontWeight: '800',
      textAlign: 'center',
      color: theme.primaryText,
    },
    subtitle: {
      marginTop: 6,
      fontSize: 14,
      textAlign: 'center',
      color: theme.mutedText,
      marginBottom: 24,
    },
    card: {
      borderRadius: 22,
      padding: 20,
      marginBottom: 18,
      borderWidth: 1,
      borderColor: theme.cardBg,
    },
    clockRow: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'space-between',
    },
    clockTime: {
      fontSize: 32,
      fontWeight: '800',
    },
    clockMeta: {
      alignItems: 'flex-end',
    },
    clockLabel: {
      fontSize: 13,
      color: theme.mutedText,
    },
    countdownCard: {
      alignItems: 'center',
    },
    countdownNumber: {
      fontSize: 64,
      fontWeight: '800',
      textAlign: 'center',
    },
    countdownLabel: {
      marginTop: 10,
      fontSize: 11,
      letterSpacing: 3,
      textAlign: 'center',
      color: theme.mutedText,
    },
    countdownSubtitle: {
      marginTop: 6,
      fontSize: 12,
      textAlign: 'center',
      color: theme.mutedText,
    },
    statsRow: {
      flexDirection: 'row',
      justifyContent: 'space-between',
      gap: 12,
    },
    statCard: {
      flex: 1,
      borderRadius: 20,
      backgroundColor: theme.cardBg,
      padding: 18,
      borderWidth: 1,
      borderColor: theme.cardBg,
    },
    statLabel: {
      fontSize: 11,
      letterSpacing: 2,
      textTransform: 'uppercase',
      color: theme.mutedText,
      marginBottom: 10,
    },
    taskValue: {
      fontSize: 22,
      fontWeight: '800',
      color: theme.tealAccent,
    },
    prayerValue: {
      fontSize: 22,
      fontWeight: '800',
      color: theme.primaryText,
    },
    progressCard: {
      marginBottom: 22,
    },
    progressHeader: {
      flexDirection: 'row',
      justifyContent: 'space-between',
      alignItems: 'center',
      marginBottom: 12,
    },
    progressText: {
      fontSize: 13,
      color: theme.mutedText,
    },
    progressTrack: {
      height: 8,
      borderRadius: 999,
      backgroundColor: theme.accent2 + '33',
      overflow: 'hidden',
    },
    progressFill: {
      height: 8,
      borderRadius: 999,
      backgroundColor: theme.accent1,
    },
    sectionHeader: {
      marginBottom: 10,
    },
    sectionTitle: {
      fontSize: 14,
      fontWeight: '700',
      color: theme.primaryText,
    },
    prayerScroll: {
      paddingVertical: 8,
      paddingHorizontal: 2,
    },
    prayerChip: {
      minWidth: 90,
      marginRight: 12,
      paddingVertical: 16,
      paddingHorizontal: 12,
      borderRadius: 18,
      backgroundColor: theme.cardBg,
      borderWidth: 1,
      borderColor: theme.cardBg,
      alignItems: 'center',
      justifyContent: 'center',
      position: 'relative',
    },
    prayerIcon: {
      fontSize: 20,
      color: theme.primaryText,
      marginBottom: 8,
    },
    prayerLabel: {
      fontSize: 10,
      color: theme.mutedText,
      textAlign: 'center',
    },
    checkmark: {
      position: 'absolute',
      top: 8,
      right: 8,
      fontSize: 12,
      color: theme.tealAccent,
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
      paddingHorizontal: 16,
      borderWidth: 1,
      borderColor: theme.cardBg,
    },
    tabItem: {
      alignItems: 'center',
      flex: 1,
    },
    tabLabel: {
      fontSize: 11,
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

export default LifePlan2027;
export { ThemeContext, getThemeForHour };
