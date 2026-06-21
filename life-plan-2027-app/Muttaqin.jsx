import React, { useState, useEffect } from 'react';

const C = {
  bg: '#0a1a0f',
  bgLight: '#f5f0e8',
  card: '#112318',
  cardLight: '#ffffff',
  green: '#1a6b3a',
  greenLight: '#22c55e',
  gold: '#d4a017',
  goldLight: '#fbbf24',
  text: '#f0ead6',
  textLight: '#1a1a2e',
  muted: '#6b8f71',
  mutedLight: '#9ca3af',
  border: '#1e3d28',
  borderLight: '#e5e7eb',
  teal: '#0d9488',
  red: '#ef4444',
  blue: '#3b82f6',
  orange: '#f97316',
};

const TABS = [
  { id: 'workout', icon: '🏋️', label: 'Workout' },
  { id: 'habits', icon: '📅', label: 'Habits' },
];

const WORKOUT_DAYS = [
  {
    id: 'day1',
    title: 'Push Day',
    subtitle: 'Chest, shoulders & triceps',
    exercises: [
      { id: 'bench_press', name: 'Barbell Bench Press', sets: 4, reps: 10 },
      { id: 'incline_press', name: 'Incline DB Press', sets: 3, reps: 12 },
      { id: 'shoulder_press', name: 'Standing Shoulder Press', sets: 3, reps: 10 },
      { id: 'tricep_dips', name: 'Tricep Dips', sets: 3, reps: 12 },
    ],
  },
  {
    id: 'day2',
    title: 'Pull Day',
    subtitle: 'Back, biceps & rear delts',
    exercises: [
      { id: 'pull_ups', name: 'Pull Ups', sets: 4, reps: 8 },
      { id: 'barbell_row', name: 'Bent-over Row', sets: 4, reps: 10 },
      { id: 'face_pull', name: 'Face Pulls', sets: 3, reps: 15 },
      { id: 'bicep_curl', name: 'Bicep Curls', sets: 3, reps: 12 },
    ],
  },
  {
    id: 'day3',
    title: 'Leg Day',
    subtitle: 'Quads, glutes & hamstrings',
    exercises: [
      { id: 'squat', name: 'Back Squat', sets: 4, reps: 10 },
      { id: 'romanian_deadlift', name: 'Romanian Deadlift', sets: 3, reps: 10 },
      { id: 'walking_lunge', name: 'Walking Lunges', sets: 3, reps: 12 },
      { id: 'calf_raise', name: 'Calf Raises', sets: 3, reps: 20 },
    ],
  },
  {
    id: 'day4',
    title: 'Core + Full Body',
    subtitle: 'Strength, stability & conditioning',
    exercises: [
      { id: 'deadlift', name: 'Deadlift', sets: 4, reps: 6 },
      { id: 'plank_walkout', name: 'Plank Walkouts', sets: 3, reps: 10 },
      { id: 'leg_raise', name: 'Hanging Leg Raises', sets: 3, reps: 12 },
      { id: 'farmers_carry', name: 'Farmer Carry', sets: 3, reps: 30 },
    ],
  },
];

const STORAGE_KEYS = {
  workout: 'muttaqin_workout',
  history: 'muttaqin_history',
  lastDate: 'muttaqin_lastDate',
  water: 'muttaqin_water',
  prayers: 'muttaqin_prayers',
  tasks: 'muttaqin_tasks',
  sunnah: 'muttaqin_sunnah',
};

const WATER_GOAL = 8;

const DEFAULT_PRAYERS = [
  { id: 'fajr', label: 'Fajr', done: false },
  { id: 'dhuhr', label: 'Dhuhr', done: false },
  { id: 'asr', label: 'Asr', done: false },
  { id: 'maghrib', label: 'Maghrib', done: false },
  { id: 'isha', label: 'Isha', done: false },
];

const DEFAULT_TASKS = [
  { id: 'quran', label: 'Quran review', done: false },
  { id: 'dhikr', label: 'Morning dhikr', done: false },
  { id: 'study', label: 'Study a beneficial lesson', done: false },
];

const getTodayKey = () => new Date().toISOString().slice(0, 10);

const loadStorage = (key, fallback) => {
  try {
    const raw = window.storage?.getItem?.(key) ?? localStorage.getItem(key);
    return raw ? JSON.parse(raw) : fallback;
  } catch {
    return fallback;
  }
};

const saveStorage = (key, value) => {
  try {
    const raw = JSON.stringify(value);
    if (window.storage?.setItem) {
      window.storage.setItem(key, raw);
    } else {
      localStorage.setItem(key, raw);
    }
  } catch {
    // ignore
  }
};

