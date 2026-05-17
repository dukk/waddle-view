import {
  Dialog,
  DialogContent,
  DialogTitle,
  Typography,
} from '@mui/material';
import { AdoptDisplayForm } from '@/components/AdoptDisplayForm';

type Props = {
  open: boolean;
  onAdopted?: () => void;
};

export function AdoptDisplayDialog({ open, onAdopted }: Props) {
  return (
    <Dialog open={open} fullWidth maxWidth="sm" disableEscapeKeyDown>
      <DialogTitle>Add a display</DialogTitle>
      <DialogContent>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          Pair this browser with a kiosk by requesting adoption on the display, then confirming
          the challenge code from the kiosk alert.
        </Typography>
        <AdoptDisplayForm requestLabel="Continue to adoption" onAdopted={onAdopted} />
      </DialogContent>
    </Dialog>
  );
}
