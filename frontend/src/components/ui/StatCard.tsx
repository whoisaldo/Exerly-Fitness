import type { ReactNode } from 'react';

interface StatCardProps {
  icon: ReactNode;
  label: string;
  value: string | number;
  trend?: number;
  sparkline?: number[];
  className?: string;
}

function Sparkline({ data }: { data: number[] }) {
  const h = 24;
  const w = 64;
  const max = Math.max(...data);
  const min = Math.min(...data);
  const range = max - min || 1;
  const points = data
    .map((v, i) => {
      const x = (i / (data.length - 1)) * w;
      const y = h - ((v - min) / range) * h;
      return `${x},${y}`;
    })
    .join(' ');

  return (
    <svg width={w} height={h} className="ml-auto shrink-0" viewBox={`0 0 ${w} ${h}`}>
      <polyline
        points={points}
        fill="none"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="text-primary"
      />
    </svg>
  );
}

export function StatCard({ icon, label, value, trend, sparkline, className = '' }: StatCardProps) {
  const trendColor = trend && trend >= 0 ? 'text-success' : 'text-error';
  const trendArrow = trend && trend >= 0 ? '\u2191' : '\u2193';

  return (
    <div
      className={`glass p-5 transition-all duration-300 hover:border-violet-500/40 hover:shadow-glow-primary ${className}`}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
          {icon}
        </div>
        {sparkline && sparkline.length > 1 && <Sparkline data={sparkline} />}
      </div>
      <p className="label mt-4">{label}</p>
      <div className="mt-1 flex items-baseline gap-2">
        <span className="stat-value">{value}</span>
        {trend !== undefined && (
          <span className={`text-sm font-medium ${trendColor}`}>
            {trendArrow} {Math.abs(trend)}%
          </span>
        )}
      </div>
    </div>
  );
}
