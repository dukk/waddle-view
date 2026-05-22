import { useCallback, useRef, useState } from 'react';
import type { ReactNode } from 'react';
import { ConfirmDialog, type ConfirmDialogSeverity } from '@/components/ConfirmDialog';

export type ConfirmDialogOptions = {
  title: string;
  message: ReactNode;
  confirmLabel?: string;
  cancelLabel?: string;
  severity?: ConfirmDialogSeverity;
  busyLabel?: string;
};

type PendingConfirm = ConfirmDialogOptions;

export function useConfirmDialog() {
  const [pending, setPending] = useState<PendingConfirm | null>(null);
  const [busy, setBusy] = useState(false);
  const resolveRef = useRef<((confirmed: boolean) => void) | null>(null);

  const close = useCallback((confirmed: boolean) => {
    resolveRef.current?.(confirmed);
    resolveRef.current = null;
    setPending(null);
    setBusy(false);
  }, []);

  const confirm = useCallback((options: ConfirmDialogOptions): Promise<boolean> => {
    return new Promise((resolve) => {
      resolveRef.current = resolve;
      setBusy(false);
      setPending(options);
    });
  }, []);

  const setConfirmBusy = useCallback((value: boolean) => {
    setBusy(value);
  }, []);

  function ConfirmDialogHost() {
    if (!pending) return null;
    const { title, message, confirmLabel, cancelLabel, severity, busyLabel } = pending;

    return (
      <ConfirmDialog
        open
        title={title}
        message={message}
        confirmLabel={confirmLabel}
        cancelLabel={cancelLabel}
        severity={severity}
        busy={busy}
        busyLabel={busyLabel}
        onConfirm={() => close(true)}
        onCancel={() => close(false)}
        onClose={() => !busy && close(false)}
      />
    );
  }

  return { confirm, ConfirmDialogHost, setConfirmBusy };
}
