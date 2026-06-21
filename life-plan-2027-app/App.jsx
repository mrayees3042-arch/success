import React, { useState, useEffect, useRef, useCallback } from 'react';

// --- COLORS ---
const C = {
  bg: "#0a1a0f", bgLight: "#f5f0e8",
  card: "#112318", cardLight: "#ffffff",
  green: "#1a6b3a", greenLight: "#22c55e",
  gold: "#d4a017", goldLight: "#fbbf24",
  text: "#f0ead6", textLight: "#1a1a2e",
  muted: "#6b8f71", mutedLight: "#9ca3af",
  border: "#1e3d28", borderLight: "#e5e7eb",
  teal: "#0d9488", red: "#ef4444",
  blue: "#3b82f6", orange: "#f97316",
};

// --- DEFAULTS ---
const DEFAULT_PRAYERS = [
  { id: "tahajjud", ar: "تهجد", name: "Tahajjud", time: "4:15 AM", done: false, missed: false },
  { id: "fajr", ar: "فجر", name: "Fajr", time: "5:30 AM", done: false, missed: false },
  { id: "dhuha", ar: "ضحى", name: "Dhuha", time: "7:00 AM", done: false, missed: false },
  { id: "dhuhr", ar: "ظهر", name: "Dhuhr", time: "12:30 PM", done: false, missed: false },
  { id: "asr", ar: "عصر", name: "Asr", time: "3:45 PM", done: false, missed: false },
  { id: "maghrib", ar: "مغرب", name: "Maghrib", time: "6:45 PM", done: false, missed: false },
  { id: "isha", ar: "عشاء", name: "Isha", time: "8:15 PM", done: false, missed: false },
];

const DEFAULT_TASKS = [
  { id: 1, title: "Quran Reading", sub: "15–20 mins after Fajr", duration: "20m", done: false, color: C.greenLight, emoji: "📖" },
  { id: 2, title: "TIA Portal Study", sub: "7–9 AM · 2 hours", duration: "2h", done: false, color: C.blue, emoji: "💻" },
  { id: 3, title: "Morning Walk", sub: "30 mins · after study", duration: "30m", done: false, color: C.gold, emoji: "🚶" },
  { id: 4, title: "Workout", sub: "Push / Legs / Back / HIIT", duration: "1h", done: false, color: C.red, emoji: "🏋️" },
  { id: 5, title: "Productive Phone", sub: "Use phone only for useful work", duration: "–", done: false, color: C.teal, emoji: "📱" },
];

const DEFAULT_WORKOUT = [
  { id: 1, day: "Day 1 – Push", schedule: "Mon / Thu", icon: "💪", exercises: [{ id: 1, name: "Push-ups", sets: 4, reps: 20, muscles: ["Chest", "Shoulders", "Triceps"] }, { id: 2, name: "Diamond Push-ups", sets: 3, reps: 15, muscles: ["Inner chest", "Triceps"] }, { id: 3, name: "Pike Push-ups", sets: 4, reps: 12, muscles: ["Shoulders"] }, { id: 4, name: "Tricep Dips (chair)", sets: 3, reps: 15, muscles: ["Triceps"] }] },
  { id: 2, day: "Day 2 – Legs & Core", schedule: "Tue / Fri", icon: "🦵", exercises: [{ id: 1, name: "Bodyweight Squats", sets: 4, reps: 20, muscles: ["Quads"] }, { id: 2, name: "Jump Squats", sets: 3, reps: 15, muscles: ["Fat burn"] }, { id: 3, name: "Lunges", sets: 3, reps: 12, muscles: ["Hamstrings"] }, { id: 4, name: "Plank Hold", sets: 4, reps: 45, muscles: ["Core"], isSeconds: true }, { id: 5, name: "Leg Raises", sets: 3, reps: 15, muscles: ["Lower abs"] }] },
  { id: 3, day: "Day 3 – Back & Biceps", schedule: "Wed / Sat", icon: "🏋️", exercises: [{ id: 1, name: "Pull-ups / Chin-ups", sets: 4, reps: 8, muscles: ["Back", "Biceps"] }, { id: 2, name: "Inverted Rows (table)", sets: 4, reps: 12, muscles: ["Back"] }, { id: 3, name: "Towel Bicep Curls", sets: 3, reps: 15, muscles: ["Biceps"] }] },
  { id: 4, day: "Day 4 – HIIT Full Body", schedule: "Sun · Max fat burn", icon: "🔥", exercises: [{ id: 1, name: "Burpees", sets: 4, reps: 10, muscles: ["Full body"] }, { id: 2, name: "Mountain Climbers", sets: 4, reps: 30, muscles: ["Belly fat"], isSeconds: true }, { id: 3, name: "Russian Twists", sets: 3, reps: 20, muscles: ["Obliques"] }, { id: 4, name: "High Knees", sets: 4, reps: 30, muscles: ["Cardio"], isSeconds: true }] },
];

const DEFAULT_SUNNAH = { fasting: false, miswak: false, sadaqah: false, dhikr: false, dhikrCount: 0, alKahf: false, alMulk: false };

const ISLAMIC_QUOTES = [
  { ar: "إِنَّ مَعَ الْعُسْرِ يُسْرًا", en: "Indeed, with hardship comes ease.", ref: "Quran 94:6" },
  { ar: "وَمَن يَتَّقِ اللَّهَ يَجْعَل لَّهُ مَخْرَجًا", en: "Whoever fears Allah, He will make a way out for him.", ref: "Quran 65:2" },
  { ar: "الصَّوْمُ جُنَّةٌ", en: "Fasting is a shield.", ref: "Bukhari & Muslim" },
  { ar: "إِنَّ اللَّهَ يُحِبُّ إِذَا عَمِلَ أَحَدُكُمْ عَمَلاً أَنْ يُتْقِنَهُ", en: "Allah loves that when one of you does a task, he does it with excellence.", ref: "Al-Bayhaqi" },
  { ar: "الْمُؤْمِنُ الْقَوِيُّ خَيْرٌ وَأَحَبُّ إِلَى اللَّهِ مِنَ الْمُؤْمِنِ الضَّعِيفِ", en: "The strong believer is better and more beloved to Allah than the weak believer.", ref: "Muslim" },
  { ar: "مَنْ سَلَكَ طَرِيقًا يَلْتَمِسُ فِيهِ عِلْمًا سَهَّلَ اللَّهُ لَهُ طَرِيقًا إِلَى الْجَنَّةِ", en: "Whoever takes a path seeking knowledge, Allah eases his path to Jannah.", ref: "Muslim" },
  { ar: "أَحَبُّ الأَعْمَالِ إِلَى اللَّهِ أَدْوَمُهَا وَإِنْ قَلَّ", en: "The most beloved deeds to Allah are the most consistent, even if small.", ref: "Bukhari" },
];

const SECTION_HADITHS = {
  prayers: { ar: "الصَّلَاةُ عِمَادُ الدِّينِ", en: "Prayer is the pillar of the religion.", ref: "Al-Bayhaqi" },
  fasting: { ar: "الصَّوْمُ جُنَّةٌ", en: "Fasting is a shield.", ref: "Bukhari" },
  workout: { ar: "الْمُؤْمِنُ الْقَوِيُّ خَيْرٌ", en: "The strong believer is better and more beloved to Allah.", ref: "Muslim" },
  quran: { ar: "خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ", en: "The best of you are those who learn the Quran and teach it.", ref: "Bukhari" },
  dhikr: { ar: "أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ", en: "Verily in the remembrance of Allah do hearts find rest.", ref: "Quran 13:28" },
  income: { ar: "مَا أَكَلَ أَحَدٌ طَعَامًا قَطُّ خَيْرًا مِنْ أَنْ يَأْكُلَ مِنْ عَمَلِ يَدِهِ", en: "No one has ever eaten better food than that earned by his own hands.", ref: "Bukhari" },
  water: { ar: "وَجَعَلْنَا مِنَ الْمَاءِ كُلَّ شَيْءٍ حَيٍّ", en: "And We made every living thing from water.", ref: "Quran 21:30" },
};

