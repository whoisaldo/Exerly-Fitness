import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { useSearchParams } from 'react-router-dom';
import { isCalendarDay, normalizeTimeZone, todayString } from '../lib/dates';

const CalendarContext = createContext<{ timeZone: string; today: string } | null>(null);

export function AccountCalendarProvider({
  timeZone,
  children,
}: {
  timeZone: string;
  children: ReactNode;
}) {
  const [, refreshClock] = useState(0);
  useEffect(() => {
    const update = () => refreshClock((value) => value + 1);
    const timer = window.setInterval(update, 30_000);
    window.addEventListener('focus', update);
    document.addEventListener('visibilitychange', update);
    return () => {
      window.clearInterval(timer);
      window.removeEventListener('focus', update);
      document.removeEventListener('visibilitychange', update);
    };
  }, []);
  const zone = normalizeTimeZone(timeZone);
  const today = todayString(zone);
  const value = useMemo(() => ({ timeZone: zone, today }), [zone, today]);
  return <CalendarContext.Provider value={value}>{children}</CalendarContext.Provider>;
}

export function useAccountCalendar() {
  const calendar = useContext(CalendarContext);
  if (!calendar) throw new Error('Account calendar requires a loaded account.');
  return calendar;
}

export function useSelectedDay() {
  const { today } = useAccountCalendar();
  const [search, setSearch] = useSearchParams();
  const supplied = search.get('date');
  const date = isCalendarDay(supplied) ? supplied : today;
  useEffect(() => {
    if (isCalendarDay(supplied)) return;
    // Once opened, a logging page keeps that day across reload, midnight and
    // preference changes. Opening the navigation link without a date chooses
    // the account's current day again.
    setSearch(
      (current) => {
        if (isCalendarDay(current.get('date'))) return current;
        const next = new URLSearchParams(current);
        next.set('date', date);
        return next;
      },
      { replace: true }
    );
  }, [date, supplied, setSearch]);
  const setDate = useCallback(
    (value: string) => {
      if (!isCalendarDay(value)) return;
      setSearch((current) => {
        const next = new URLSearchParams(current);
        next.set('date', value);
        return next;
      });
    },
    [setSearch]
  );
  return { date, setDate };
}
