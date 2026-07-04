export default function MaintenanceNotice() {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-deep px-4">
      <div className="glass-elevated w-full max-w-md p-8 text-center">
        <div className="mx-auto mb-5 flex h-14 w-14 items-center justify-center rounded-2xl bg-primary/10 text-primary">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path
              d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76Z"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </div>
        <h1 className="text-2xl font-bold text-slate-50">Scheduled Maintenance</h1>
        <p className="mt-3 text-sm leading-relaxed text-slate-400">
          We&apos;re currently routing our database to a different cloud service for improved
          performance and reliability.
        </p>
        <p className="mt-2 text-sm leading-relaxed text-slate-400">
          Expected to be back online by{' '}
          <strong className="font-semibold text-slate-200">October 11th, 2025</strong>. Thank you
          for your patience!
        </p>
        <div className="mt-5 inline-flex items-center gap-2 rounded-full border border-warning/20 bg-warning/10 px-3 py-1.5 text-xs font-medium text-warning">
          <span className="h-2 w-2 animate-pulse rounded-full bg-warning" />
          Working on it...
        </div>
        <p className="mt-6 text-xs text-slate-500">
          Questions? Contact us at{' '}
          <a
            href="mailto:aliyounes@eternalreverse.com"
            className="text-primary-bright transition-colors hover:text-primary"
          >
            aliyounes@eternalreverse.com
          </a>
        </p>
      </div>
    </div>
  );
}