const TABS = [
  { id: "today", icon: "🏠", label: "Today" },
  { id: "goals", icon: "🎯", label: "Goals" },
  { id: "habits", icon: "🔥", label: "Habits" },
  { id: "workout", icon: "🏋️", label: "Workout" },
  { id: "income", icon: "₹", label: "Income" },
  { id: "todo", icon: "☑️", label: "ToDo" },
];

// --- HELPERS ---
function useLocalStorage(key, initialValue) {
  const [storedValue, setStoredValue] = useState(() => {
    try {
      const item = window.localStorage.getItem(key);
      return item ? JSON.parse(item) : initialValue;
    } catch (error) { return initialValue; }
  });
  const setValue = value => {
    try {
      const valueToStore = value instanceof Function ? value(storedValue) : value;
      setStoredValue(valueToStore);
      window.localStorage.setItem(key, JSON.stringify(valueToStore));
    } catch (error) {}
  };
  return [storedValue, setValue];
}

const calcTaqwaScore = (state) => {
  let score = 0;
  score += (state.prayers.filter(p => p.done).length / 7) * 25;
  score += state.tasks.find(t => t.id === 1)?.done ? 8 : 0; // Quran task
  score += state.sunnah.fasting ? 5 : 0;
  score += state.sunnah.dhikr ? 5 : 0;
  score += state.sunnah.miswak ? 4 : 0;
  score += state.sunnah.sadaqah ? 3 : 0;
  score += (state.tasks.filter(t => t.done).length / 5) * 25;
  score += (state.water / 10) * 10;
  score += state.workoutDone ? 10 : 0;
  const todayStr = new Date().toDateString();
  score += state.income.entries.some(e => new Date(e.date).toDateString() === todayStr) ? 5 : 0;
  return Math.min(100, Math.round(score));
};

// --- COMPONENTS ---
const TodoItem = ({ task, onToggle, onDelete }) => {
  const [swiped, setSwiped] = useState(false);
  const startX = useRef(0);
  
  const onTouchStart = e => startX.current = e.touches[0].clientX;
  const onTouchEnd = e => {
    const delta = e.changedTouches[0].clientX - startX.current;
    if (delta < -60) setSwiped(true);
    else if (delta > 40) setSwiped(false);
  };

  return (
    <div style={{ position: 'relative', marginBottom: '12px', overflow: 'hidden', borderRadius: '16px' }} onTouchStart={onTouchStart} onTouchEnd={onTouchEnd}>
      <div style={{ position: 'absolute', right: 0, top: 0, bottom: 0, width: '70px', background: 'var(--red)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', fontSize: '12px', cursor: 'pointer' }} onClick={onDelete}>🗑️ Delete</div>
      <div className="card" style={{ transform: `translateX(${swiped ? '-70px' : '0px'})`, transition: 'transform 0.2s ease', position: 'relative', zIndex: 1, margin: 0, display: 'flex', alignItems: 'center', gap: '12px' }}>
        <div onClick={onToggle} style={{ width: '24px', height: '24px', borderRadius: '50%', border: `2px solid ${task.done ? 'var(--greenLight)' : 'var(--border)'}`, background: task.done ? 'var(--greenLight)' : 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {task.done && <span style={{ color: '#fff', fontSize: '14px' }}>✓</span>}
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: '15px', color: task.done ? 'var(--muted)' : 'var(--text)', textDecoration: task.done ? 'line-through' : 'none' }}>{task.title}</div>
          <div style={{ fontSize: '11px', color: 'var(--muted)', marginTop: '4px' }}>Created • {new Date(task.createdAt).toLocaleString('en-US', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute:'2-digit' })}</div>
        </div>
      </div>
    </div>
  );
};

