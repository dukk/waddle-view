import {
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Typography,
} from '@mui/material';
import { AdoptDisplayForm } from '@/components/AdoptDisplayForm';

type Props = {
  open: boolean;
  /** When false, escape and backdrop dismiss are disabled (first-time pairing). */
  dismissible?: boolean;
  onClose?: () => void;
  onAdopted?: () => void;
};

export function AdoptDisplayDialog({
  open,
  dismissible = true,
  onClose,
  onAdopted,
}: Props) {
  const handleClose = dismissible ? onClose : undefined;

  return (
    <Dialog
      open={open}
      fullWidth
      maxWidth="sm"
      onClose={handleClose}
      disableEscapeKeyDown={!dismissible}
    >
      <DialogTitle>Adopt display</DialogTitle>
      <DialogContent>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          Pair this browser with a display by requesting adoption on the display, then confirming
          the challenge code from the display alert.
        </Typography>
        <AdoptDisplayForm requestLabel="Continue to adoption" onAdopted={onAdopted} />
      </DialogContent>
      {dismissible && onClose ? (
        <DialogActions>
          <Button onClick={onClose}>Cancel</Button>
        </DialogActions>
      ) : null}
    </Dialog>
  );
}
