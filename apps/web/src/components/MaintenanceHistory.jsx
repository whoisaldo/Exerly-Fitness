import { Link } from 'react-router-dom';
import { PageTransition, PageHeader, GlassCard, Badge } from './ui';

const MAINTENANCE_HISTORY = [
  {
    id: 1,
    date: 'October 18, 2024',
    duration: 'Ongoing',
    reason: 'Frontend Updates',
    description:
      'Website may not be at full functionality right now due to ongoing frontend improvements and optimizations.',
    status: 'in-progress',
  },
  {
    id: 2,
    date: 'October 10, 2025',
    duration: '2 hours',
    reason: 'Database Migration',
    description:
      'Migrated from PostgreSQL/SQLite to MongoDB Atlas for improved performance and scalability.',
    status: 'completed',
  },
  {
    id: 3,
    date: 'October 10, 2025',
    duration: '30 minutes',
    reason: 'System Maintenance',
    description:
      'Routed database to different cloud service for improved performance and reliability.',
    status: 'completed',
  },
];

const STATUS_BADGE = {
  completed: 'status',
  'in-progress': 'meal',
  scheduled: 'intensity',
};

const STATUS_DOT = {
  completed: 'bg-success',
  'in-progress': 'bg-warning animate-pulse',
  scheduled: 'bg-primary',
};

export default function MaintenanceHistory() {
  return (
    <PageTransition className="min-h-screen bg-deep px-4 pb-24 pt-10 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-2xl">
        <PageHeader
          title="Maintenance history"
          subtitle="Scheduled and completed maintenance on Exerly systems."
          action={
            <Link
              to="/status-check"
              className="text-sm font-medium text-primary-bright transition-colors hover:text-primary"
            >
              System status →
            </Link>
          }
        />

        <div className="mt-8">
          {MAINTENANCE_HISTORY.map((entry, index) => (
            <div key={entry.id} className="grid grid-cols-[auto_1fr] gap-4">
              <div className="flex flex-col items-center">
                <span className="flex h-8 w-8 items-center justify-center rounded-full border border-white/[0.08] bg-surface-2">
                  <span
                    className={`h-2 w-2 rounded-full ${STATUS_DOT[entry.status] ?? 'bg-slate-500'}`}
                  />
                </span>
                {index < MAINTENANCE_HISTORY.length - 1 && (
                  <span className="w-px flex-1 bg-white/[0.08]" />
                )}
              </div>

              <GlassCard className="mb-4" hover={false}>
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <h2 className="text-base font-semibold text-slate-50">{entry.reason}</h2>
                  <Badge variant={STATUS_BADGE[entry.status] ?? 'intensity'}>
                    {entry.status.replace('-', ' ')}
                  </Badge>
                </div>
                <p className="mt-1 text-xs text-slate-500">
                  {entry.date} · {entry.duration}
                </p>
                <p className="mt-3 text-sm leading-relaxed text-slate-400">{entry.description}</p>
              </GlassCard>
            </div>
          ))}
        </div>

        <div className="glass mt-2 flex flex-wrap items-center justify-between gap-2 p-4">
          <span className="inline-flex items-center gap-2 text-sm text-slate-200">
            <span className="h-2 w-2 rounded-full bg-success" />
            All systems operational
          </span>
          <span className="text-xs text-slate-500">
            Last updated:{' '}
            {new Date().toLocaleDateString('en-US', {
              year: 'numeric',
              month: 'long',
              day: 'numeric',
              hour: '2-digit',
              minute: '2-digit',
            })}
          </span>
        </div>
      </div>
    </PageTransition>
  );
}
