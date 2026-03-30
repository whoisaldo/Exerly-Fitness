type SkeletonVariant = 'card' | 'stat' | 'table-row' | 'text' | 'circle';

interface LoadingSkeletonProps {
  variant?: SkeletonVariant;
  count?: number;
  className?: string;
}

const base = 'animate-pulse rounded-xl bg-white/5';

const variants: Record<SkeletonVariant, string> = {
  card: `${base} h-40 w-full rounded-2xl`,
  stat: `${base} h-28 w-full rounded-2xl`,
  'table-row': `${base} h-12 w-full rounded-lg`,
  text: `${base} h-4 w-3/4 rounded-md`,
  circle: `${base} h-12 w-12 rounded-full`,
};

export function LoadingSkeleton({
  variant = 'card',
  count = 1,
  className = '',
}: LoadingSkeletonProps) {
  return (
    <>
      {Array.from({ length: count }, (_, i) => (
        <div key={i} className={`${variants[variant]} ${className}`} />
      ))}
    </>
  );
}
