import { addDays, friendlyDate, isCalendarDay, isFuture, isToday } from '../../lib/dates';
import { useAccountCalendar } from '../../hooks/useAccountCalendar';

interface DateNavProps {
  date: string;
  onChange: (date: string) => void;
  className?: string;
}

function Chevron({ direction }: { direction: 'left' | 'right' }) {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d={direction === 'left' ? 'M15 18l-6-6 6-6' : 'M9 18l6-6-6-6'}
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

/**
 * Day stepper with a native date picker behind the label.
 *
 * Forward navigation stops at today. Logging into the future is rejected by the
 * API anyway, and an arrow that does nothing is worse than one that is disabled.
 */
export function DateNav({ date, onChange, className = '' }: DateNavProps) {
  const { today, timeZone } = useAccountCalendar();
  const earliest = addDays(today, -3650);
  const canGoBack = date > earliest;
  const previousDay = canGoBack ? addDays(date, -1) : date;
  const canGoForward = date < today;
  const nextDay = canGoForward ? addDays(date, 1) : date;

  return (
    <div className={`flex flex-wrap items-center gap-1 ${className}`}>
      <button
        type="button"
        onClick={() => onChange(previousDay)}
        disabled={!canGoBack}
        aria-label="Previous day"
        className="min-h-11 min-w-11 rounded-lg p-2 text-slate-400 hover:bg-white/[0.06] hover:text-slate-100"
      >
        <Chevron direction="left" />
      </button>

      <div className="relative flex min-h-11 min-w-[9rem] items-center justify-center rounded-lg text-center focus-within:outline focus-within:outline-2 focus-within:outline-primary">
        <span className="pointer-events-none block text-sm font-semibold text-slate-100">
          {friendlyDate(date, today)}
        </span>
        <input
          type="date"
          value={date}
          min={earliest}
          max={today}
          onChange={(e) =>
            isCalendarDay(e.target.value) &&
            e.target.value >= earliest &&
            e.target.value <= today &&
            onChange(e.target.value)
          }
          aria-label="Pick a date"
          // The native picker sits invisibly over the label so the whole thing
          // is one tap target without rebuilding a calendar.
          className="absolute inset-0 h-full w-full cursor-pointer opacity-0"
        />
      </div>

      <button
        type="button"
        onClick={() => canGoForward && onChange(nextDay)}
        disabled={!canGoForward}
        aria-label="Next day"
        className="min-h-11 min-w-11 rounded-lg p-2 text-slate-400 hover:bg-white/[0.06] hover:text-slate-100 disabled:pointer-events-none disabled:opacity-30"
      >
        <Chevron direction="right" />
      </button>

      {!isToday(date, today) && (
        <button
          type="button"
          onClick={() => onChange(today)}
          className="ml-1 min-h-11 rounded-lg px-2.5 py-1.5 text-xs font-semibold text-primary hover:bg-primary/10"
        >
          Today
        </button>
      )}
      {isFuture(date, today) && (
        <p role="status" className="basis-full text-pretty text-sm text-slate-300">
          This date is ahead of today in {timeZone}. Saved changes keep their original date. Retry
          them when this date arrives, or review your time zone in Profile.
        </p>
      )}
    </div>
  );
}
