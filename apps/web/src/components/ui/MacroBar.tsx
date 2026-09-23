interface MacroBarProps {
  label: string;
  value: number;
  target: number | null;
  unit?: string;
  color: string;
  className?: string;
  incomplete?: boolean;
  known?: boolean;
}

/**
 * One macro's progress toward its target.
 *
 * Over target is shown by colouring the bar rather than letting it overflow,
 * because "how far past" matters less than "past".
 */
export function MacroBar({
  label,
  value,
  target,
  unit = 'g',
  color,
  className = '',
  incomplete = false,
  known = true,
}: MacroBarProps) {
  const hasTarget = target != null && target > 0;
  const pct = hasTarget ? Math.min(100, (value / target) * 100) : 0;
  const over = hasTarget && value > target;
  const remaining = hasTarget ? target - value : null;

  return (
    <div className={className}>
      <div className="flex items-baseline justify-between gap-2">
        <span className="label">{label}</span>
        <span className="text-sm tabular-nums text-slate-300">
          {known ? `${Math.round(value)}${incomplete ? '+' : ''}` : '—'}
          {hasTarget && <span className="text-slate-500"> / {Math.round(target)}</span>}
          <span className="text-slate-500">{unit}</span>
        </span>
      </div>

      <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-white/[0.08]">
        <div
          className="h-full rounded-full transition-[width] duration-500 ease-out"
          style={{ width: `${pct}%`, background: over ? '#f59e0b' : color }}
        />
      </div>

      {hasTarget && (
        <p className="mt-1 text-xs tabular-nums text-slate-500">
          {incomplete
            ? 'Some values unknown'
            : over
              ? `${Math.round(Math.abs(remaining as number))}${unit} over`
              : `${Math.round(remaining as number)}${unit} left`}
        </p>
      )}
    </div>
  );
}

export const MACRO_COLORS = {
  protein: '#8b5cf6',
  carbs: '#38bdf8',
  fat: '#f59e0b',
  fiber: '#10b981',
} as const;
