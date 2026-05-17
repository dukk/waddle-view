import { useRef, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Paper,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { useControllerAuth } from '@/context/ControllerAuthContext';
import {
  exportDisplaysJson,
  importDisplaysJson,
  importDisplaysJsonLegacy,
  shouldOfferLocalDisplaysMigration,
} from '@/storage/displays';
import { migrateLocalDisplaysToServer } from '@/storage/userDisplaysSync';

type DisplaysBackupSectionProps = {
  onChanged: () => void;
};

export function DisplaysBackupSection({ onChanged }: DisplaysBackupSectionProps) {
  const { status } = useControllerAuth();
  const userModeEnabled = Boolean(status?.authEnabled);
  const [importText, setImportText] = useState('');
  const [msg, setMsg] = useState<{ level: 'success' | 'error'; text: string } | null>(null);
  const [migrating, setMigrating] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  const showMigration =
    userModeEnabled && shouldOfferLocalDisplaysMigration();
  const showBackup = !userModeEnabled;

  if (!showBackup && !showMigration) {
    return null;
  }

  const exportBlob = () => {
    const blob = new Blob([exportDisplaysJson()], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'waddle_controller_displays.json';
    a.click();
    URL.revokeObjectURL(url);
  };

  const doImport = () => {
    setMsg(null);
    try {
      try {
        importDisplaysJson(importText);
      } catch {
        importDisplaysJsonLegacy(importText);
      }
      setImportText('');
      onChanged();
      setMsg({ level: 'success', text: 'Imported display list.' });
    } catch (e) {
      setMsg({ level: 'error', text: String(e) });
    }
  };

  const doMigrate = async () => {
    setMsg(null);
    setMigrating(true);
    try {
      await migrateLocalDisplaysToServer();
      onChanged();
      setMsg({ level: 'success', text: 'Display settings migrated to the server.' });
    } catch (e) {
      setMsg({ level: 'error', text: String(e) });
    } finally {
      setMigrating(false);
    }
  };

  return (
    <Paper variant="outlined" sx={{ p: 2 }}>
      <Typography variant="subtitle1" fontWeight={600} gutterBottom>
        Display list backup
      </Typography>

      {msg && (
        <Alert severity={msg.level} onClose={() => setMsg(null)} sx={{ mb: 2 }}>
          {msg.text}
        </Alert>
      )}

      {showMigration && (
        <Box>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            This browser still has display settings saved locally. Move them to your controller
            account on the server (API keys are included for adopted displays).
          </Typography>
          <Button variant="contained" disabled={migrating} onClick={() => void doMigrate()}>
            {migrating ? 'Migrating…' : 'Migrate display settings to the server'}
          </Button>
        </Box>
      )}

      {showBackup && (
        <Box>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Export or import the saved display list stored in this browser (labels, base URLs, and
            adopted API keys and roles when present).
          </Typography>
          <Stack direction="row" spacing={1} sx={{ mb: 2 }} flexWrap="wrap" useFlexGap>
            <Button variant="outlined" onClick={exportBlob}>
              Export JSON
            </Button>
            <Button variant="outlined" onClick={() => fileRef.current?.click()}>
              Import from file
            </Button>
            <input
              ref={fileRef}
              type="file"
              accept="application/json,.json"
              hidden
              onChange={async (ev) => {
                const f = ev.target.files?.[0];
                ev.target.value = '';
                if (!f) return;
                setImportText(await f.text());
              }}
            />
          </Stack>
          <TextField
            label="Paste JSON to import"
            value={importText}
            onChange={(e) => setImportText(e.target.value)}
            fullWidth
            multiline
            minRows={4}
          />
          <Button
            sx={{ mt: 1 }}
            variant="contained"
            onClick={doImport}
            disabled={!importText.trim()}
          >
            Apply import
          </Button>
        </Box>
      )}
    </Paper>
  );
}