// --- MAIN APP ---
export default function App() {
  const [isDark, setIsDark] = useLocalStorage('muttaqin_theme', true);
  const [tab, setTab] = useState('today');

  const [prayers, setPrayers] = useLocalStorage('muttaqin_prayers', DEFAULT_PRAYERS);
  const [tasks, setTasks] = useLocalStorage('muttaqin_tasks', DEFAULT_TASKS);
  const [workout, setWorkout] = useLocalStorage('muttaqin_workout', DEFAULT_WORKOUT);
  const [income, setIncome] = useLocalStorage('muttaqin_income', { entries: [], monthlyTarget: 300000, dailyTarget: 10000 });
  const [todo, setTodo] = useLocalStorage('muttaqin_todo', []);
  const [sunnah, setSunnah] = useLocalStorage('muttaqin_sunnah', DEFAULT_SUNNAH);
  const [water, setWater] = useLocalStorage('muttaqin_water', 0);
  const [workoutDone, setWorkoutDone] = useLocalStorage('muttaqin_workoutDone', false);
  const [streaks, setStreaks] = useLocalStorage('muttaqin_streaks', {});
  const [history, setHistory] = useLocalStorage('muttaqin_history', []);

  const score = calcTaqwaScore({ prayers, tasks, sunnah, water, workoutDone, income });

  // Date Sync & Snapshot
  useEffect(() => {
    const todayStr = new Date().toDateString();
    const lastDate = localStorage.getItem("muttaqin_lastDate");
    if (lastDate && lastDate !== todayStr) {
      const snapshot = JSON.parse(localStorage.getItem("muttaqin_snapshot") || "{}");
      setHistory(prev => [...prev, { ...snapshot, date: lastDate }]);
      setPrayers(DEFAULT_PRAYERS);
      setTasks(DEFAULT_TASKS.map(t => ({...t, done: false})));
      setSunnah(DEFAULT_SUNNAH);
      setWater(0);
      setWorkoutDone(false);
    }
    localStorage.setItem("muttaqin_lastDate", todayStr);
  }, []);

  useEffect(() => {
    localStorage.setItem("muttaqin_snapshot", JSON.stringify({ taqwaScore: score, prayers, tasks, water, sunnah, workoutDone, income: income.entries.filter(e => new Date(e.date).toDateString() === new Date().toDateString()) }));
  }, [score, prayers, tasks, water, sunnah, workoutDone, income]);

  // Data derivation
  const todayDate = new Date();
  const dayOfYear = Math.floor((todayDate - new Date(todayDate.getFullYear(), 0, 0)) / 1000 / 60 / 60 / 24);
  const activeQuote = ISLAMIC_QUOTES[dayOfYear % ISLAMIC_QUOTES.length];
  const daysTo2027 = Math.max(0, Math.ceil((new Date("2027-01-01T00:00:00") - todayDate) / 86400000));
  const daysToRamadan = Math.max(0, Math.ceil((new Date("2027-02-18T00:00:00") - todayDate) / 86400000));
  const isFastingDay = todayDate.getDay() === 1 || todayDate.getDay() === 4;
  const isFriday = todayDate.getDay() === 5;

  // Render logic components
  const SectionHadith = ({ data }) => (
    <div style={{ padding: '12px 16px', borderLeft: '3px solid var(--gold)', background: 'var(--card)', borderRadius: '8px', marginBottom: '16px' }}>
      <div style={{ fontFamily: "'Amiri', serif", color: 'var(--gold)', fontSize: '18px', textAlign: 'right', marginBottom: '6px' }}>{data.ar}</div>
      <div style={{ fontSize: '12px', color: 'var(--muted)', fontStyle: 'italic' }}>"{data.en}"</div>
      <div style={{ fontSize: '10px', color: 'var(--muted)', marginTop: '4px', textAlign: 'right' }}>— {data.ref}</div>
    </div>
  );

  const updateStreak = (key, isDone) => {
    setStreaks(s => {
      const current = s[key] || 0;
      return { ...s, [key]: isDone ? current + 1 : Math.max(0, current - 1) };
    });
  };

  // Screens
  const renderToday = () => {
    const nextPrayer = prayers.find(p => !p.done && !p.missed) || prayers[0];
    const ringColor = score < 40 ? 'var(--red)' : score < 70 ? 'var(--orange)' : score < 90 ? 'var(--greenLight)' : 'var(--gold)';
    const scoreMsg = score === 0 ? "بسم الله · Begin" : score < 40 ? "Keep Going 💪" : score < 70 ? "Almost There 🔥" : score < 90 ? "On Fire! ⚡" : score < 100 ? "Nearly Perfect 🌟" : "الحمد لله · Perfect Day! 🌟";

    return (
      <div className="fade-in">
        <div className="card" style={{ borderColor: 'var(--green)', boxShadow: '0 0 15px rgba(212,160,23,0.1)' }}>
          <div style={{ fontFamily: "'Amiri', serif", color: 'var(--gold)', fontSize: '20px', textAlign: 'center', marginBottom: '8px' }}>{activeQuote.ar}</div>
          <div style={{ fontSize: '12px', color: 'var(--muted)', textAlign: 'center', fontStyle: 'italic' }}>"{activeQuote.en}"</div>
          <div style={{ fontSize: '10px', color: 'var(--muted)', textAlign: 'center', marginTop: '6px' }}>— {activeQuote.ref}</div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '24px' }}>
          <div className="card" style={{ borderColor: 'var(--green)', textAlign: 'center', padding: '20px 12px' }}>
            <div className="large-num">{daysTo2027}</div>
            <div className="section-title" style={{ marginTop: '8px' }}>DAYS TO 2027</div>
          </div>
          <div className="card" style={{ borderColor: 'var(--green)', textAlign: 'center', padding: '20px 12px' }}>
            <div className="large-num">{daysToRamadan}</div>
            <div className="section-title" style={{ marginTop: '8px' }}>DAYS TO RAMADAN</div>
          </div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '8px', marginBottom: '32px' }}>
          <div className="card" style={{ background: 'linear-gradient(180deg, var(--card), #d4a01722)', textAlign: 'center', padding: '12px 8px' }}>
            <div style={{ fontSize: '18px', filter: 'drop-shadow(0 0 8px var(--gold))' }}>🕌</div>
            <div style={{ fontSize: '18px', fontWeight: 900, color: 'var(--gold)' }}>{prayers.filter(p=>p.done).length}/7</div>
            <div style={{ fontSize: '9px', color: 'var(--muted)', marginTop: '4px', textTransform: 'uppercase', letterSpacing: '1px' }}>Prayers</div>
          </div>
          <div className="card" style={{ background: 'linear-gradient(180deg, var(--card), #22c55e22)', textAlign: 'center', padding: '12px 8px' }}>
            <div style={{ fontSize: '18px', filter: 'drop-shadow(0 0 8px var(--greenLight))' }}>✓</div>
            <div style={{ fontSize: '18px', fontWeight: 900, color: 'var(--greenLight)' }}>{tasks.filter(t=>t.done).length}/5</div>
            <div style={{ fontSize: '9px', color: 'var(--muted)', marginTop: '4px', textTransform: 'uppercase', letterSpacing: '1px' }}>Tasks</div>
          </div>
          <div className="card" style={{ background: 'linear-gradient(180deg, var(--card), #3b82f622)', textAlign: 'center', padding: '12px 8px' }}>
            <div style={{ fontSize: '18px', filter: 'drop-shadow(0 0 8px var(--blue))' }}>💧</div>
            <div style={{ fontSize: '18px', fontWeight: 900, color: 'var(--blue)' }}>{water}L</div>
            <div style={{ fontSize: '9px', color: 'var(--muted)', marginTop: '4px', textTransform: 'uppercase', letterSpacing: '1px' }}>Water</div>
          </div>
          <div className="card" style={{ background: 'linear-gradient(180deg, var(--card), #f9731622)', textAlign: 'center', padding: '12px 8px' }}>
            <div style={{ fontSize: '18px', filter: 'drop-shadow(0 0 8px var(--orange))' }}>🔥</div>
            <div style={{ fontSize: '18px', fontWeight: 900, color: 'var(--orange)' }}>{streaks['taqwa'] || 0}d</div>
            <div style={{ fontSize: '9px', color: 'var(--muted)', marginTop: '4px', textTransform: 'uppercase', letterSpacing: '1px' }}>Streak</div>
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', marginBottom: '32px' }}>
          <div style={{ position: 'relative', width: '140px', height: '140px', display: 'flex', alignItems: 'center', justifyContent: 'center', animation: score >= 90 ? 'pulse-glow 2s infinite' : 'none', borderRadius: '50%' }}>
            <svg width="140" height="140" style={{ position: 'absolute', transform: 'rotate(-90deg)' }}>
              <circle cx="70" cy="70" r="60" stroke="var(--border)" strokeWidth="8" fill="none" />
              <circle cx="70" cy="70" r="60" stroke={ringColor} strokeWidth="8" fill="none" strokeDasharray={2 * Math.PI * 60} strokeDashoffset={(2 * Math.PI * 60) * (1 - score / 100)} style={{ transition: 'stroke-dashoffset 1s ease-out' }} strokeLinecap="round" />
            </svg>
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              <span style={{ fontSize: '36px', fontWeight: 900, color: ringColor, lineHeight: 1 }}>{score}%</span>
              <span style={{ fontSize: '11px', color: 'var(--muted)', letterSpacing: '2px', marginTop: '4px', fontWeight: 'bold' }}>TAQWA</span>
            </div>
          </div>
          <div style={{ marginTop: '16px', fontSize: '15px', fontWeight: 700, color: 'var(--text)' }}>{scoreMsg}</div>
        </div>

        <div className="section-title">السنة · Sunnah Practice</div>
        <SectionHadith data={SECTION_HADITHS.fasting} />
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '10px', marginBottom: '32px' }}>
          <div className="card" onClick={() => setSunnah(s => ({...s, fasting: !s.fasting}))} style={{ background: sunnah.fasting ? 'var(--green)' : 'var(--card)', borderColor: isFastingDay ? 'var(--gold)' : 'var(--border)', boxShadow: isFastingDay ? '0 0 10px rgba(212,160,23,0.3)' : 'none', textAlign: 'center', cursor: 'pointer' }}>
            <div style={{ fontSize: '20px' }}>🌙</div>
            <div style={{ fontSize: '12px', fontWeight: 'bold', marginTop: '6px' }}>Fasting</div>
            <div style={{ fontSize: '9px', color: sunnah.fasting ? '#fff' : 'var(--muted)', marginTop: '4px' }}>{isFastingDay ? "Sunnah Fast Day 🌙" : `Next: ${todayDate.getDay()<=1 ? 'Mon' : 'Thu'}`}</div>
          </div>
          <div className="card" onClick={() => setSunnah(s => ({...s, miswak: !s.miswak}))} style={{ background: sunnah.miswak ? 'var(--green)' : 'var(--card)', textAlign: 'center', cursor: 'pointer' }}>
            <div style={{ fontSize: '20px' }}>🪥</div>
            <div style={{ fontSize: '12px', fontWeight: 'bold', marginTop: '6px' }}>Miswak</div>
          </div>
          <div className="card" onClick={() => setSunnah(s => ({...s, sadaqah: !s.sadaqah}))} style={{ background: sunnah.sadaqah ? 'var(--green)' : 'var(--card)', textAlign: 'center', cursor: 'pointer' }}>
            <div style={{ fontSize: '20px' }}>💰</div>
            <div style={{ fontSize: '12px', fontWeight: 'bold', marginTop: '6px' }}>Sadaqah</div>
          </div>
          <div className="card" onClick={() => { if(sunnah.dhikrCount < 99) setSunnah(s => ({...s, dhikrCount: s.dhikrCount+1, dhikr: s.dhikrCount+1===99})) }} style={{ background: sunnah.dhikr ? 'var(--green)' : 'var(--card)', textAlign: 'center', cursor: 'pointer', gridColumn: 'span 3' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <span style={{ fontSize: '20px' }}>🤲</span>
                <span style={{ fontSize: '14px', fontWeight: 'bold' }}>Dhikr {sunnah.dhikr && '✓'}</span>
              </div>
              <span style={{ fontSize: '16px', fontWeight: 'bold', color: 'var(--gold)' }}>{sunnah.dhikrCount}/99</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '11px', color: 'var(--muted)', marginTop: '8px' }}>
              <span>Subhanallah {Math.min(33, sunnah.dhikrCount)}</span>
              <span>Alhamdulillah {Math.max(0, Math.min(33, sunnah.dhikrCount - 33))}</span>
              <span>AllahuAkbar {Math.max(0, sunnah.dhikrCount - 66)}</span>
            </div>
          </div>
          <div className="card" onClick={() => isFriday && setSunnah(s => ({...s, alKahf: !s.alKahf}))} style={{ background: sunnah.alKahf ? 'var(--green)' : 'var(--card)', opacity: isFriday ? 1 : 0.5, textAlign: 'center', cursor: isFriday ? 'pointer' : 'default' }}>
            <div style={{ fontSize: '20px' }}>📖</div>
            <div style={{ fontSize: '12px', fontWeight: 'bold', marginTop: '6px' }}>Al-Kahf</div>
            <div style={{ fontSize: '9px', color: 'var(--muted)', marginTop: '4px' }}>Friday only</div>
          </div>
          <div className="card" onClick={() => setSunnah(s => ({...s, alMulk: !s.alMulk}))} style={{ background: sunnah.alMulk ? 'var(--green)' : 'var(--card)', textAlign: 'center', cursor: 'pointer' }}>
            <div style={{ fontSize: '20px' }}>🌙</div>
            <div style={{ fontSize: '12px', fontWeight: 'bold', marginTop: '6px' }}>Al-Mulk</div>
            <div style={{ fontSize: '9px', color: 'var(--muted)', marginTop: '4px' }}>Nightly</div>
          </div>
        </div>

        <div className="section-title">Prayers</div>
        <SectionHadith data={SECTION_HADITHS.prayers} />
        <div className="card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', borderLeft: '4px solid var(--gold)' }}>
          <div>
            <div style={{ fontSize: '11px', color: 'var(--muted)', letterSpacing: '1.5px', fontWeight: 'bold' }}>NEXT PRAYER</div>
            <div style={{ fontSize: '18px', fontWeight: 900, color: 'var(--gold)', marginTop: '4px' }}>{nextPrayer.name}</div>
          </div>
          <div style={{ fontSize: '24px', fontWeight: 900 }}>{nextPrayer.time}</div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '8px', marginBottom: '8px' }}>
          {prayers.slice(0, 4).map((p, i) => (
            <div key={i} className="card" onClick={() => { if(!p.missed) { const newP = [...prayers]; newP[i].done = !newP[i].done; setPrayers(newP); updateStreak(`prayer_${p.id}`, newP[i].done); } }} style={{ padding: '12px 0', textAlign: 'center', cursor: p.missed ? 'not-allowed' : 'pointer', background: p.done ? 'var(--green)' : 'var(--card)', borderColor: p.missed ? 'var(--red)' : p.id === nextPrayer.id ? 'var(--gold)' : 'var(--border)' }}>
              <div style={{ fontSize: '12px', fontWeight: 'bold', color: p.done ? '#fff' : p.missed ? 'var(--red)' : 'var(--text)', marginBottom: '8px' }}>{p.id.toUpperCase()}</div>
              {p.done ? <div style={{ background: 'var(--greenLight)', color: '#fff', width: '24px', height: '24px', borderRadius: '50%', margin: '0 auto', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '14px', fontWeight: 'bold' }}>✓</div> : p.missed ? <div style={{ background: 'var(--red)', color: '#fff', width: '24px', height: '24px', borderRadius: '6px', margin: '0 auto', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '14px', fontWeight: 'bold' }}>✕</div> : <div style={{ width: '20px', height: '20px', borderRadius: '50%', border: '2px solid var(--border)', margin: '0 auto' }} />}
            </div>
          ))}
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '8px', marginBottom: '32px' }}>
          {prayers.slice(4).map((p, i) => {
            const actualIdx = i + 4;
            return (
            <div key={actualIdx} className="card" onClick={() => { if(!p.missed) { const newP = [...prayers]; newP[actualIdx].done = !newP[actualIdx].done; setPrayers(newP); updateStreak(`prayer_${p.id}`, newP[actualIdx].done); } }} style={{ padding: '12px 0', textAlign: 'center', cursor: p.missed ? 'not-allowed' : 'pointer', background: p.done ? 'var(--green)' : 'var(--card)', borderColor: p.missed ? 'var(--red)' : p.id === nextPrayer.id ? 'var(--gold)' : 'var(--border)' }}>
              <div style={{ fontSize: '12px', fontWeight: 'bold', color: p.done ? '#fff' : p.missed ? 'var(--red)' : 'var(--text)', marginBottom: '8px' }}>{p.id.toUpperCase()}</div>
              {p.done ? <div style={{ background: 'var(--greenLight)', color: '#fff', width: '24px', height: '24px', borderRadius: '50%', margin: '0 auto', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '14px', fontWeight: 'bold' }}>✓</div> : p.missed ? <div style={{ background: 'var(--red)', color: '#fff', width: '24px', height: '24px', borderRadius: '6px', margin: '0 auto', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '14px', fontWeight: 'bold' }}>✕</div> : <div style={{ width: '20px', height: '20px', borderRadius: '50%', border: '2px solid var(--border)', margin: '0 auto' }} />}
            </div>
          )})}
        </div>

        <div className="section-title">Daily Tasks</div>
        <SectionHadith data={SECTION_HADITHS.quran} />
        <div style={{ height: '4px', background: 'var(--border)', borderRadius: '2px', overflow: 'hidden', marginBottom: '16px' }}>
          <div style={{ height: '100%', width: `${(tasks.filter(t=>t.done).length / tasks.length)*100}%`, background: 'var(--gold)', animation: 'gold-shimmer 2s infinite linear', backgroundImage: 'linear-gradient(90deg, var(--gold), #fbbf24, var(--gold))', backgroundSize: '200% 100%', transition: 'width 0.3s ease' }} />
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginBottom: '32px' }}>
          {tasks.map((task, i) => (
            <div key={task.id} className="card" onClick={() => { const newT = [...tasks]; newT[i].done = !newT[i].done; setTasks(newT); updateStreak(`task_${task.id}`, newT[i].done); }} style={{ display: 'flex', alignItems: 'center', padding: '16px', cursor: 'pointer', borderLeft: `4px solid ${task.color}`, background: task.done ? 'var(--green)' : 'var(--card)', animation: task.done ? 'fadeInGreen 0.3s forwards' : 'none' }}>
              <span style={{ fontSize: '24px', marginRight: '16px' }}>{task.emoji}</span>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: '15px', fontWeight: 'bold', color: task.done ? '#fff' : 'var(--text)', textDecoration: task.done ? 'line-through' : 'none' }}>{task.title}</div>
                <div style={{ fontSize: '11px', color: task.done ? '#ccc' : 'var(--muted)', marginTop: '4px' }}>{task.sub}</div>
              </div>
              <div style={{ width: '24px', height: '24px', borderRadius: '50%', border: task.done ? 'none' : '2px solid var(--border)', background: task.done ? 'var(--greenLight)' : 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                {task.done && <span style={{ color: '#fff', fontSize: '14px', fontWeight: 'bold' }}>✓</span>}
              </div>
            </div>
          ))}
        </div>

        <div className="section-title">Water Intake</div>
        <SectionHadith data={SECTION_HADITHS.water} />
        <div className="card" style={{ marginBottom: '32px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
            <div style={{ fontSize: '13px', fontWeight: 'bold', color: 'var(--muted)' }}>{water}/10 Glasses</div>
            <div style={{ fontSize: '15px', fontWeight: 900, color: 'var(--blue)' }}>{(water * 0.26).toFixed(1)}L / 2.6L</div>
          </div>
          <div style={{ height: '6px', background: 'var(--border)', borderRadius: '3px', overflow: 'hidden', marginBottom: '24px' }}>
            <div style={{ height: '100%', width: `${(water / 10)*100}%`, background: 'var(--blue)', transition: 'width 0.3s ease' }} />
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '12px', justifyContent: 'center' }}>
            {Array.from({length: 10}).map((_, i) => (
              <div key={i} onClick={() => setWater(i+1)} style={{ width: '28px', height: '38px', borderRadius: '2px 2px 8px 8px', border: `2px solid ${i < water ? 'var(--blue)' : 'var(--border)'}`, position: 'relative', overflow: 'hidden', cursor: 'pointer' }}>
                {i < water && <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: '80%', background: 'rgba(59, 130, 246, 0.5)', animation: 'wave 2s infinite linear', borderTop: '2px solid rgba(255,255,255,0.4)' }} />}
              </div>
            ))}
          </div>
        </div>
      </div>
    );
  };

  const renderGoals = () => {
    const totalActive = Object.values(streaks).filter(v => v > 0).length;
    const maxGoals = tasks.length + 1; // 5 tasks + 1 prayer goal

    return (
      <div className="fade-in">
        <div style={{ fontSize: '24px', fontWeight: 900, color: 'var(--text)', marginBottom: '8px' }}>Goals · الأهداف</div>
        <div style={{ fontSize: '13px', color: 'var(--muted)', marginBottom: '24px' }}>Your Today tasks are your goals</div>

        <div className="card" style={{ background: 'linear-gradient(135deg, var(--gold), var(--green))', border: 'none', display: 'flex', alignItems: 'center', gap: '16px', marginBottom: '24px' }}>
          <span style={{ fontSize: '32px' }}>🔥</span>
          <div style={{ color: '#fff', fontSize: '16px', fontWeight: 'bold' }}>{totalActive > 0 ? `${Math.max(...Object.values(streaks))} day top streak — MashaAllah! 🌟` : '0 day streak — Start today!'}</div>
        </div>

        {[{ id: 'all_prayers', title: 'All 7 Prayers', sub: 'Tahajjud to Isha', color: 'var(--gold)', emoji: '🕌' }, ...tasks].map((goal, i) => {
          const streak = streaks[goal.id === 'all_prayers' ? 'prayer_all' : `task_${goal.id}`] || 0;
          const isDone = goal.id === 'all_prayers' ? prayers.every(p=>p.done) : tasks.find(t=>t.id===goal.id).done;
          return (
            <div key={i} className="card" style={{ borderLeft: `4px solid ${goal.color}`, marginBottom: '16px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '16px', marginBottom: '16px' }}>
                <div style={{ width: '48px', height: '48px', borderRadius: '12px', background: 'var(--bg)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '24px' }}>{goal.emoji}</div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: '16px', fontWeight: 'bold', color: 'var(--text)' }}>{goal.title}</div>
                  <div style={{ fontSize: '12px', color: 'var(--muted)', marginTop: '4px' }}>{goal.sub}</div>
                </div>
                <div style={{ fontSize: '14px', fontWeight: 'bold', color: goal.color }}>{Math.min(100, Math.round((streak/30)*100))}%</div>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div style={{ fontSize: '13px', fontWeight: 'bold', color: 'var(--text)' }}>🔥 {streak} days</div>
                <button onClick={() => {
                  if (goal.id === 'all_prayers') { setPrayers(prayers.map(p=>({...p, done: true}))); updateStreak('prayer_all', true); }
                  else { const newT = [...tasks]; const idx = newT.findIndex(t=>t.id===goal.id); newT[idx].done = !newT[idx].done; setTasks(newT); updateStreak(`task_${goal.id}`, newT[idx].done); }
                }} className="btn" style={{ background: isDone ? 'var(--green)' : 'transparent', border: `1px solid ${goal.color}`, color: isDone ? '#fff' : 'var(--text)' }}>{isDone ? '✓ Done' : 'Mark Done'}</button>
              </div>
            </div>
          );
        })}
        
        <div style={{ textAlign: 'center', fontSize: '12px', color: 'var(--muted)', marginTop: '32px' }}>{totalActive}/{maxGoals} goals active — {Math.round((totalActive/maxGoals)*100)}% this month</div>
      </div>
    );
  };

  const renderHabits = () => {
    const monthName = new Date().toLocaleString('default', { month: 'long' });
    const avgScore = history.length ? Math.round(history.reduce((a, b) => a + (b.taqwaScore||0), 0) / history.length) : 0;
    const missed = history.filter(h => (h.taqwaScore||0) < 50).length;
    
    // Generate 35 day heatmap grid
    const heatmap = Array.from({length: 35}).map((_, i) => {
      const h = history[history.length - 35 + i];
      return h ? h.taqwaScore : null;
    });

    const currentMonthEntries = income.entries.filter(e => new Date(e.date).getMonth() === todayDate.getMonth());
    const monthEarned = currentMonthEntries.reduce((a, b) => a + b.earned, 0);
    const monthSpent = currentMonthEntries.reduce((a, b) => a + b.spent, 0);

    return (
      <div className="fade-in">
        <div style={{ fontSize: '24px', fontWeight: 900, color: 'var(--text)', marginBottom: '8px' }}>Habits · العادات</div>
        <div style={{ fontSize: '13px', color: 'var(--muted)', marginBottom: '24px' }}>{monthName} Overview</div>

        <div className="card" style={{ marginBottom: '16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
            <div style={{ fontSize: '16px', fontWeight: 'bold' }}>Today progress</div>
            <div style={{ fontSize: '28px', fontWeight: 900, color: 'var(--gold)' }}>{score}%</div>
          </div>
          <div style={{ display: 'flex', gap: '8px' }}>
            <div className="card" style={{ flex: 1, padding: '12px', background: 'var(--bg)' }}>
              <div className="section-title">TASKS</div>
              <div style={{ fontSize: '20px', fontWeight: 'bold', color: 'var(--green)' }}>{tasks.filter(t=>t.done).length}/5</div>
            </div>
            <div className="card" style={{ flex: 1, padding: '12px', background: 'var(--bg)' }}>
              <div className="section-title">PRAYERS</div>
              <div style={{ fontSize: '20px', fontWeight: 'bold', color: 'var(--gold)' }}>{prayers.filter(p=>p.done).length}/7</div>
            </div>
          </div>
        </div>

        <div className="card" style={{ display: 'flex', justifyContent: 'space-between', padding: '16px', marginBottom: '24px' }}>
          <div style={{ textAlign: 'center' }}><div style={{ fontSize: '24px', fontWeight: 'bold', color: 'var(--green)' }}>{streaks['taqwa'] || 0}</div><div className="section-title">STREAK</div></div>
          <div style={{ width: '1px', background: 'var(--border)' }} />
          <div style={{ textAlign: 'center' }}><div style={{ fontSize: '24px', fontWeight: 'bold', color: 'var(--gold)' }}>{avgScore}%</div><div className="section-title">AVG</div></div>
          <div style={{ width: '1px', background: 'var(--border)' }} />
          <div style={{ textAlign: 'center' }}><div style={{ fontSize: '24px', fontWeight: 'bold', color: 'var(--red)' }}>{missed}</div><div className="section-title">MISSED</div></div>
        </div>

        <div className="card" style={{ marginBottom: '24px' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: '6px' }}>
            {heatmap.map((s, i) => {
              const bg = s === null ? 'var(--bg)' : s < 40 ? 'var(--red)' : s < 70 ? 'var(--orange)' : s < 90 ? 'var(--greenLight)' : 'var(--gold)';
              return <div key={i} style={{ aspectRatio: '1', borderRadius: '4px', background: bg, opacity: s===null ? 0.3 : 1 }} />;
            })}
          </div>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: '4px', marginTop: '12px', fontSize: '10px', color: 'var(--muted)' }}>
            Less <div style={{ width:'10px', height:'10px', background:'var(--red)' }}/> <div style={{ width:'10px', height:'10px', background:'var(--orange)' }}/> <div style={{ width:'10px', height:'10px', background:'var(--greenLight)' }}/> <div style={{ width:'10px', height:'10px', background:'var(--gold)' }}/> More
          </div>
        </div>

        <div className="card" style={{ marginBottom: '24px' }}>
          <div style={{ fontSize: '14px', fontWeight: 'bold', marginBottom: '16px' }}>💧 Water Today</div>
          <div style={{ fontSize: '12px', color: 'var(--blue)', fontWeight: 'bold', marginBottom: '12px' }}>{(water * 0.26).toFixed(1)}L / 2.6L</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px', pointerEvents: 'none' }}>
            {Array.from({length: 10}).map((_, i) => (
              <div key={i} style={{ width: '20px', height: '28px', borderRadius: '2px 2px 6px 6px', border: `2px solid ${i < water ? 'var(--blue)' : 'var(--border)'}`, position: 'relative', overflow: 'hidden' }}>
                {i < water && <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: '80%', background: 'var(--blue)' }} />}
              </div>
            ))}
          </div>
        </div>

        <div className="section-title">{monthName.toUpperCase()} 30 DAY DATA</div>
        <div className="card" onClick={() => setTab('income')} style={{ cursor: 'pointer', marginBottom: '24px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '16px' }}>
            <div style={{ fontSize: '14px', fontWeight: 'bold' }}>💰 INCOME</div>
            <div style={{ fontSize: '11px', color: 'var(--muted)' }}>Tap to edit →</div>
          </div>
          <div style={{ display: 'flex', gap: '8px' }}>
            <div style={{ flex: 1, background: 'var(--bg)', padding: '12px', borderRadius: '8px', textAlign: 'center' }}><div className="section-title">EARNED</div><div style={{ color: 'var(--teal)', fontWeight: 'bold', marginTop: '4px' }}>₹{monthEarned}</div></div>
            <div style={{ flex: 1, background: 'var(--bg)', padding: '12px', borderRadius: '8px', textAlign: 'center' }}><div className="section-title">SPENT</div><div style={{ color: 'var(--red)', fontWeight: 'bold', marginTop: '4px' }}>₹{monthSpent}</div></div>
            <div style={{ flex: 1, background: 'var(--bg)', padding: '12px', borderRadius: '8px', textAlign: 'center' }}><div className="section-title">NET</div><div style={{ color: monthEarned-monthSpent>=0 ? 'var(--green)' : 'var(--red)', fontWeight: 'bold', marginTop: '4px' }}>₹{monthEarned-monthSpent}</div></div>
          </div>
        </div>
      </div>
    );
  };

  const renderWorkout = () => {
    const [editMode, setEditMode] = useState(false);
    const [activeWorkout, setActiveWorkout] = useState(null);

    if (activeWorkout) {
      const day = workout.find(w => w.id === activeWorkout.dayId);
      const ex = day.exercises[activeWorkout.exerciseIndex];
      return (
        <div style={{ position: 'fixed', inset: 0, background: 'var(--bg)', zIndex: 100, padding: '40px 20px', display: 'flex', flexDirection: 'column' }}>
          <div style={{ fontSize: '14px', color: 'var(--gold)', letterSpacing: '2px', textTransform: 'uppercase', textAlign: 'center', marginBottom: '40px' }}>{day.day}</div>
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
            <div style={{ fontSize: '32px', fontWeight: 900, color: 'var(--text)', textAlign: 'center', marginBottom: '16px' }}>{ex.name}</div>
            <div style={{ fontSize: '18px', color: 'var(--muted)', marginBottom: '40px' }}>Set {activeWorkout.setIndex + 1} of {ex.sets}</div>
            <div style={{ fontSize: '80px', fontWeight: 900, color: 'var(--gold)' }} onClick={() => setActiveWorkout({...activeWorkout, repCount: activeWorkout.repCount + 1})}>{activeWorkout.repCount}</div>
            <div style={{ fontSize: '14px', color: 'var(--muted)' }}>Target: {ex.reps} {ex.isSeconds ? 'sec' : 'reps'} (Tap to count)</div>
          </div>
          <div style={{ display: 'flex', gap: '12px', marginBottom: '20px' }}>
            <button className="btn" style={{ flex: 1, background: 'var(--card)', border: '1px solid var(--border)', color: 'var(--text)' }} onClick={() => setActiveWorkout(null)}>✕ Cancel</button>
            <button className="btn" style={{ flex: 2, background: 'var(--teal)', color: '#fff' }} onClick={() => {
              if (activeWorkout.setIndex + 1 < ex.sets) setActiveWorkout({...activeWorkout, setIndex: activeWorkout.setIndex + 1, repCount: 0});
              else if (activeWorkout.exerciseIndex + 1 < day.exercises.length) setActiveWorkout({...activeWorkout, exerciseIndex: activeWorkout.exerciseIndex + 1, setIndex: 0, repCount: 0});
              else { setWorkoutDone(true); setActiveWorkout(null); updateStreak('workout', true); }
            }}>Next {activeWorkout.setIndex + 1 < ex.sets ? 'Set' : 'Exercise'} →</button>
          </div>
        </div>
      );
    }

    return (
      <div className="fade-in">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
          <div style={{ fontSize: '24px', fontWeight: 900, color: 'var(--text)' }}>Workout · التدريب</div>
          <button onClick={() => setEditMode(!editMode)} style={{ background: 'transparent', border: 'none', color: 'var(--gold)', fontSize: '14px', fontWeight: 'bold' }}>{editMode ? '✓ Done Editing' : '✏️ Edit'}</button>
        </div>
        <div style={{ fontSize: '13px', color: 'var(--muted)', marginBottom: '16px' }}>4-day bodyweight plan</div>
        <SectionHadith data={SECTION_HADITHS.workout} />

        {workout.map((w, wIdx) => (
          <div key={w.id} className="card" style={{ marginBottom: '16px', borderColor: workoutDone && new Date().getDay() === wIdx ? 'var(--greenLight)' : 'var(--border)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
              {editMode ? <input className="input" value={w.day} onChange={e => { const nw = [...workout]; nw[wIdx].day = e.target.value; setWorkout(nw); }} style={{ flex: 1, marginRight: '12px' }} /> : <div style={{ fontSize: '16px', fontWeight: 'bold', color: 'var(--greenLight)' }}>{w.icon} {w.day}</div>}
              {!editMode && <div style={{ fontSize: '12px', background: 'var(--bg)', padding: '4px 8px', borderRadius: '4px', color: 'var(--muted)' }}>{w.schedule}</div>}
            </div>
            
            {w.exercises.map((ex, eIdx) => (
              <div key={ex.id} style={{ background: 'var(--bg)', padding: '12px', borderRadius: '8px', marginBottom: '8px' }}>
                {editMode ? (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    <input className="input" value={ex.name} onChange={e => { const nw = [...workout]; nw[wIdx].exercises[eIdx].name = e.target.value; setWorkout(nw); }} />
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <input className="input" type="number" value={ex.sets} onChange={e => { const nw = [...workout]; nw[wIdx].exercises[eIdx].sets = Number(e.target.value); setWorkout(nw); }} style={{ width: '60px' }} placeholder="Sets" />
                      <input className="input" type="number" value={ex.reps} onChange={e => { const nw = [...workout]; nw[wIdx].exercises[eIdx].reps = Number(e.target.value); setWorkout(nw); }} style={{ width: '60px' }} placeholder="Reps" />
                      <button className="btn" style={{ background: 'var(--red)', color: '#fff', padding: '8px' }} onClick={() => { const nw = [...workout]; nw[wIdx].exercises.splice(eIdx, 1); setWorkout(nw); }}>🗑</button>
                    </div>
                  </div>
                ) : (
                  <>
                    <div style={{ fontSize: '14px', fontWeight: 'bold', marginBottom: '4px' }}>{ex.name}</div>
                    <div style={{ fontSize: '12px', color: 'var(--muted)', marginBottom: '8px' }}>{ex.sets} sets × {ex.reps} {ex.isSeconds ? 'sec' : 'reps'}</div>
                    <div style={{ display: 'flex', gap: '6px' }}>{ex.muscles.map((m, i) => <span key={i} style={{ fontSize: '9px', background: 'var(--card)', padding: '2px 6px', borderRadius: '4px', border: '1px solid var(--border)' }}>{m}</span>)}</div>
                  </>
                )}
              </div>
            ))}
            
            {editMode ? (
              <button className="btn" style={{ width: '100%', background: 'transparent', border: '1px dashed var(--gold)', color: 'var(--gold)', marginTop: '8px' }} onClick={() => { const nw = [...workout]; nw[wIdx].exercises.push({ id: Date.now(), name: "New Exercise", sets: 3, reps: 10, muscles: [] }); setWorkout(nw); }}>＋ Add Exercise</button>
            ) : (
              <button className="btn" style={{ width: '100%', background: 'var(--green)', color: '#fff', marginTop: '16px' }} onClick={() => setActiveWorkout({ dayId: w.id, exerciseIndex: 0, setIndex: 0, repCount: 0 })}>▶ Start Workout</button>
            )}
          </div>
        ))}
        <div style={{ textAlign: 'center', fontSize: '11px', color: 'var(--muted)', marginTop: '24px' }}>Consistency beats perfection. · 4-day split · Bodyweight · No equipment needed</div>
      </div>
    );
  };

  const renderIncome = () => {
    const [earnedIn, setEarnedIn] = useState('');
    const [spentIn, setSpentIn] = useState('');
    const [filter, setFilter] = useState('All');

    const currentMonthEntries = income.entries.filter(e => new Date(e.date).getMonth() === todayDate.getMonth());
    const totalEarned = currentMonthEntries.reduce((a, b) => a + b.earned, 0);
    const totalSpent = currentMonthEntries.reduce((a, b) => a + b.spent, 0);
    const targetProgress = Math.min(1, totalEarned / income.monthlyTarget);

    const handleAdd = (type) => {
      const val = type === 'earn' ? Number(earnedIn) : Number(spentIn);
      if (val > 0) {
        const newEntry = { id: Date.now(), date: new Date().toISOString(), earned: type === 'earn' ? val : 0, spent: type === 'spend' ? val : 0 };
        setIncome({ ...income, entries: [newEntry, ...income.entries] });
        type === 'earn' ? setEarnedIn('') : setSpentIn('');
      }
    };

    const filtered = income.entries.filter(e => filter === 'All' ? true : filter === 'Income' ? e.earned > 0 : e.spent > 0);

    return (
      <div className="fade-in">
        <div style={{ fontSize: '24px', fontWeight: 900, color: 'var(--text)', marginBottom: '8px' }}>₹10K/day Plan · خطة الدخل</div>
        <div style={{ fontSize: '13px', color: 'var(--muted)', marginBottom: '16px' }}>Automation career to ₹3 lakhs/month</div>
        <SectionHadith data={SECTION_HADITHS.income} />

        <div className="card" style={{ marginBottom: '20px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '16px' }}>
            <div>
              <div style={{ fontSize: '32px', fontWeight: 900, color: 'var(--gold)' }}>₹{totalEarned.toLocaleString()}</div>
              <div style={{ fontSize: '11px', color: 'var(--muted)' }}>earned this month</div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontSize: '16px', fontWeight: 'bold', color: 'var(--teal)' }}>₹{Math.round(totalEarned/Math.max(1, todayDate.getDate())).toLocaleString()}/day</div>
              <div style={{ fontSize: '10px', color: 'var(--muted)' }}>daily avg</div>
            </div>
          </div>
          <div style={{ height: '6px', background: 'var(--bg)', borderRadius: '3px', overflow: 'hidden', marginBottom: '8px' }}>
            <div style={{ height: '100%', width: `${targetProgress*100}%`, background: 'var(--gold)' }} />
          </div>
          <div style={{ fontSize: '10px', color: 'var(--gold)' }}>{Math.round(targetProgress*100)}% of ₹{(income.monthlyTarget).toLocaleString()} target</div>
        </div>

        <div style={{ display: 'flex', gap: '8px', marginBottom: '24px' }}>
          <div className="card" style={{ flex: 1, padding: '12px' }}><div className="section-title">EARNED</div><div style={{ fontSize: '16px', fontWeight: 'bold', color: 'var(--teal)', marginTop: '4px' }}>₹{totalEarned}</div></div>
          <div className="card" style={{ flex: 1, padding: '12px' }}><div className="section-title">SPENT</div><div style={{ fontSize: '16px', fontWeight: 'bold', color: 'var(--red)', marginTop: '4px' }}>₹{totalSpent}</div></div>
          <div className="card" style={{ flex: 1, padding: '12px' }}><div className="section-title">SAVINGS</div><div style={{ fontSize: '16px', fontWeight: 'bold', color: totalEarned-totalSpent>=0?'var(--greenLight)':'var(--red)', marginTop: '4px' }}>₹{totalEarned-totalSpent}</div></div>
        </div>

        <div style={{ display: 'flex', gap: '8px', marginBottom: '12px' }}>
          <input className="input" type="number" value={earnedIn} onChange={e=>setEarnedIn(e.target.value)} placeholder="Enter today earnings ₹" style={{ flex: 1 }} />
          <button className="btn" onClick={()=>handleAdd('earn')} style={{ width: '48px', background: 'var(--teal)', color: '#fff' }}>+</button>
        </div>
        <div style={{ display: 'flex', gap: '8px', marginBottom: '24px' }}>
          <input className="input" type="number" value={spentIn} onChange={e=>setSpentIn(e.target.value)} placeholder="Enter today expense ₹" style={{ flex: 1 }} />
          <button className="btn" onClick={()=>handleAdd('spend')} style={{ width: '48px', background: 'var(--red)', color: '#fff' }}>+</button>
        </div>

        <div style={{ display: 'flex', gap: '8px', marginBottom: '16px' }}>
          {['All', 'Income', 'Expenses'].map(f => (
            <button key={f} className="btn" onClick={()=>setFilter(f)} style={{ flex: 1, padding: '8px', fontSize: '12px', background: filter===f ? 'var(--card)' : 'transparent', border: `1px solid ${filter===f ? 'var(--gold)' : 'var(--border)'}`, color: filter===f ? 'var(--gold)' : 'var(--muted)' }}>{f}</button>
          ))}
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
          {filtered.map(entry => (
            <div key={entry.id} className="card" style={{ display: 'flex', justifyContent: 'space-between', padding: '12px 16px' }}>
              <div style={{ fontSize: '14px', color: 'var(--text)' }}>{new Date(entry.date).toLocaleDateString('en-US', { day:'numeric', month:'short' })}</div>
              <div style={{ display: 'flex', gap: '16px' }}>
                {entry.earned > 0 && <div style={{ fontSize: '14px', fontWeight: 'bold', color: 'var(--teal)' }}>+₹{entry.earned}</div>}
                {entry.spent > 0 && <div style={{ fontSize: '14px', fontWeight: 'bold', color: 'var(--red)' }}>-₹{entry.spent}</div>}
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  };

  const renderTodo = () => {
    const [newTodo, setNewTodo] = useState('');
    const addTodo = () => {
      if (newTodo.trim()) {
        setTodo([{ id: Date.now(), title: newTodo, createdAt: new Date().toISOString(), done: false }, ...todo]);
        setNewTodo('');
      }
    };

    return (
      <div className="fade-in">
        <div style={{ fontSize: '24px', fontWeight: 900, color: 'var(--text)', marginBottom: '24px' }}>To-Do · المهام</div>
        <div style={{ display: 'flex', gap: '8px', marginBottom: '24px' }}>
          <input className="input" value={newTodo} onChange={e=>setNewTodo(e.target.value)} onKeyDown={e => e.key === 'Enter' && addTodo()} placeholder="Add a new task..." style={{ flex: 1 }} />
          <button className="btn" onClick={addTodo} style={{ width: '48px', background: 'var(--teal)', color: '#fff' }}>+</button>
        </div>

        {todo.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '40px 20px', color: 'var(--muted)' }}>
            <div style={{ fontSize: '40px', marginBottom: '16px' }}>✨</div>
            <div style={{ fontSize: '16px', fontWeight: 'bold' }}>لا مهام · No tasks yet</div>
            <div style={{ fontSize: '13px', marginTop: '8px' }}>Add one above to get started</div>
          </div>
        ) : (
          todo.map(t => (
            <TodoItem key={t.id} task={t} 
              onToggle={() => { const n = [...todo]; const i = n.findIndex(x=>x.id===t.id); n[i].done = !n[i].done; setTodo(n); }} 
              onDelete={() => setTodo(todo.filter(x=>x.id!==t.id))} 
            />
          ))
        )}
      </div>
    );
  };

  return (
    <div className={`theme-${isDark ? 'dark' : 'light'}`} style={{ backgroundColor: 'var(--bg)', color: 'var(--text)', minHeight: '100vh', fontFamily: 'system-ui, -apple-system, sans-serif', maxWidth: '390px', margin: '0 auto', position: 'relative', overflowX: 'hidden' }}>
      <style>{`
        .theme-dark { --bg: ${C.bg}; --card: ${C.card}; --green: ${C.green}; --greenLight: ${C.greenLight}; --gold: ${C.gold}; --goldLight: ${C.goldLight}; --text: ${C.text}; --muted: ${C.muted}; --border: ${C.border}; --teal: ${C.teal}; --red: ${C.red}; --blue: ${C.blue}; --orange: ${C.orange}; }
        .theme-light { --bg: ${C.bgLight}; --card: ${C.cardLight}; --green: ${C.green}; --greenLight: ${C.greenLight}; --gold: ${C.gold}; --goldLight: ${C.goldLight}; --text: ${C.textLight}; --muted: ${C.mutedLight}; --border: ${C.borderLight}; --teal: ${C.teal}; --red: ${C.red}; --blue: ${C.blue}; --orange: ${C.orange}; }
        * { box-sizing: border-box; }
        body { margin: 0; background: #000; }
        .card { background: var(--card); border-radius: 16px; padding: 16px; border: 1px solid var(--border); transition: all 0.2s ease; }
        .section-title { font-size: 11px; letter-spacing: 3px; text-transform: uppercase; color: var(--gold); font-weight: bold; margin-bottom: 8px; }
        .large-num { font-size: 32px; font-weight: 900; color: var(--gold); text-shadow: 0 0 20px #d4a01766; line-height: 1; }
        .btn { border-radius: 24px; padding: 8px 20px; border: none; cursor: pointer; font-weight: bold; transition: all 0.2s ease; outline: none; display: flex; align-items: center; justify-content: center; }
        .input { background: var(--card); border: 1px solid var(--border); border-radius: 12px; color: var(--text); padding: 12px 16px; outline: none; width: 100%; transition: all 0.2s ease; }
        .input:focus { border-color: var(--gold); }
        .fade-in { animation: fadeIn 0.3s ease-out; }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
        @keyframes pulse-glow { 0%, 100% { filter: drop-shadow(0 0 8px #d4a01744); } 50% { filter: drop-shadow(0 0 24px #d4a017aa); } }
        @keyframes gold-shimmer { 0% { background-position: -200% center; } 100% { background-position: 200% center; } }
        @keyframes wave { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(-3px); } }
        @keyframes fadeInGreen { from { background: var(--card); } to { background: var(--green); } }
      `}</style>

      <div style={{ padding: '20px 16px 120px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '24px' }}>
          <div>
            <div style={{ fontSize: '10px', color: 'var(--gold)', letterSpacing: '2px', fontWeight: 'bold' }}>بِسْمِ اللَّهِ</div>
            <div style={{ fontSize: '28px', fontWeight: 900, marginTop: '4px' }}>Rayees</div>
            <div style={{ fontSize: '12px', color: 'var(--gold)', letterSpacing: '1px', marginTop: '2px' }}>مُتَّقِين · MUTTAQIN</div>
          </div>
          <div onClick={() => setIsDark(!isDark)} style={{ width: '56px', height: '28px', borderRadius: '14px', background: isDark ? 'var(--gold)' : 'var(--green)', position: 'relative', cursor: 'pointer', transition: 'background 0.3s ease' }}>
            <div style={{ position: 'absolute', top: '2px', left: isDark ? '30px' : '2px', width: '24px', height: '24px', borderRadius: '50%', background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '12px', transition: 'left 0.3s ease' }}>{isDark ? '☀️' : '🌙'}</div>
          </div>
        </div>

        {tab === 'today' && renderToday()}
        {tab === 'goals' && renderGoals()}
        {tab === 'habits' && renderHabits()}
        {tab === 'workout' && renderWorkout()}
        {tab === 'income' && renderIncome()}
        {tab === 'todo' && renderTodo()}
      </div>

      <div style={{ position: 'fixed', bottom: 0, left: '50%', transform: 'translateX(-50%)', width: '100%', maxWidth: '390px', backgroundColor: 'var(--bg)', borderTop: '1px solid var(--border)', display: 'flex', justifyContent: 'space-around', alignItems: 'center', height: '70px', zIndex: 50 }}>
        <div style={{ position: 'absolute', top: '-26px', left: '50%', transform: 'translateX(-50%)', width: '52px', height: '52px', borderRadius: '50%', backgroundColor: 'var(--teal)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 4px 20px rgba(13,148,136,0.5)', zIndex: 60, fontSize: '24px' }}>
          {TABS.find(t=>t.id === tab)?.icon}
        </div>
        {TABS.map(t => (
          <div key={t.id} onClick={() => setTab(t.id)} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', opacity: tab === t.id ? 0 : 1, transition: 'opacity 0.2s' }}>
            <div style={{ fontSize: '20px', marginBottom: '4px' }}>{t.icon}</div>
            <div style={{ fontSize: '10px', fontWeight: 'bold', color: 'var(--muted)' }}>{t.label}</div>
          </div>
        ))}
      </div>
    </div>
  );
}