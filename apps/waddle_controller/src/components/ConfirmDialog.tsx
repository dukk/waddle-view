import type { ReactNode } from 'react';
import {
  Alert,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Typography,
} from '@mui/material';

export type ConfirmDialogSeverity = 'warning' | 'error';

export type ConfirmDialogProps = {
  open: boolean;
  title: string;
  message: ReactNode;
  confirmLabel?: string;
  cancelLabel?: string;
  severity?: ConfirmDialogSeverity;
  busy?: boolean;
  busyLabel?: string;
  onConfirm: () => void;
  onCancel: () => void;
  onClose: () => void;
};

export function ConfirmDialog({
  open,
  title,
  message,
  confirmLabel = 'Confirm',
  cancelLabel = 'Cancel',
  severity = 'warning',
  busy = false,
  busyLabel,
  onConfirm,
  onCancel,
  onClose,
}: ConfirmDialogProps) {
  const confirmColor = severity === 'error' ? 'error' : 'warning';
  const primaryLabel = busy && busyLabel ? busyLabel : confirmLabel;

  return (
    <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle>{title}</DialogTitle>
      <DialogContent>
        {typeof message === 'string' ? (
          <Alert severity={severity}>{message}</Alert>
        ) : (
          <Typography component="div" variant="body2">
            {message}
          </Typography>
        )}
      </DialogContent>
      <DialogActions>
        <Button onClick={onCancel} disabled={busy}>
          {cancelLabel}
        </Button>
        <Button
          variant="contained"
          color={confirmColor}
          disabled={busy}
          onClick={onConfirm}
        >
          {primaryLabel}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
