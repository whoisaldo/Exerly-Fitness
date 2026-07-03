const MINI_STATS = [
  { value: '1,847', label: 'kcal' },
  { value: '2', label: 'workouts' },
  { value: '7.5h', label: 'sleep' },
];

/** Static, decorative recreation of the Exerly iOS home screen. */
export function IPhoneFrame({ className = '' }: { className?: string }) {
  // 76% of the daily calorie ring, drawn as a static arc
  const r = 34;
  const c = 2 * Math.PI * r;

  return (
    <div
      aria-hidden="true"
      className={`w-[250px] rounded-[3rem] border border-white/[0.14] bg-surface-1 p-2 shadow-glow-lg ${className}`}
    >
      <div className="relative overflow-hidden rounded-[2.55rem] bg-deep px-4 pb-4 pt-3">
        {/* Dynamic Island */}
        <div className="mx-auto mb-3 h-6 w-24 rounded-full bg-black" />

        {/* Greeting */}
        <div className="mb-4 flex items-center justify-between px-1">
          <div>
            <div className="text-[10px] uppercase tracking-widest text-slate-500">Good morning</div>
            <div className="text-base font-bold text-slate-50">John Doe</div>
          </div>
          <span className="flex h-8 w-8 items-center justify-center rounded-xl border border-white/[0.08] bg-surface-2">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" className="text-slate-400">
              <path
                d="M18 8A6 6 0 1 0 6 8c0 7-3 9-3 9h18s-3-2-3-9M13.7 21a2 2 0 0 1-3.4 0"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </span>
        </div>

        {/* Calorie ring card */}
        <div className="mb-3 rounded-2xl border border-white/[0.08] bg-surface-2 p-4">
          <div className="flex items-center justify-center">
            <div className="relative flex items-center justify-center">
              <svg width="96" height="96" className="-rotate-90">
                <circle
                  cx="48"
                  cy="48"
                  r={r}
                  fill="none"
                  stroke="rgba(255,255,255,0.08)"
                  strokeWidth="7"
                />
                <circle
                  cx="48"
                  cy="48"
                  r={r}
                  fill="none"
                  stroke="#8b5cf6"
                  strokeWidth="7"
                  strokeLinecap="round"
                  strokeDasharray={c}
                  strokeDashoffset={c * 0.24}
                />
              </svg>
              <div className="absolute text-center">
                <div className="text-lg font-bold tabular-nums text-slate-50">1,847</div>
                <div className="text-[9px] uppercase tracking-widest text-slate-500">kcal</div>
              </div>
            </div>
          </div>
          <div className="mt-2 text-center text-[10px] uppercase tracking-widest text-slate-500">
            Today&apos;s calories
          </div>
        </div>

        {/* Mini stat cards */}
        <div className="mb-3 grid grid-cols-3 gap-2">
          {MINI_STATS.map((s) => (
            <div
              key={s.label}
              className="rounded-xl border border-white/[0.08] bg-surface-2 px-1 py-2.5 text-center"
            >
              <div className="text-xs font-bold tabular-nums text-slate-50">{s.value}</div>
              <div className="mt-0.5 text-[8px] uppercase tracking-wider text-slate-500">
                {s.label}
              </div>
            </div>
          ))}
        </div>

        {/* Streak card */}
        <div className="mb-4 flex items-center gap-2.5 rounded-2xl border border-white/[0.08] bg-surface-2 p-3">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" className="text-warning">
            <path
              d="M12 2c1 4-4 6-4 10a4 4 0 0 0 8 .5C16 9 13 7 12 2ZM10 16.5a2 2 0 1 0 4 0"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
          <div>
            <div className="text-[9px] uppercase tracking-widest text-slate-500">
              Current streak
            </div>
            <div className="text-xs font-semibold text-slate-100">12 days — keep going</div>
          </div>
        </div>

        {/* Tab bar */}
        <div className="flex items-center justify-between rounded-2xl border border-white/[0.08] bg-surface-2 px-5 py-2.5">
          <span className="h-1.5 w-5 rounded-full bg-primary" />
          <span className="h-1.5 w-5 rounded-full bg-white/[0.12]" />
          <span className="flex h-9 w-9 items-center justify-center rounded-full bg-primary text-lg font-semibold leading-none text-white shadow-glow-primary">
            +
          </span>
          <span className="h-1.5 w-5 rounded-full bg-white/[0.12]" />
          <span className="h-1.5 w-5 rounded-full bg-white/[0.12]" />
        </div>
      </div>
    </div>
  );
}
