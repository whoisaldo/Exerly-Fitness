interface ExerlyMarkProps {
  className?: string;
  size?: number;
  withWordmark?: boolean;
}

/**
 * Inline SVG brand mark — a violet tile with the EKG pulse from the logo.
 * Replaces the bitmap logo in nav/footer chrome; the wordmark inherits
 * the surrounding text color.
 */
export function ExerlyMark({ className = '', size = 28, withWordmark = true }: ExerlyMarkProps) {
  return (
    <span className={`inline-flex items-center gap-2.5 ${className}`}>
      <svg
        width={size}
        height={size}
        viewBox="0 0 32 32"
        fill="none"
        aria-hidden="true"
        className="shrink-0"
      >
        <rect x="2" y="2" width="28" height="28" rx="8" fill="#8b5cf6" />
        <path
          d="M7 16H11L13.5 10L17 22L19.5 12L21.5 16H25"
          stroke="#ffffff"
          strokeWidth="2.2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
      {withWordmark && (
        <span className="text-lg font-bold tracking-tight text-slate-50">Exerly</span>
      )}
    </span>
  );
}