const normalizeWorkout = (value) => {
  if (!Array.isArray(value)) return null;
  return value.map((day) => ({
    ...day,
    exercises: Array.isArray(day.exercises)
      ? day.exercises.map((ex) => {
          if (Array.isArray(ex.sessions)) {
            return {
              ...ex,
              totalDone: typeof ex.totalDone === 'number' ? ex.totalDone : ex.sessions.reduce((sum, n) => sum + n, 0),
            };
          }
          if (typeof ex.done === 'number' && typeof ex.remaining === 'number') {
            return {
              ...ex,
              sessions: [ex.done || 0],
              totalDone: ex.done || 0,
            };
          }
          return {
            ...ex,
            sessions: Array.isArray(ex.sessions) ? ex.sessions : [],
            totalDone: typeof ex.totalDone === 'number' ? ex.totalDone : 0,
          };
        })
      : [],
  }));
};

const buildDefaultWorkout = () =>
  WORKOUT_DAYS.map((day) => ({
    ...day,
    exercises: day.exercises.map((ex) => ({
      ...ex,
      sessions: [],
      totalDone: 0,
    })),
  }));

const buildDefaultPrayers = () => DEFAULT_PRAYERS.map((item) => ({ ...item }));
const buildDefaultTasks = () => DEFAULT_TASKS.map((item) => ({ ...item }));
const buildDefaultSunnah = () => 0;

const formatPercent = (value) => `${Math.round(value)}%`;

