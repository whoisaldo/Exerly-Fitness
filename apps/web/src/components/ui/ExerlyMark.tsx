import exerlyLogo from '../Assets/ExerlyLogo.jpg';

interface ExerlyMarkProps {
  className?: string;
  size?: number;
  withWordmark?: boolean;
}

/**
 * The original Exerly logo, with an optional text wordmark beside it.
 * Kept as the single brand component so nav/footer/credits stay in sync.
 */
export function ExerlyMark({ className = '', size = 32, withWordmark = true }: ExerlyMarkProps) {
  return (
    <span className={`inline-flex items-center gap-2.5 ${className}`}>
      <img
        src={exerlyLogo}
        alt={withWordmark ? '' : 'Exerly'}
        width={size}
        height={size}
        style={{ width: size, height: size }}
        className="shrink-0 rounded-[22%] object-cover"
      />
      {withWordmark && (
        <span className="text-lg font-bold tracking-tight text-slate-50">Exerly</span>
      )}
    </span>
  );
}
