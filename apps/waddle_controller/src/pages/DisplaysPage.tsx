import { useEffect, useState } from 'react';

import {

  Alert,

  Button,

  Chip,

  Paper,

  Stack,

  Table,

  TableBody,

  TableCell,

  TableContainer,

  TableHead,

  TableRow,

  Typography,

} from '@mui/material';

import { AdoptDisplayDialog } from '@/components/AdoptDisplayDialog';

import { EditDisplayDialog } from '@/components/EditDisplayDialog';

import { DisplaysBackupSection } from '@/components/DisplaysBackupSection';

import { useDisplay } from '@/context/DisplayContext';

import type { SavedDisplay } from '@/storage/displays';

import { loadSession } from '@/storage/sessions';

import { hasAnyAdoptedDisplay } from '@/util/adoptedDisplays';



type DisplaysPageProps = {

  /** When true, omit outer page chrome (used inside Controller Settings tabs). */

  embedded?: boolean;

};



export function DisplaysPage({ embedded = false }: DisplaysPageProps) {

  const { displays, active, refresh, removeDisplay, updateDisplay } = useDisplay();

  const [success, setSuccess] = useState<string | null>(null);

  const [labelError, setLabelError] = useState<string | null>(null);

  const [adoptOpen, setAdoptOpen] = useState(false);

  const [editDisplay, setEditDisplay] = useState<SavedDisplay | null>(null);

  const adopted = hasAnyAdoptedDisplay(displays);



  useEffect(() => {

    if (!adopted) {

      setAdoptOpen(true);

    }

  }, [adopted]);



  const handleAdopted = () => {

    refresh();

    setSuccess('Display adopted and saved.');

    setAdoptOpen(false);

  };



  return (

    <Stack spacing={2}>

      {!embedded && (

        <Stack direction="row" justifyContent="space-between" alignItems="flex-end" gap={2}>

          <Typography variant="body2" color="text.secondary">
            Pair kiosks with this browser, rename them, and switch which display the controller
            targets. Adopted API keys stay in local storage only—they are not included in backup
            export.
          </Typography>

          <Button variant="contained" onClick={() => setAdoptOpen(true)}>

            Adopt display

          </Button>

        </Stack>

      )}

      {embedded && (

        <Stack direction="row" justifyContent="flex-end">

          <Button variant="contained" onClick={() => setAdoptOpen(true)}>

            Adopt display

          </Button>

        </Stack>

      )}



      {success && (

        <Alert severity="success" onClose={() => setSuccess(null)}>

          {success}

        </Alert>

      )}

      {labelError && (

        <Alert severity="error" onClose={() => setLabelError(null)}>

          {labelError}

        </Alert>

      )}



      <TableContainer component={Paper} variant="outlined">

        <Table size="small">

          <TableHead>

            <TableRow>

              <TableCell>Display</TableCell>

              <TableCell>Base URL</TableCell>

              <TableCell>Adoption</TableCell>

              <TableCell align="right">Actions</TableCell>

            </TableRow>

          </TableHead>

          <TableBody>

            {displays.length === 0 ? (

              <TableRow>

                <TableCell colSpan={4} align="center" sx={{ py: 4 }}>

                  <Typography variant="body2" color="text.secondary">

                    No displays saved yet. Use <strong>Adopt display</strong> to pair with a kiosk.

                  </Typography>

                </TableCell>

              </TableRow>

            ) : (

              displays.map((d) => {

                const session = loadSession(d.id);

                const isActive = active?.id === d.id;

                return (

                  <TableRow key={d.id} selected={isActive}>

                    <TableCell>

                      <Stack direction="row" alignItems="center" spacing={1} useFlexGap flexWrap="wrap">

                        <Typography variant="body2" fontWeight={isActive ? 600 : 400}>

                          {d.label}

                        </Typography>

                        {isActive && <Chip label="Active" size="small" color="primary" />}

                      </Stack>

                    </TableCell>

                    <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.85rem' }}>

                      {d.baseUrl}

                    </TableCell>

                    <TableCell>

                      {session ? (

                        <Typography variant="body2">

                          {session.identifier} ({session.role})

                        </Typography>

                      ) : (

                        <Typography variant="body2" color="text.secondary">

                          Not adopted

                        </Typography>

                      )}

                    </TableCell>

                    <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>

                      <Button size="small" onClick={() => setEditDisplay(d)}>

                        Edit

                      </Button>

                      <Button size="small" color="error" onClick={() => removeDisplay(d.id)}>

                        Remove

                      </Button>

                    </TableCell>

                  </TableRow>

                );

              })

            )}

          </TableBody>

        </Table>

      </TableContainer>



      <DisplaysBackupSection onChanged={refresh} />



      {adoptOpen && (

        <AdoptDisplayDialog

          open

          dismissible={adopted}

          onClose={() => setAdoptOpen(false)}

          onAdopted={handleAdopted}

        />

      )}



      {editDisplay && (

        <EditDisplayDialog

          display={editDisplay}

          onClose={() => setEditDisplay(null)}

          onSave={async (input) => {
            setLabelError(null);
            try {
              await updateDisplay(editDisplay.id, input);
              setSuccess('Display saved.');
            } catch (e) {
              setLabelError(String(e));
              throw e;
            }
          }}

        />

      )}

    </Stack>

  );

}


