import React, { useState, useEffect } from 'react';

const TodayScreen = ({
  // Mocked state/props to match the requested data logic
  daysLeft = 222,
  score = 85,
  stats = { prayers: 5, tasks: 4, water: 6, streak: 12 },
  nextPrayer = { name: 'Asr', time: new Date(Date.now() + 3600000) },
  prayers = [
    { id: 'Fajr', done: true },
    { id: 'Dhuhr', done: true },
    { id: 'Asr', done: false },
    { id: 'Maghrib', done: false, missed: true },
    { id: 'Isha', done: false }
  ],
  tasks = [
    { id: '1', title: 'Quran', emoji: '📖', done: true, color: '#4ade80' },
    { id: '2', title: 'TIA Portal', emoji: '💻', done: false, color: '#3b82f6' },
    { id: '3', title: 'Morning Walk', emoji: '🚶', done: true, color: '#f59e0b' },
    { id: '4', title: 'Workout', emoji: '🏋️', done: false, color: '#ef4444' },
    { id: '5', title: 'Phone', emoji: '📱', done: false, color: '#a855f7' }
  ],
  water = 6,
  heatmap = Array.from({ length: 28 }, (_, i) => ({ day: i + 1, score: Math.floor(Math.random() * 100) })),
  onTogglePrayer,
  onToggleTask,
  onAddWater
}) => {
  // Count up animation hook
  const useCountUp = (end, duration = 1200) => {
    const [count, setCount] = useState(0);
    useEffect(() => {
      let startTime = null;
      const animate = (timestamp) => {
        if (!startTime) startTime = timestamp;
        const progress = Math.min((timestamp - startTime) / duration, 1);
        // easeOutQuart
        const ease = 1 - Math.pow(1 - progress, 4);
        setCount(Math.floor(ease * end));
        if (progress < 1) requestAnimationFrame(animate);
      };
      requestAnimationFrame(animate);
    }, [end, duration]);
    return count;
  };

  const pCount = useCountUp(stats.prayers);
  const tCount = useCountUp(stats.tasks);
  const wCount = useCountUp(stats.water);
  const sCount = useCountUp(stats.streak);

  const [isDark, setIsDark] = useState(true);
  const today = new Date().getDay(); // 0=Sun,1=Mon,4=Thu
  const isFastingDay = today === 1 || today === 4;
  const fastingLabel = today === 1 ? "Monday" : today === 4 ? "Thursday" : null;
  const [fasting, setFasting] = useState(false);

  // Countdown timer
  const [timeLeft, setTimeLeft] = useState('00:00');
  useEffect(() => {
    const timer = setInterval(() => {
      const diff = Math.max(0, nextPrayer.time - new Date());
      const m = Math.floor((diff / 1000 / 60) % 60).toString().padStart(2, '0');
      const s = Math.floor((diff / 1000) % 60).toString().padStart(2, '0');
      setTimeLeft(`${m}:${s}`);
    }, 1000);
    return () => clearInterval(timer);
  }, [nextPrayer]);

  // Ripple effect for water
  const [rippleId, setRippleId] = useState(null);
  const handleWaterClick = (i) => {
    setRippleId(i);
    setTimeout(() => setRippleId(null), 500);
    if (onAddWater) onAddWater(i + 1);
  };

  let finalScore = score;
  if (isFastingDay) {
    const currentPoints = (score / 100) * 100;
    const extra = fasting ? 10 : 0;
    finalScore = Math.round(((currentPoints + extra) / 110) * 100);
  }

  const getScoreLabel = (s) => {
    if (s === 0) return null;
    if (s < 40) return "Keep Going 💪";
    if (s < 75) return "Almost There 🔥";
    if (s < 100) return "On Fire! ⚡";
    return "Perfect Day! 🌟";
  };

  return (
    <div style={{ maxWidth: '390px', margin: '0 auto', backgroundColor: '#070d1a', color: '#fff', minHeight: '100vh', padding: '20px 16px 100px 16px', boxSizing: 'border-box', overflowX: 'hidden', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <style>{`
        @keyframes pulse-glow {
          0% { box-shadow: 0 0 0 0 rgba(245, 158, 11, 0.4); }
          70% { box-shadow: 0 0 0 20px rgba(245, 158, 11, 0); }
          100% { box-shadow: 0 0 0 0 rgba(245, 158, 11, 0); }
        }
        @keyframes green-pulse {
          0% { transform: scale(1); box-shadow: 0 0 0 0 rgba(74, 222, 128, 0.7); }
          50% { transform: scale(1.15); box-shadow: 0 0 15px 5px rgba(74, 222, 128, 0); }
          100% { transform: scale(1); }
        }
        @keyframes shimmer {
          0% { background-position: -200% 0; }
          100% { background-position: 200% 0; }
        }
        @keyframes wave {
          0% { transform: translateX(0) translateZ(0) scaleY(1); }
          50% { transform: translateX(-25%) translateZ(0) scaleY(1.05); }
          100% { transform: translateX(-50%) translateZ(0) scaleY(1); }
        }
        @keyframes ripple-anim {
          0% { transform: scale(0.5); opacity: 1; }
          100% { transform: scale(2.5); opacity: 0; }
        }
        .theme-container {
          --bg-base: #fdfbf7;
          --text-main: #1e293b;
          --text-muted: #64748b;
          --card-bg: rgba(255, 255, 255, 0.6);
          --card-border: rgba(0, 0, 0, 0.05);
          --banner-bg: linear-gradient(135deg, #fffbeb, #fef3c7);
          --banner-text: #b45309;
          --glass-shadow: rgba(0, 0, 0, 0.05);
          --tooltip-bg: #fff;
          --tooltip-text: #1e293b;
        }
        .theme-container.dark {
            --bg-base: #070d1a;
            --text-main: #f8fafc;
            --text-muted: #94a3b8;
            --card-bg: #0f1c2e;
            --card-border: rgba(255, 255, 255, 0.06);
            --banner-bg: linear-gradient(135deg, #451a03, #78350f);
            --banner-text: #fff;
            --glass-shadow: rgba(0, 0, 0, 0.3);
            --tooltip-bg: #1e293b;
            --tooltip-text: #f8fafc;
          }
        }
        .glass-card {
          backdrop-filter: blur(20px);
          -webkit-backdrop-filter: blur(20px);
          background: var(--card-bg);
          border: 1px solid var(--card-border);
          border-radius: 16px;
          box-shadow: 0 4px 15px var(--glass-shadow);
        }
        .gradient-border {
          position: relative;
        }
        .gradient-border::before {
          content: "";
          position: absolute;
          inset: -1px;
          border-radius: 17px;
          padding: 1px;
          background: linear-gradient(135deg, rgba(255,255,255,0.15), rgba(255,255,255,0));
          -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
          -webkit-mask-composite: xor;
          mask-composite: exclude;
          pointer-events: none;
        }
        .prayer-card {
          transition: all 0.3s ease;
        }
        .prayer-card:hover {
          box-shadow: inset 0 0 15px rgba(255,255,255,0.05);
          transform: translateY(-2px);
        }
        .shimmer-line {
          height: 2px;
          background: linear-gradient(90deg, transparent, rgba(245, 158, 11, 0.5), transparent);
          background-size: 200% 100%;
          animation: shimmer 3s infinite linear;
        }
        .ripple {
          position: absolute;
          border-radius: 50%;
          background: rgba(255, 255, 255, 0.6);
          width: 20px;
          height: 20px;
          left: calc(50% - 10px);
          top: calc(50% - 10px);
          animation: ripple-anim 0.5s ease-out;
          pointer-events: none;
        }
        .heatmap-cell {
          position: relative;
        }
        .heatmap-cell:hover .tooltip {
          opacity: 1;
          visibility: visible;
        }
        .tooltip {
          opacity: 0;
          visibility: hidden;
          transition: all 0.2s ease;
          position: absolute;
          bottom: 120%;
          left: 50%;
          transform: translateX(-50%);
          background: var(--tooltip-bg);
          color: var(--tooltip-text);
          padding: 6px 10px;
          border-radius: 6px;
          font-size: 11px;
          font-weight: 600;
          white-space: nowrap;
          z-index: 10;
          box-shadow: 0 4px 6px var(--glass-shadow);
          border: 1px solid var(--card-border);
        }
        .tooltip::after {
          content: '';
          position: absolute;
          top: 100%;
          left: 50%;
          transform: translateX(-50%);
          border-width: 4px;
          border-style: solid;
          border-color: #1e293b transparent transparent transparent;
        }
      `}</style>

      {/* 1. Header Section */}
      <div className="glass-card gradient-border" style={{ padding: '20px 16px', textAlign: 'center', position: 'relative', marginBottom: '24px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px', marginBottom: '12px' }}>
          <span style={{ filter: 'drop-shadow(0 0 10px rgba(255,255,255,0.8))', fontSize: '18px' }}>🌙</span>
          <h2 style={{ margin: 0, letterSpacing: '3px', fontSize: '15px', color: '#e2e8f0', fontWeight: '700' }}>BISMILLAH</h2>
        </div>
        <div style={{ background: 'linear-gradient(135deg, #f59e0b, #ea580c)', padding: '6px 16px', borderRadius: '999px', display: 'inline-block', fontSize: '11px', fontWeight: '800', letterSpacing: '1.5px', boxShadow: '0 4px 10px rgba(245,158,11,0.2)' }}>
          LIFE PLAN 2027
        </div>
        <div className="shimmer-line" style={{ marginTop: '20px', width: '100%', opacity: 0.7 }} />
      </div>

      {/* 2. Days Counter */}
      <div style={{ background: 'linear-gradient(135deg, #451a03, #78350f)', borderRadius: '24px', padding: '32px 24px', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '28px', position: 'relative', overflow: 'hidden', boxShadow: '0 10px 25px rgba(0,0,0,0.3)' }}>
        <div style={{ position: 'absolute', width: '180px', height: '180px', borderRadius: '50%', border: '3px solid rgba(255,255,255,0.05)', borderTopColor: '#f59e0b', borderRightColor: '#ea580c', transform: `rotate(${(daysLeft / 365) * 360}deg)` }} />
        <div style={{ textAlign: 'center', position: 'relative', zIndex: 1 }}>
          <div style={{ fontSize: '72px', fontWeight: '900', lineHeight: 1, textShadow: '0 0 30px rgba(245,158,11,0.6)', color: '#fff' }}>{daysLeft}</div>
          <div style={{ fontSize: '12px', letterSpacing: '3px', marginTop: '12px', color: '#fbbf24', fontWeight: '700' }}>DAYS TO 2027</div>
        </div>
      </div>

      {/* 3. Stats Row */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '10px', marginBottom: '36px' }}>
        {[
          { label: 'Prayers', val: pCount, max: 7, color: '#4ade80', icon: '🕌' },
          { label: 'Tasks', val: tCount, max: tasks.length, color: '#3b82f6', icon: '✓' },
          { label: 'Water', val: wCount, max: 10, color: '#06b6d4', icon: '💧' },
          { label: 'Streak', val: sCount, max: null, color: '#f97316', icon: '🔥' }
        ].map((stat, i) => (
          <div key={i} className="glass-card" style={{ padding: '14px 8px', textAlign: 'center', background: `linear-gradient(180deg, var(--card-bg), ${stat.color}1a)` }}>
            <div style={{ fontSize: '18px', filter: `drop-shadow(0 0 8px ${stat.color}80)`, marginBottom: '6px' }}>{stat.icon}</div>
            <div style={{ fontSize: '20px', fontWeight: '800', color: stat.color }}>{stat.val}{stat.max ? `/${stat.max}` : ''}</div>
            <div style={{ fontSize: '10px', opacity: 0.7, marginTop: '4px', fontWeight: '600', letterSpacing: '0.5px' }}>{stat.label.toUpperCase()}</div>
          </div>
        ))}
      </div>

      {/* 4. Score Ring */}
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', marginBottom: '36px' }}>
        <div style={{ width: '130px', height: '130px', borderRadius: '50%', background: `conic-gradient(#f59e0b ${finalScore}%, #1e293b ${finalScore}%)`, display: 'flex', alignItems: 'center', justifyContent: 'center', animation: 'pulse-glow 2s infinite', marginBottom: '20px' }}>
          <div style={{ width: '114px', height: '114px', borderRadius: '50%', backgroundColor: 'var(--bg-base)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', boxShadow: 'inset 0 0 20px var(--glass-shadow)' }}>
            <span style={{ fontSize: '32px', fontWeight: '900', color: '#f59e0b', textShadow: '0 2px 10px rgba(245,158,11,0.3)' }}>{finalScore}%</span>
          </div>
        </div>
        {getScoreLabel(finalScore) && <div style={{ fontSize: '16px', fontWeight: '700', color: 'var(--text-main)', letterSpacing: '0.5px' }}>{getScoreLabel(finalScore)}</div>}
      </div>

      {/* Sunnah Fasting Tracker */}
      <div style={{ marginBottom: '36px' }}>
        <div className="glass-card" style={{ padding: '16px 20px', display: 'flex', flexDirection: 'column', gap: '12px', border: fasting && isFastingDay ? '1px solid #4ade80' : isFastingDay ? '1px solid #f59e0b' : '1px solid var(--card-border)' }}>
          <h3 style={{ margin: 0, fontSize: '13px', fontWeight: '800', letterSpacing: '1.5px', color: 'var(--text-muted)', textTransform: 'uppercase' }}>سنة الصيام · Sunnah Fast</h3>
          {isFastingDay ? (
            <>
              <div style={{ fontSize: '14px', fontWeight: '600', color: 'var(--text-main)' }}>
                Today is {fastingLabel} — Sunnah Fast Day 🌙
              </div>
              <button onClick={() => setFasting(!fasting)} style={{ padding: '10px 16px', borderRadius: '8px', border: 'none', background: fasting ? '#4ade80' : '#f59e0b', color: fasting ? '#064e3b' : '#fff', fontSize: '14px', fontWeight: '700', cursor: 'pointer', transition: 'background 0.3s' }}>
                {fasting ? '✓ Fasting Today' : 'Fasting / Not Fasting'}
              </button>
            </>
          ) : (
            <div style={{ fontSize: '14px', fontWeight: '600', color: 'var(--text-muted)' }}>
              Next: {today === 2 || today === 3 ? 'Thursday' : 'Monday'}
            </div>
          )}
        </div>
      </div>

      {/* 5. Prayers Section */}
      <div style={{ marginBottom: '36px' }}>
        <div className="glass-card" style={{ padding: '16px 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', borderLeft: '4px solid #f59e0b' }}>
          <div>
            <div style={{ fontSize: '11px', color: 'var(--text-muted)', fontWeight: '700', letterSpacing: '1.5px', marginBottom: '4px' }}>NEXT PRAYER</div>
            <div style={{ fontSize: '18px', fontWeight: '800', color: '#f59e0b' }}>{nextPrayer.name}</div>
          </div>
          <div style={{ fontSize: '28px', fontWeight: '900', fontVariantNumeric: 'tabular-nums', textShadow: '0 0 15px rgba(255,255,255,0.2)' }}>{timeLeft}</div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: '10px' }}>
          {prayers.map((p, i) => (
            <div key={i} onClick={() => onTogglePrayer?.(p.id)} className="glass-card prayer-card" style={{ padding: '14px 0', textAlign: 'center', cursor: 'pointer' }}>
              <div style={{ fontSize: '12px', marginBottom: '10px', fontWeight: '600', color: p.done ? 'var(--text-main)' : 'var(--text-muted)' }}>{p.id}</div>
              {p.done ? (
                <div style={{ width: '24px', height: '24px', borderRadius: '50%', background: '#4ade80', color: '#064e3b', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', fontSize: '14px', fontWeight: 'bold', animation: 'green-pulse 0.6s ease-out' }}>✓</div>
              ) : p.missed ? (
                <div style={{ width: '24px', height: '24px', borderRadius: '6px', background: 'linear-gradient(135deg, #ef4444, #b91c1c)', color: '#fff', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', fontSize: '16px', fontWeight: 'bold', boxShadow: '0 2px 8px rgba(239,68,68,0.4)' }}>✕</div>
              ) : (
                <div style={{ width: '20px', height: '20px', borderRadius: '50%', border: '2px solid rgba(255,255,255,0.15)', display: 'inline-block' }} />
              )}
            </div>
          ))}
        </div>
      </div>

      {/* 6. Daily Tasks */}
      <div style={{ marginBottom: '36px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '14px' }}>
          <h3 style={{ fontSize: '13px', fontWeight: '800', letterSpacing: '1.5px', color: 'var(--text-muted)', margin: 0 }}>DAILY TASKS</h3>
          <span style={{ fontSize: '13px', fontWeight: '700', color: '#3b82f6' }}>{tasks.filter(t => t.done).length}/{tasks.length}</span>
        </div>
        <div style={{ height: '4px', borderRadius: '2px', background: 'rgba(255,255,255,0.05)', overflow: 'hidden', marginBottom: '20px' }}>
          <div style={{ width: `${(tasks.filter(t => t.done).length / tasks.length) * 100}%`, height: '100%', background: 'linear-gradient(90deg, #1d4ed8, #3b82f6, #93c5fd)', backgroundSize: '200% 100%', animation: 'shimmer 2s infinite linear', transition: 'width 0.4s cubic-bezier(0.4, 0, 0.2, 1)' }} />
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          {tasks.map((task) => (
            <div key={task.id} onClick={() => onToggleTask?.(task.id)} className="glass-card" style={{ display: 'flex', alignItems: 'center', padding: '16px 20px', cursor: 'pointer', borderLeft: `4px solid ${task.color}`, boxShadow: `inset 15px 0 30px -15px ${task.color}40`, background: task.done ? 'rgba(74, 222, 128, 0.08)' : 'var(--card-bg)', transition: 'background 0.4s ease, transform 0.2s' }}>
              <span style={{ fontSize: '22px', marginRight: '16px', filter: task.done ? 'grayscale(100%) opacity(50%)' : 'none' }}>{task.emoji}</span>
              <span style={{ flex: 1, fontSize: '15px', fontWeight: '600', color: task.done ? 'var(--text-muted)' : 'var(--text-main)', textDecoration: task.done ? 'line-through' : 'none', transition: 'color 0.3s' }}>{task.title}</span>
              <div style={{ width: '24px', height: '24px', borderRadius: '50%', border: task.done ? 'none' : '2px solid rgba(255,255,255,0.15)', background: task.done ? '#4ade80' : 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center', transition: 'all 0.3s' }}>
                {task.done && <span style={{ color: '#064e3b', fontSize: '14px', fontWeight: 'bold' }}>✓</span>}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* 7. Water Intake */}
      <div className="glass-card gradient-border" style={{ padding: '24px 20px', marginBottom: '36px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
          <h3 style={{ margin: 0, fontSize: '13px', fontWeight: '800', letterSpacing: '1.5px', color: 'var(--text-muted)' }}>WATER INTAKE</h3>
          <span style={{ fontSize: '13px', fontWeight: '700', color: '#06b6d4' }}>{water}/10 Glasses</span>
        </div>
        <div style={{ height: '6px', borderRadius: '3px', background: 'rgba(255,255,255,0.05)', overflow: 'hidden', marginBottom: '24px' }}>
          <div style={{ width: `${(water / 10) * 100}%`, height: '100%', background: 'linear-gradient(90deg, #0891b2, #06b6d4, #67e8f9)', backgroundSize: '200% 100%', animation: 'shimmer 2s infinite linear', transition: 'width 0.4s cubic-bezier(0.4, 0, 0.2, 1)' }} />
        </div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '14px', justifyContent: 'center' }}>
          {Array.from({ length: 10 }).map((_, i) => (
            <div key={i} onClick={() => handleWaterClick(i)} style={{ width: '28px', height: '38px', borderRadius: '2px 2px 8px 8px', border: `2px solid ${i < water ? '#06b6d4' : 'rgba(255,255,255,0.1)'}`, position: 'relative', overflow: 'hidden', cursor: 'pointer', transition: 'border-color 0.3s' }}>
              {rippleId === i && <div className="ripple" />}
              {i < water && (
                <div style={{ position: 'absolute', bottom: 0, left: '-50%', width: '200%', height: '85%', background: 'rgba(6, 182, 212, 0.5)', animation: 'wave 2s infinite linear', borderTop: '2px solid rgba(255,255,255,0.3)' }} />
              )}
            </div>
          ))}
        </div>
      </div>

      {/* 8. Weekly Heatmap */}
      <div className="glass-card" style={{ padding: '24px 20px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
          <h3 style={{ margin: 0, fontSize: '13px', fontWeight: '800', letterSpacing: '1.5px', color: 'var(--text-muted)' }}>WEEKLY HEATMAP</h3>
          <div style={{ background: 'rgba(245, 158, 11, 0.15)', color: '#fbbf24', padding: '6px 10px', borderRadius: '6px', fontSize: '11px', fontWeight: '800', letterSpacing: '0.5px' }}>
            This Month: 85 Avg
          </div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: '8px' }}>
          {heatmap.map((day, i) => {
            const opacity = Math.max(0.08, day.score / 100);
            return (
              <div key={i} className="heatmap-cell" style={{ aspectRatio: '1', borderRadius: '6px', background: `rgba(74, 222, 128, ${opacity})`, cursor: 'help', border: '1px solid rgba(255,255,255,0.03)' }}>
                <span className="tooltip">Day {day.day}: Score {day.score}</span>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};

export default TodayScreen;
