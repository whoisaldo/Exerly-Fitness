import { type ReactNode, useState } from 'react';

interface Column<T> {
  key: keyof T & string;
  label: string;
  sortable?: boolean;
  render?: (value: T[keyof T], row: T) => ReactNode;
}

interface DataTableProps<T> {
  columns: Column<T>[];
  data: T[];
  emptyState?: ReactNode;
  onRowClick?: (row: T) => void;
}

function SortIcon({ dir }: { dir: 'asc' | 'desc' | null }) {
  return (
    <svg width="12" height="12" viewBox="0 0 12 12" className="ml-1 inline-block">
      <path
        d="M6 2L9 5H3L6 2Z"
        fill="currentColor"
        className={dir === 'asc' ? 'opacity-100' : 'opacity-25'}
      />
      <path
        d="M6 10L3 7H9L6 10Z"
        fill="currentColor"
        className={dir === 'desc' ? 'opacity-100' : 'opacity-25'}
      />
    </svg>
  );
}

export function DataTable<T extends Record<string, unknown>>({
  columns,
  data,
  emptyState,
  onRowClick,
}: DataTableProps<T>) {
  const [sortKey, setSortKey] = useState<string | null>(null);
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('asc');

  function handleSort(key: string) {
    if (sortKey === key) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'));
    } else {
      setSortKey(key);
      setSortDir('asc');
    }
  }

  const sorted = sortKey
    ? [...data].sort((a, b) => {
        const av = a[sortKey] as string | number;
        const bv = b[sortKey] as string | number;
        const cmp = av < bv ? -1 : av > bv ? 1 : 0;
        return sortDir === 'asc' ? cmp : -cmp;
      })
    : data;

  if (data.length === 0 && emptyState) {
    return <>{emptyState}</>;
  }

  return (
    <div className="overflow-x-auto rounded-2xl border border-border-subtle">
      <table className="w-full text-left text-sm">
        <thead>
          <tr className="border-b border-border-subtle bg-surface-1/50">
            {columns.map((col) => (
              <th
                key={col.key}
                className={`px-4 py-3 text-label font-medium uppercase tracking-widest text-slate-400 ${
                  col.sortable ? 'cursor-pointer select-none hover:text-slate-200' : ''
                }`}
                onClick={col.sortable ? () => handleSort(col.key) : undefined}
              >
                {col.label}
                {col.sortable && (
                  <SortIcon dir={sortKey === col.key ? sortDir : null} />
                )}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {sorted.map((row, i) => (
            <tr
              key={i}
              className={`border-b border-border-subtle transition-colors last:border-0 ${
                onRowClick
                  ? 'cursor-pointer hover:bg-surface-2/60'
                  : 'hover:bg-surface-2/30'
              }`}
              onClick={onRowClick ? () => onRowClick(row) : undefined}
            >
              {columns.map((col) => (
                <td key={col.key} className="px-4 py-3 text-slate-200">
                  {col.render
                    ? col.render(row[col.key], row)
                    : String(row[col.key] ?? '')}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