export default function App() {
  const [dark, setDark] = useState(true);
  const [tab, setTab] = useState('workout');
  const [workoutData, setWorkoutData] = useState(() => {
    const stored = normalizeWorkout(loadStorage(STORAGE_KEYS.workout, null));
    return stored || buildDefaultWorkout();
  });
  const [habitsHistory, setHabitsHistory] = useState(() => loadStorage(STORAGE_KEYS.history, []));
  const [lastSavedDate, setLastSavedDate] = useState(() => loadStorage(STORAGE_KEYS.lastDate, getTodayKey()));
  const [resumedToday, setResumedToday] = useState(false);
  const [expandedDays, setExpandedDays] = useState(() =>
    WORKOUT_DAYS.reduce((acc, day) => ({ ...acc, [day.id]: true }), {})
  );
  const [repsInputs, setRepsInputs] = useState({});
  const [water, setWater] = useState(() => loadStorage(STORAGE_KEYS.water, 0));
  const [prayers, setPrayers] = useState(() => loadStorage(STORAGE_KEYS.prayers, buildDefaultPrayers()));
  const [tasks, setTasks] = useState(() => loadStorage(STORAGE_KEYS.tasks, buildDefaultTasks()));
  const [sunnah, setSunnah] = useState(() => loadStorage(STORAGE_KEYS.sunnah, buildDefaultSunnah()));

  const themeBg = dark ? C.bg : C.bgLight;
  const themeText = dark ? C.text : C.textLight;
  const themeCard = dark ? C.card : C.cardLight;
  const themeMuted = dark ? C.muted : C.mutedLight;

  const calculateTotals = (data) => {
    const totalTarget = data.reduce(
      (acc, day) => acc + day.exercises.reduce((sum, ex) => sum + ex.sets * ex.reps, 0),
      0
    );
    const totalDone = data.reduce(
      (acc, day) => acc + day.exercises.reduce((sum, ex) => sum + ex.totalDone, 0),
      0
    );
    return { totalTarget, totalDone };
  };

  const todaysTotals = calculateTotals(workoutData);
  const overallProgress = todaysTotals.totalTarget ? (todaysTotals.totalDone / todaysTotals.totalTarget) * 100 : 0;

  const prayerDoneCount = prayers.filter((item) => item.done).length;
  const taskDoneCount = tasks.filter((item) => item.done).length;
  const waterPercent = Math.min(100, (Math.min(water, WATER_GOAL) / WATER_GOAL) * 100);
  const taqwaScore = Math.round(
    (prayerDoneCount / DEFAULT_PRAYERS.length) * 50 +
      (taskDoneCount / DEFAULT_TASKS.length) * 30 +
      (Math.min(water, WATER_GOAL) / WATER_GOAL) * 20
  );

  const getCalendarDays = () => {
    const days = [];
    const today = new Date();
    for (let i = 27; i >= 0; i -= 1) {
      const d = new Date();
      d.setDate(today.getDate() - i);
      days.push(d);
    }
    return days;
  };

  const calendarDays = getCalendarDays();

  const findHistoryEntry = (date) => habitsHistory.find((entry) => entry.date === date);

  const getDayColor = (percent) => {
    if (percent >= 90) return C.gold;
    if (percent >= 70) return C.greenLight;
    if (percent >= 40) return C.gold + '66';
    if (percent > 0) return C.red + '66';
    return themeCard;
  };

  const handleDailyReset = (todayKey) => {
    if (lastSavedDate && lastSavedDate !== todayKey) {
      const { totalTarget, totalDone } = calculateTotals(workoutData);
      const completion = totalTarget ? Math.round((totalDone / totalTarget) * 100) : 0;
      const nextHistory = [...habitsHistory, { date: lastSavedDate, completion, totalDone, totalTarget }];
      setHabitsHistory(nextHistory);
      saveStorage(STORAGE_KEYS.history, nextHistory);
    }
    const resetWorkout = buildDefaultWorkout();
    setWorkoutData(resetWorkout);
    setWater(0);
    setPrayers(buildDefaultPrayers());
    setTasks(buildDefaultTasks());
    setSunnah(buildDefaultSunnah());
    setLastSavedDate(todayKey);
    setResumedToday(false);
    saveStorage(STORAGE_KEYS.workout, resetWorkout);
    saveStorage(STORAGE_KEYS.water, 0);
    saveStorage(STORAGE_KEYS.prayers, buildDefaultPrayers());
    saveStorage(STORAGE_KEYS.tasks, buildDefaultTasks());
    saveStorage(STORAGE_KEYS.sunnah, buildDefaultSunnah());
    saveStorage(STORAGE_KEYS.lastDate, todayKey);
  };

  useEffect(() => {
    const todayKey = getTodayKey();
    const savedDate = loadStorage(STORAGE_KEYS.lastDate, todayKey);
    const storedWorkout = normalizeWorkout(loadStorage(STORAGE_KEYS.workout, null));
    const storedHistory = loadStorage(STORAGE_KEYS.history, []);
    const storedWater = loadStorage(STORAGE_KEYS.water, 0);
    const storedPrayers = loadStorage(STORAGE_KEYS.prayers, null);
    const storedTasks = loadStorage(STORAGE_KEYS.tasks, null);
    const storedSunnah = loadStorage(STORAGE_KEYS.sunnah, null);

    if (savedDate === todayKey && storedWorkout) {
      setWorkoutData(storedWorkout);
      setHabitsHistory(storedHistory);
      setWater(storedWater);
      setPrayers(storedPrayers || buildDefaultPrayers());
      setTasks(storedTasks || buildDefaultTasks());
      setSunnah(typeof storedSunnah === 'number' ? storedSunnah : buildDefaultSunnah());
      setResumedToday(true);
    } else {
      if (savedDate && savedDate !== todayKey && storedWorkout) {
        const { totalTarget, totalDone } = calculateTotals(storedWorkout);
        const completion = totalTarget ? Math.round((totalDone / totalTarget) * 100) : 0;
        const nextHistory = [...storedHistory, { date: savedDate, completion, totalDone, totalTarget }];
        setHabitsHistory(nextHistory);
        saveStorage(STORAGE_KEYS.history, nextHistory);
      } else {
        setHabitsHistory(storedHistory);
      }
      const resetWorkout = buildDefaultWorkout();
      setWorkoutData(resetWorkout);
      setWater(0);
      setPrayers(buildDefaultPrayers());
      setTasks(buildDefaultTasks());
      setSunnah(buildDefaultSunnah());
      saveStorage(STORAGE_KEYS.workout, resetWorkout);
      saveStorage(STORAGE_KEYS.water, 0);
      saveStorage(STORAGE_KEYS.prayers, buildDefaultPrayers());
      saveStorage(STORAGE_KEYS.tasks, buildDefaultTasks());
      saveStorage(STORAGE_KEYS.sunnah, buildDefaultSunnah());
    }
    setLastSavedDate(todayKey);
    saveStorage(STORAGE_KEYS.lastDate, todayKey);
  }, []);

  useEffect(() => {
    saveStorage(STORAGE_KEYS.workout, workoutData);
  }, [workoutData]);

  useEffect(() => {
    saveStorage(STORAGE_KEYS.history, habitsHistory);
  }, [habitsHistory]);

  useEffect(() => {
    saveStorage(STORAGE_KEYS.lastDate, lastSavedDate);
  }, [lastSavedDate]);

  useEffect(() => {
    saveStorage(STORAGE_KEYS.water, water);
  }, [water]);

  useEffect(() => {
    saveStorage(STORAGE_KEYS.prayers, prayers);
  }, [prayers]);

  useEffect(() => {
    saveStorage(STORAGE_KEYS.tasks, tasks);
  }, [tasks]);

  useEffect(() => {
    saveStorage(STORAGE_KEYS.sunnah, sunnah);
  }, [sunnah]);

  useEffect(() => {
    const interval = setInterval(() => {
      const todayKey = getTodayKey();
      if (todayKey !== lastSavedDate) {
        handleDailyReset(todayKey);
      }
    }, 15000);
    return () => clearInterval(interval);
  }, [lastSavedDate, workoutData, habitsHistory]);

  const logReps = (dayId, exerciseId, amount) => {
    if (!amount || amount <= 0) return;
    setWorkoutData((prev) =>
      prev.map((day) =>
        day.id !== dayId
          ? day
          : {
              ...day,
              exercises: day.exercises.map((ex) =>
                ex.id !== exerciseId
                  ? ex
                  : {
                      ...ex,
                      sessions: [...ex.sessions, amount],
                      totalDone: ex.totalDone + amount,
                    }
              ),
            }
      )
    );
    setRepsInputs((prev) => ({ ...prev, [exerciseId]: '' }));
  };

  const undoLastLog = (dayId, exerciseId) => {
    setWorkoutData((prev) =>
      prev.map((day) =>
        day.id !== dayId
          ? day
          : {
              ...day,
              exercises: day.exercises.map((ex) => {
                if (ex.id !== exerciseId) return ex;
                const lastValue = ex.sessions.length ? ex.sessions[ex.sessions.length - 1] : 0;
                return {
                  ...ex,
                  sessions: ex.sessions.slice(0, -1),
                  totalDone: Math.max(ex.totalDone - lastValue, 0),
                };
              }),
            }
      )
    );
  };

  const togglePrayer = (prayerId) => {
    setPrayers((prev) =>
      prev.map((item) => (item.id !== prayerId ? item : { ...item, done: !item.done }))
    );
  };

  const toggleTask = (taskId) => {
    setTasks((prev) =>
      prev.map((item) => (item.id !== taskId ? item : { ...item, done: !item.done }))
    );
  };

  const addWater = () => {
    setWater((prev) => Math.min(WATER_GOAL, prev + 1));
  };

  const resetWater = () => setWater(0);

  const logSunnah = () => setSunnah((prev) => prev + 1);

  const toggleDay = (dayId) => {
    setExpandedDays((prev) => ({ ...prev, [dayId]: !prev[dayId] }));
  };

  const formatDateLabel = (date) => `${date.getDate()}/${date.getMonth() + 1}`;

  return (
    <div
      style={{
        backgroundColor: themeBg,
        color: themeText,
        minHeight: '100vh',
        maxWidth: '390px',
        margin: '0 auto',
        position: 'relative',
        padding: '24px 16px 120px',
        fontFamily: 'system-ui, -apple-system, sans-serif',
        transition: 'background-color 0.3s ease, color 0.3s ease',
      }}
    >
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Amiri&display=swap');
        body { margin: 0; background: #000; -webkit-font-smoothing: antialiased; }
        html { scroll-behavior: smooth; }
        * { box-sizing: border-box; transition: background-color 0.25s ease, color 0.25s ease, border-color 0.25s ease, box-shadow 0.25s ease; }
        input, button { transition: all 0.25s ease; }
        button, [role="button"], input { touch-action: manipulation; }
        @keyframes pulse-glow { 0%, 100% { box-shadow: 0 0 8px #d4a01744; } 50% { box-shadow: 0 0 24px #d4a017aa; } }
        @keyframes gold-shimmer { 0% { background-position: -200% center; } 100% { background-position: 200% center; } }
      `}</style>

      <div
        onClick={() => setDark(!dark)}
        style={{
          position: 'absolute',
          top: '16px',
          right: '16px',
          width: '56px',
          height: '28px',
          borderRadius: '14px',
          backgroundColor: dark ? C.gold : C.green,
          cursor: 'pointer',
          transition: 'background-color 0.3s ease',
        }}
      >
        <div
          style={{
            position: 'absolute',
            top: '2px',
            left: dark ? '30px' : '2px',
            width: '24px',
            height: '24px',
            borderRadius: '50%',
            backgroundColor: '#fff',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '14px',
            transition: 'left 0.3s ease',
          }}
        >
          {dark ? '☀️' : '🌙'}
        </div>
      </div>

      <div style={{ textAlign: 'center', marginBottom: '24px', marginTop: '12px' }}>
        <div style={{ fontSize: '13px', fontFamily: "'Amiri', serif", color: C.gold }}>مُتَّقِين · MUTTAQIN</div>
        <div style={{ fontSize: '28px', fontWeight: 900, marginTop: '8px' }}>Workout Tracker</div>
        <div style={{ fontSize: '12px', color: themeMuted, marginTop: '6px' }}>Rep balance tracking with daily history</div>
      </div>

      <div style={{ display: 'flex', gap: '10px', marginBottom: '18px', overflowX: 'auto', paddingBottom: '4px' }}>
        {TABS.map((item) => {
          const active = tab === item.id;
          return (
            <div
              key={item.id}
              onClick={() => setTab(item.id)}
              style={{
                flex: active ? '1.2' : '1',
                minWidth: '110px',
                borderRadius: '14px',
                padding: '12px 12px',
                backgroundColor: active ? C.gold : themeCard,
                color: active ? '#111' : themeText,
                border: `1px solid ${active ? C.gold : dark ? C.border : C.borderLight}`,
                cursor: 'pointer',
                textAlign: 'center',
                fontWeight: 700,
                transition: 'all 0.2s ease',
              }}
            >
              <div style={{ fontSize: '18px' }}>{item.icon}</div>
              <div style={{ marginTop: '4px', fontSize: '11px', letterSpacing: '1px' }}>{item.label}</div>
            </div>
          );
        })}
      </div>

      {tab === 'workout' && (
        <>
          <div style={{ display: 'flex', gap: '10px', marginBottom: '18px' }}>
            <div style={{ flex: 1, borderRadius: '18px', padding: '16px', backgroundColor: themeCard, border: `1px solid ${dark ? C.border : C.borderLight}` }}>
              <div style={{ fontSize: '11px', color: themeMuted, letterSpacing: '1px', textTransform: 'uppercase', marginBottom: '6px' }}>Today progress</div>
              <div style={{ fontSize: '28px', fontWeight: 900, color: C.gold }}>{todaysTotals.totalDone}</div>
              <div style={{ fontSize: '11px', color: themeMuted, marginTop: '2px' }}>of {todaysTotals.totalTarget} reps</div>
            </div>
            <div style={{ flex: 1, borderRadius: '18px', padding: '16px', backgroundColor: themeCard, border: `1px solid ${dark ? C.border : C.borderLight}` }}>
              <div style={{ fontSize: '11px', color: themeMuted, letterSpacing: '1px', textTransform: 'uppercase', marginBottom: '6px' }}>Completion</div>
              <div style={{ fontSize: '28px', fontWeight: 900, color: C.greenLight }}>{formatPercent(overallProgress)}</div>
              <div style={{ width: '100%', height: '8px', backgroundColor: dark ? C.border : C.borderLight, borderRadius: '999px', marginTop: '12px', overflow: 'hidden' }}>
                <div style={{ width: `${Math.min(100, overallProgress)}%`, height: '100%', background: `linear-gradient(90deg, ${C.green}, ${C.greenLight})`, transition: 'width 0.3s ease' }} />
              </div>
            </div>
          </div>

          <div style={{ display: 'grid', gap: '12px', marginBottom: '18px' }}>
            <div style={{ borderRadius: '18px', padding: '18px', backgroundColor: themeCard, border: `1px solid ${dark ? C.border : C.borderLight}` }}>
              <div style={{ fontSize: '11px', textTransform: 'uppercase', color: themeMuted, letterSpacing: '1px', marginBottom: '10px' }}>Taqwa Score</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                <div style={{ position: 'relative', width: '96px', height: '96px' }}>
                  <div style={{ width: '96px', height: '96px', borderRadius: '50%', background: dark ? '#0f2217' : '#f8fafc', display: 'flex', alignItems: 'center', justifyContent: 'center', border: `8px solid rgba(255,255,255,0.08)` }} />
                  <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <div style={{ width: '100%', height: '100%', borderRadius: '50%', background: `conic-gradient(${C.gold} ${taqwaScore * 3.6}deg, ${dark ? '#122518' : '#e5e7eb'} 0deg)` }} />
                    <div style={{ position: 'absolute', width: '66px', height: '66px', borderRadius: '50%', backgroundColor: themeBg, display: 'flex', alignItems: 'center', justifyContent: 'center', color: themeText, fontWeight: 700, fontSize: '18px' }}>
                      {taqwaScore}%
                    </div>
                  </div>
                </div>
                <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  <div style={{ fontSize: '13px', fontWeight: 700 }}>Daily balance</div>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                    <div style={{ borderRadius: '14px', padding: '10px', backgroundColor: dark ? '#122f24' : '#fff', border: `1px solid ${dark ? C.border : C.borderLight}` }}>
                      <div style={{ fontSize: '10px', color: themeMuted, textTransform: 'uppercase', marginBottom: '4px' }}>Prayers</div>
                      <div style={{ fontSize: '18px', fontWeight: 700, color: C.gold }}>{prayerDoneCount}/{DEFAULT_PRAYERS.length}</div>
                    </div>
                    <div style={{ borderRadius: '14px', padding: '10px', backgroundColor: dark ? '#122f24' : '#fff', border: `1px solid ${dark ? C.border : C.borderLight}` }}>
                      <div style={{ fontSize: '10px', color: themeMuted, textTransform: 'uppercase', marginBottom: '4px' }}>Water</div>
                      <div style={{ fontSize: '18px', fontWeight: 700, color: C.greenLight }}>{water}/{WATER_GOAL}</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div style={{ borderRadius: '18px', padding: '16px', backgroundColor: themeCard, border: `1px solid ${dark ? C.border : C.borderLight}` }}>
              <div style={{ fontSize: '11px', color: themeMuted, textTransform: 'uppercase', letterSpacing: '1px', marginBottom: '10px' }}>Sunnah Tracker</div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '12px' }}>
                <div>
                  <div style={{ fontSize: '20px', fontWeight: 900, color: C.gold }}>{sunnah}</div>
                  <div style={{ fontSize: '11px', color: themeMuted, marginTop: '4px' }}>extra acts today</div>
                </div>
                <button
                  onClick={logSunnah}
                  style={{ borderRadius: '14px', padding: '12px 14px', backgroundColor: C.teal, color: '#fff', border: 'none', cursor: 'pointer', fontWeight: 700, transition: 'transform 0.2s ease, background-color 0.25s ease', willChange: 'transform, opacity' }}
                >
                  +1
                </button>
              </div>
            </div>
          </div>

          {resumedToday && (
            <div style={{ marginBottom: '18px', borderRadius: '16px', padding: '14px 16px', backgroundColor: C.gold + '11', border: `1px solid ${C.gold}33`, color: C.gold, fontSize: '12px' }}>
              Resumed from last session. Your today reps are restored.
            </div>
          )}

          {workoutData.map((day) => {
            const dayTarget = day.exercises.reduce((sum, ex) => sum + ex.sets * ex.reps, 0);
            const dayDone = day.exercises.reduce((sum, ex) => sum + ex.totalDone, 0);
            const dayPercent = dayTarget ? (dayDone / dayTarget) * 100 : 0;
            const expanded = expandedDays[day.id];

            return (
              <div key={day.id} style={{ marginBottom: '18px' }}>
                <div
                  onClick={() => toggleDay(day.id)}
                  style={{
                    borderRadius: '18px',
                    padding: '16px',
                    backgroundColor: themeCard,
                    border: `1px solid ${dark ? C.border : C.borderLight}`,
                    cursor: 'pointer',
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    transition: 'transform 0.2s ease, box-shadow 0.2s ease',
                    willChange: 'transform, opacity',
                  }}
                >
                  <div>
                    <div style={{ fontSize: '15px', fontWeight: 700, color: themeText }}>{day.title}</div>
                    <div style={{ fontSize: '11px', color: themeMuted, marginTop: '4px' }}>{day.subtitle}</div>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontSize: '14px', fontWeight: 700, color: C.gold }}>{formatPercent(dayPercent)}</div>
                    <div style={{ fontSize: '10px', color: themeMuted, marginTop: '4px' }}>{dayDone}/{dayTarget} reps</div>
                  </div>
                </div>

                {expanded && (
                  <div style={{ marginTop: '12px', display: 'grid', gap: '12px' }}>
                    {day.exercises.map((exercise) => {
                      const totalTarget = exercise.sets * exercise.reps;
                      const done = exercise.totalDone;
                      const remaining = Math.max(totalTarget - done, 0);
                      const progress = totalTarget ? Math.min(100, (done / totalTarget) * 100) : 0;

                      return (
                        <div key={exercise.id} style={{ borderRadius: '18px', padding: '16px', backgroundColor: themeCard, border: `1px solid ${dark ? C.border : C.borderLight}` }}>
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                            <div>
                              <div style={{ fontSize: '15px', fontWeight: 700, color: themeText }}>{exercise.name}</div>
                              <div style={{ fontSize: '11px', color: themeMuted, marginTop: '4px' }}>{exercise.sets} sets × {exercise.reps} reps</div>
                            </div>
                            <div style={{ display: 'flex', gap: '6px', alignItems: 'center' }}>
                              <div style={{ padding: '6px 10px', borderRadius: '999px', backgroundColor: C.gold + '22', color: C.gold, fontSize: '11px', fontWeight: 700 }}>
                                +{totalTarget}
                              </div>
                              <div style={{ padding: '6px 10px', borderRadius: '999px', backgroundColor: done ? C.green + '22' : C.border + '22', color: done ? C.greenLight : themeMuted, fontSize: '11px', fontWeight: 700 }}>
                                {done} done
                              </div>
                            </div>
                          </div>

                          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '8px', marginBottom: '14px' }}>
                            {[
                              { label: 'Total', value: totalTarget, color: C.gold },
                              { label: 'Done', value: done, color: C.greenLight },
                              { label: 'Still needed', value: remaining, color: remaining === 0 ? C.greenLight : themeMuted },
                            ].map((item) => (
                              <div key={item.label} style={{ borderRadius: '14px', padding: '10px', backgroundColor: dark ? '#152d1f' : '#f8fafc', border: `1px solid ${dark ? C.border : C.borderLight}` }}>
                                <div style={{ fontSize: '10px', letterSpacing: '1px', textTransform: 'uppercase', color: themeMuted, marginBottom: '4px' }}>{item.label}</div>
                                <div style={{ fontSize: '18px', fontWeight: 700, color: item.color }}>{item.value}</div>
                              </div>
                            ))}
                          </div>

                          <div style={{ display: 'flex', gap: '8px', alignItems: 'center', marginBottom: '10px' }}>
                            <input
                              type='number'
                              min='0'
                              value={repsInputs[exercise.id] ?? ''}
                              onChange={(e) => setRepsInputs((prev) => ({ ...prev, [exercise.id]: e.target.value }))}
                              placeholder='Log reps'
                              style={{
                                flex: 1,
                                borderRadius: '14px',
                                border: `1px solid ${dark ? C.border : C.borderLight}`,
                                padding: '12px',
                                backgroundColor: dark ? '#0f2217' : '#f8fafc',
                                color: themeText,
                                outline: 'none',
                                fontSize: '14px',
                              }}
                            />
                            <button
                              onClick={() => {
                                const amount = Math.max(0, Math.floor(Number(repsInputs[exercise.id]) || 0));
                                if (amount > 0) {
                                  logReps(day.id, exercise.id, amount);
                                }
                              }}
                              style={{
                                borderRadius: '14px',
                                padding: '12px 14px',
                                backgroundColor: C.teal,
                                color: '#fff',
                                border: 'none',
                                cursor: 'pointer',
                                fontWeight: 700,
                                minWidth: '78px',
                              }}
                            >
                              Log
                            </button>
                          </div>

                          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px', marginBottom: '10px' }}>
                            {exercise.sessions.length ? exercise.sessions.map((value, index) => (
                              <div key={`${exercise.id}-${index}`} style={{ padding: '8px 10px', borderRadius: '999px', backgroundColor: C.gold + '22', color: C.gold, fontSize: '12px' }}>
                                +{value}
                              </div>
                            )) : (
                              <div style={{ fontSize: '12px', color: themeMuted }}>No logs yet</div>
                            )}
                          </div>

                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '10px' }}>
                            <div style={{ width: '100%', height: '10px', borderRadius: '999px', backgroundColor: dark ? C.border : C.borderLight, overflow: 'hidden' }}>
                              <div style={{ width: `${progress}%`, height: '100%', background: done >= totalTarget ? C.gold : `linear-gradient(90deg, ${C.green}, ${C.greenLight})`, transition: 'width 0.3s ease' }} />
                            </div>
                            <button
                              onClick={() => undoLastLog(day.id, exercise.id)}
                              disabled={!exercise.sessions.length}
                              style={{
                                borderRadius: '14px',
                                padding: '10px 14px',
                                backgroundColor: exercise.sessions.length ? C.red : dark ? '#23342a' : '#e5e7eb',
                                color: exercise.sessions.length ? '#fff' : themeMuted,
                                border: 'none',
                                cursor: exercise.sessions.length ? 'pointer' : 'default',
                                fontWeight: 700,
                              }}
                            >
                              Undo
                            </button>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            );
          })}
        </>
      )}

      {tab === 'habits' && (
        <>
          <div style={{ marginBottom: '18px' }}>
            <div style={{ fontSize: '20px', fontWeight: 900, color: themeText }}>Habits History</div>
            <div style={{ fontSize: '11px', color: themeMuted, marginTop: '6px' }}>Daily completion heatmap and progress cards.</div>
          </div>

          <div style={{ display: 'grid', gap: '12px', marginBottom: '18px' }}>
            <div style={{ borderRadius: '18px', padding: '16px', backgroundColor: themeCard, border: `1px solid ${dark ? C.border : C.borderLight}` }}>
              <div style={{ fontSize: '11px', textTransform: 'uppercase', color: themeMuted, letterSpacing: '1px', marginBottom: '10px' }}>Prayers</div>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, minmax(0, 1fr))', gap: '10px' }}>
                {prayers.map((item) => (
                  <button
                    key={item.id}
                    onClick={() => togglePrayer(item.id)}
                    style={{
                      borderRadius: '15px',
                      padding: '12px',
                      backgroundColor: item.done ? C.gold : themeBg,
                      color: item.done ? '#111' : themeText,
                      border: `1px solid ${item.done ? C.gold : dark ? C.border : C.borderLight}`,
                      cursor: 'pointer',
                      fontSize: '11px',
                      fontWeight: 700,
                    }}
                  >
                    {item.label}
                  </button>
                ))}
              </div>
            </div>

            <div style={{ borderRadius: '18px', padding: '16px', backgroundColor: themeCard, border: `1px solid ${dark ? C.border : C.borderLight}` }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '14px' }}>
                <div>
                  <div style={{ fontSize: '11px', textTransform: 'uppercase', color: themeMuted, letterSpacing: '1px' }}>Daily tasks</div>
                  <div style={{ fontSize: '14px', fontWeight: 700, marginTop: '4px' }}>Stay focused on key habits</div>
                </div>
                <div style={{ fontSize: '11px', color: themeMuted }}>{taskDoneCount}/{tasks.length} done</div>
              </div>
              <div style={{ display: 'grid', gap: '10px' }}>
                {tasks.map((item) => (
                  <button
                    key={item.id}
                    onClick={() => toggleTask(item.id)}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      borderRadius: '14px',
                      padding: '12px',
                      backgroundColor: item.done ? C.green + '22' : dark ? '#122f24' : '#fff',
                      border: `1px solid ${item.done ? C.greenLight : dark ? C.border : C.borderLight}`,
                      color: item.done ? C.greenLight : themeText,
                      cursor: 'pointer',
                      fontSize: '13px',
                      fontWeight: 700,
                    }}
                  >
                    <span>{item.label}</span>
                    <span>{item.done ? 'Done' : 'Tap'}</span>
                  </button>
                ))}
              </div>
            </div>

            <div style={{ borderRadius: '18px', padding: '16px', backgroundColor: themeCard, border: `1px solid ${dark ? C.border : C.borderLight}` }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                <div>
                  <div style={{ fontSize: '11px', textTransform: 'uppercase', color: themeMuted, letterSpacing: '1px' }}>Water Intake</div>
                  <div style={{ fontSize: '14px', fontWeight: 700, marginTop: '4px' }}>{water}/{WATER_GOAL} glasses</div>
                </div>
                <button
                  onClick={addWater}
                  style={{ borderRadius: '14px', padding: '10px 14px', backgroundColor: C.teal, color: '#fff', border: 'none', cursor: 'pointer', fontWeight: 700, transition: 'transform 0.2s ease, background-color 0.25s ease', willChange: 'transform, opacity' }}
                >
                  +1
                </button>
              </div>
              <div style={{ width: '100%', height: '10px', borderRadius: '999px', backgroundColor: dark ? C.border : C.borderLight, overflow: 'hidden' }}>
                <div style={{ width: `${waterPercent}%`, height: '100%', background: `linear-gradient(90deg, ${C.green}, ${C.greenLight})`, transition: 'width 0.3s ease' }} />
              </div>
              <button
                onClick={resetWater}
                style={{ marginTop: '12px', borderRadius: '14px', padding: '10px 14px', backgroundColor: dark ? '#23342a' : '#e5e7eb', color: themeText, border: 'none', cursor: 'pointer', fontWeight: 700, transition: 'transform 0.2s ease, background-color 0.25s ease', willChange: 'transform, opacity' }}
              >
                Reset water
              </button>
            </div>
          </div>

          <div style={{ borderRadius: '18px', padding: '16px', backgroundColor: themeCard, border: `1px solid ${dark ? C.border : C.borderLight}`, marginBottom: '18px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '14px' }}>
              <div>
                <div style={{ fontSize: '12px', textTransform: 'uppercase', color: themeMuted, letterSpacing: '1px' }}>Last 30 days average</div>
                <div style={{ fontSize: '24px', fontWeight: 900, color: C.gold }}>{formatPercent(habitsHistory.length ? habitsHistory.reduce((sum, entry) => sum + entry.completion, 0) / habitsHistory.length : 0)}</div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div style={{ fontSize: '11px', color: themeMuted }}>Entries</div>
                <div style={{ fontSize: '22px', fontWeight: 900, color: C.greenLight }}>{habitsHistory.length}</div>
              </div>
            </div>
            <div style={{ width: '100%', height: '10px', borderRadius: '999px', backgroundColor: dark ? C.border : C.borderLight, overflow: 'hidden' }}>
              <div style={{ width: `${Math.min(100, habitsHistory.length ? habitsHistory.reduce((sum, entry) => sum + entry.completion, 0) / habitsHistory.length : 0)}%`, height: '100%', background: `linear-gradient(90deg, ${C.gold}, ${C.greenLight})`, transition: 'width 0.3s ease' }} />
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: '8px' }}>
            {calendarDays.map((day) => {
              const key = day.toISOString().slice(0, 10);
              const entry = findHistoryEntry(key);
              const percent = entry ? entry.completion : key === getTodayKey() ? Math.round(overallProgress) : 0;
              const isToday = key === getTodayKey();
              const dayBg = getDayColor(percent);
              const textColor = percent >= 90 ? '#111' : themeText;

              return (
                <div
                  key={key}
                  style={{
                    borderRadius: '14px',
                    padding: '12px',
                    backgroundColor: dayBg,
                    border: isToday ? `2px solid ${C.gold}` : `1px solid ${dark ? C.border : C.borderLight}`,
                    minHeight: '80px',
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'space-between',
                  }}
                >
                  <div style={{ fontSize: '11px', color: themeMuted }}>{['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'][day.getDay()]}</div>
                  <div style={{ fontSize: '20px', fontWeight: 900, color: textColor }}>{percent ? `${percent}%` : '–'}</div>
                  <div style={{ fontSize: '10px', color: themeMuted }}>{formatDateLabel(day)}</div>
                </div>
              );
            })}
          </div>

          <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginTop: '18px' }}>
            {[
              { label: '0%', color: themeCard },
              { label: '1-39%', color: C.red + '66' },
              { label: '40-69%', color: C.gold + '66' },
              { label: '70-89%', color: C.greenLight + '66' },
              { label: '90-100%', color: C.gold },
            ].map((item) => (
              <div key={item.label} style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <div style={{ width: '12px', height: '12px', borderRadius: '4px', backgroundColor: item.color, border: `1px solid ${dark ? C.border : C.borderLight}` }} />
                <div style={{ fontSize: '11px', color: themeMuted }}>{item.label}</div>
              </div>
            ))}
          </div>
        </>
      )}

      <div
        style={{
          position: 'fixed',
          bottom: 0,
          left: 0,
          right: 0,
          margin: '0 auto',
          maxWidth: '390px',
          height: '64px',
          backgroundColor: dark ? C.card : C.cardLight,
          borderTop: `1px solid ${dark ? C.border : C.borderLight}`,
          zIndex: 100,
          display: 'flex',
          justifyContent: 'space-around',
          alignItems: 'center',
          paddingBottom: 'env(safe-area-inset-bottom, 0px)',
        }}
      >
        {TABS.map((t) => {
          const isActive = tab === t.id;
          return (
            <div
              key={t.id}
              onClick={() => setTab(t.id)}
              style={{
                flex: 1,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: 'pointer',
                gap: '2px',
                transition: 'transform 0.2s ease, opacity 0.2s ease',
                willChange: 'transform, opacity',
              }}
            >
              <div style={{ fontSize: '20px', color: isActive ? C.teal : themeMuted }}>{t.icon}</div>
              <div style={{ fontSize: '9px', color: isActive ? C.teal : themeMuted, letterSpacing: '0.5px', fontWeight: 600 }}>{t.label}</div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
