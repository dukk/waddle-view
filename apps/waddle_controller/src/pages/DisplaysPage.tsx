import { useState } from 'react';
import {
  Alert,
  Box,
  Button,
  List,
  ListItem,
  ListItemText,
  Stack,
  Typography,
} from '@mui/material';
import { Link as RouterLink } from 'react-router-dom';
import { AdoptDisplayDialog } from '@/components/AdoptDisplayDialog';
import { AdoptDisplayForm } from '@/components/AdoptDisplayForm';
import { useDisplay } from '@/context/DisplayContext';
import { hasAnyAdoptedDisplay } from '@/util/adoptedDisplays';

export function DisplaysPage() {
  const { displays, active, refresh, removeDisplay } = useDisplay();
  const [success, setSuccess] = useState<string | null>(null);
  const adopted = hasAnyAdoptedDisplay(displays);

  if (!adopted) {
    return (
      <Stack spacing={2} sx={{ maxWidth: 720 }}>
        <Typography variant="h5" fontWeight={600}>
          Displays
        </Typography>
        <AdoptDisplayDialog open onAdopted={() => refresh()} />
      </Stack>
    );
  }

  return (
    <Stack spacing={3} sx={{ maxWidth: 720 }}>
      <Typography variant="h5" fontWeight={600}>
        Displays
      </Typography>
      <Typography variant="body2" color="text.secondary">
        Manage saved kiosks and adopt additional displays. API keys stay in this browser only.
      </Typography>

      {success && (
        <Alert severity="success" onClose={() => setSuccess(null)}>
          {success}
        </Alert>
      )}

      <Box>
        <Typography variant="subtitle1" gutterBottom>
          Saved displays ({displays.length})
        </Typography>
        <List dense>
          {displays.map((d) => (
            <ListItem
              key={d.id}
              secondaryAction={
                <Button size="small" color="error" onClick={() => removeDisplay(d.id)}>
                  Remove
                </Button>
              }
            >
              <ListItemText
                primary={`${d.label}${active?.id === d.id ? ' (active)' : ''}`}
                secondary={d.baseUrl}
              />
            </ListItem>
          ))}
        </List>
      </Box>

      <Box>
        <Typography variant="subtitle1" gutterBottom>
          Add display
        </Typography>
        <AdoptDisplayForm
          onAdopted={() => {
            refresh();
            setSuccess('Display adopted and saved.');
          }}
        />
      </Box>

      <Typography variant="body2" color="text.secondary">
        Export or import the display list from{' '}
        <RouterLink to="/settings">Settings</RouterLink> (API keys are not included).
      </Typography>
    </Stack>
  );
}
