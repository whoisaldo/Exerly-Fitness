import * as AlertDialog from '@radix-ui/react-alert-dialog';
import type { ReactElement } from 'react';

export function ConfirmAction({
  trigger,
  title,
  description,
  action,
  onConfirm,
}: {
  trigger: ReactElement;
  title: string;
  description: string;
  action: string;
  onConfirm: () => void;
}) {
  return (
    <AlertDialog.Root>
      <AlertDialog.Trigger asChild>{trigger}</AlertDialog.Trigger>
      <AlertDialog.Portal>
        <AlertDialog.Overlay className="fixed inset-0 z-50 bg-black/70" />
        <AlertDialog.Content className="fixed left-1/2 top-1/2 z-50 w-11/12 max-w-md -translate-x-1/2 -translate-y-1/2 rounded-2xl border border-white/15 bg-surface-2 p-6 text-slate-100 shadow-xl">
          <AlertDialog.Title className="text-balance text-lg font-semibold">
            {title}
          </AlertDialog.Title>
          <AlertDialog.Description className="mt-3 text-pretty text-sm text-slate-300">
            {description}
          </AlertDialog.Description>
          <div className="mt-6 flex flex-wrap justify-end gap-3">
            <AlertDialog.Cancel className="min-h-11 rounded-xl border border-white/20 px-4 text-sm">
              Cancel
            </AlertDialog.Cancel>
            <AlertDialog.Action
              onClick={onConfirm}
              className="min-h-11 rounded-xl bg-violet-600 px-4 text-sm font-semibold text-white"
            >
              {action}
            </AlertDialog.Action>
          </div>
        </AlertDialog.Content>
      </AlertDialog.Portal>
    </AlertDialog.Root>
  );
}
