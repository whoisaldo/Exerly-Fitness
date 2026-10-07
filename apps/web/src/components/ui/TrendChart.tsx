import { useMemo, useState } from 'react';
import type { TrendPoint } from '../../lib/api';
import { shortDate } from '../../lib/dates';
import { displayWeight, weightLabel, type UnitSystem } from '../../lib/units';

interface TrendChartProps {
  series: TrendPoint[];
  unitSystem: UnitSystem;
  height?: number;
  className?: string;
}

const PADDING = { top: 12, right: 12, bottom: 22, left: 40 };

/**
 * Scale readings as dots, smoothed trend as a line.
 *
 * Plotting both together is the point: the dots show the noise you should
 * ignore and the line shows what is actually happening.
 */
export function TrendChart({ series, unitSystem, height = 220, className = '' }: TrendChartProps) {
  const [hover, setHover] = useState<number | null>(null);
  const width = 640;

  const geometry = useMemo(() => {
    if (series.length < 2) return null;

    const values = series.flatMap((p) => [p.trend, p.weight].filter((v): v is number => v != null));
    const min = Math.min(...values);
    const max = Math.max(...values);
    // A flat month would otherwise divide by zero and draw a line at the top.
    const pad = Math.max((max - min) * 0.15, 0.4);
    const lo = min - pad;
    const hi = max + pad;

    const plotW = width - PADDING.left - PADDING.right;
    const plotH = height - PADDING.top - PADDING.bottom;

    const x = (i: number) => PADDING.left + (i / (series.length - 1)) * plotW;
    const y = (v: number) => PADDING.top + (1 - (v - lo) / (hi - lo)) * plotH;

    const trendPath = series.map((p, i) => `${i === 0 ? 'M' : 'L'}${x(i)},${y(p.trend)}`).join(' ');
    const areaPath = `${trendPath} L${x(series.length - 1)},${PADDING.top + plotH} L${x(0)},${PADDING.top + plotH} Z`;

    const ticks = [lo, (lo + hi) / 2, hi];

    return { x, y, trendPath, areaPath, ticks, plotW, plotH };
  }, [series, height]);

  if (!geometry) {
    return (
      <div
        className={`flex items-center justify-center text-sm text-slate-500 ${className}`}
        style={{ height }}
      >
        Log at least two weigh-ins to see a trend
      </div>
    );
  }

  const { x, y, trendPath, areaPath, ticks } = geometry;
  const active = hover != null ? series[hover] : null;

  return (
    <div className={`relative ${className}`}>
      <svg
        viewBox={`0 0 ${width} ${height}`}
        className="w-full"
        role="img"
        aria-label="Weight trend over time"
        onMouseLeave={() => setHover(null)}
      >
        <defs>
          <linearGradient id="trendFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#8b5cf6" stopOpacity="0.22" />
            <stop offset="100%" stopColor="#8b5cf6" stopOpacity="0" />
          </linearGradient>
        </defs>

        {ticks.map((t) => (
          <g key={t}>
            <line
              x1={PADDING.left}
              x2={width - PADDING.right}
              y1={y(t)}
              y2={y(t)}
              stroke="rgba(255,255,255,0.06)"
              strokeWidth="1"
            />
            <text x={4} y={y(t) + 4} fill="#626c80" fontSize="10" className="tabular-nums">
              {displayWeight(t, unitSystem, 1)}
            </text>
          </g>
        ))}

        <path d={areaPath} fill="url(#trendFill)" />
        <path
          d={trendPath}
          fill="none"
          stroke="#8b5cf6"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />

        {series.map((p, i) =>
          p.weight == null ? null : (
            <circle key={p.date} cx={x(i)} cy={y(p.weight)} r="2.5" fill="#9aa3b5" opacity="0.55" />
          )
        )}

        {active && (
          <line
            x1={x(hover as number)}
            x2={x(hover as number)}
            y1={PADDING.top}
            y2={height - PADDING.bottom}
            stroke="rgba(255,255,255,0.2)"
            strokeWidth="1"
          />
        )}

        {/* One invisible column per day so hovering anywhere in it registers. */}
        {series.map((p, i) => (
          <rect
            key={`hit-${p.date}`}
            x={x(i) - width / series.length / 2}
            y={0}
            width={width / series.length}
            height={height}
            fill="transparent"
            onMouseEnter={() => setHover(i)}
          />
        ))}

        <text x={PADDING.left} y={height - 6} fill="#626c80" fontSize="10">
          {shortDate(series[0].date)}
        </text>
        <text
          x={width - PADDING.right}
          y={height - 6}
          fill="#626c80"
          fontSize="10"
          textAnchor="end"
        >
          {shortDate(series[series.length - 1].date)}
        </text>
      </svg>

      {active && (
        <div className="pointer-events-none absolute left-1/2 top-2 -translate-x-1/2 rounded-lg border border-white/[0.12] bg-surface-3 px-3 py-1.5 text-xs shadow-glow">
          <span className="text-slate-400">{shortDate(active.date)}</span>
          <span className="ml-2 tabular-nums text-slate-100">
            trend {displayWeight(active.trend, unitSystem, 2)} {weightLabel(unitSystem)}
          </span>
          {active.weight != null && (
            <span className="ml-2 tabular-nums text-slate-400">
              scale {displayWeight(active.weight, unitSystem, 1)}
            </span>
          )}
        </div>
      )}
    </div>
  );
}
