import { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Switch,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import type { ControllerRole } from '@/api/bffAuth';
import { BffError } from '@/api/bffClient';
import {
  createBffUser,
  deleteBffUser,
  listBffUsers,
  updateBffUser,
  type BffUserRecord,
} from '@/api/bffUsers';
import { useControllerAuth } from '@/context/ControllerAuthContext';

export function UsersPage() {
  const { status } = useControllerAuth();
  const [users, setUsers] = useState<BffUserRecord[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [createOpen, setCreateOpen] = useState(false);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState<ControllerRole>('operator');
  const [creating, setCreating] = useState(false);
  const [createErr, setCreateErr] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const res = await listBffUsers();
      setUsers(res.users);
    } catch (e) {
      setError(e instanceof BffError ? e.message : String(e));
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const openCreateDialog = () => {
    setCreateErr(null);
    setCreateOpen(true);
  };

  const closeCreateDialog = () => {
    setCreateOpen(false);
    setCreateErr(null);
  };

  const createUser = async () => {
    setCreating(true);
    setCreateErr(null);
    try {
      await createBffUser({ username, password, role });
      closeCreateDialog();
      setUsername('');
      setPassword('');
      setRole('operator');
      await load();
    } catch (e) {
      setCreateErr(e instanceof BffError ? e.message : String(e));
    } finally {
      setCreating(false);
    }
  };

  const toggleDisabled = async (user: BffUserRecord) => {
    try {
      await updateBffUser(user.id, { disabled: !user.disabled });
      await load();
    } catch (e) {
      setError(e instanceof BffError ? e.message : String(e));
    }
  };

  const remove = async (id: string) => {
    try {
      await deleteBffUser(id);
      await load();
    } catch (e) {
      setError(e instanceof BffError ? e.message : String(e));
    }
  };

  if (!status?.userManagementEnabled) {
    return (
      <Alert severity="info">
        User management is disabled. Enable it on the <strong>Users</strong> tab under Controller
        Settings (admin only).
      </Alert>
    );
  }

  return (
    <Stack spacing={3} sx={{ maxWidth: 960 }}>
      <Box>
        <Stack
          direction={{ xs: 'column', sm: 'row' }}
          justifyContent="space-between"
          alignItems={{ xs: 'flex-start', sm: 'center' }}
          spacing={1}
          sx={{ mb: 1 }}
        >
          <Typography variant="h5" fontWeight={600}>
            BFF operator accounts
          </Typography>
          <Button variant="contained" onClick={openCreateDialog}>
            Add user
          </Button>
        </Stack>
        <Typography variant="body2" color="text.secondary">
          Operator and admin accounts for BFF sign-in to this controller. Disabled users remain in
          the list but cannot authenticate until re-enabled.
        </Typography>
      </Box>
      {error && <Alert severity="error">{error}</Alert>}
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Username</TableCell>
            <TableCell>Role</TableCell>
            <TableCell>Disabled</TableCell>
            <TableCell align="right">Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {users.map((u) => (
            <TableRow key={u.id}>
              <TableCell>{u.username}</TableCell>
              <TableCell>{u.role}</TableCell>
              <TableCell>
                <Switch checked={u.disabled} onChange={() => void toggleDisabled(u)} />
              </TableCell>
              <TableCell align="right">
                <Button color="error" size="small" onClick={() => void remove(u.id)}>
                  Delete
                </Button>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>

      <Dialog open={createOpen} onClose={closeCreateDialog} fullWidth maxWidth="xs">
        <DialogTitle>Add user</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            {createErr && <Alert severity="error">{createErr}</Alert>}
            <TextField
              label="Username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              disabled={creating}
            />
            <TextField
              label="Password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              helperText="At least 12 characters"
              disabled={creating}
            />
            <FormControl disabled={creating}>
              <InputLabel>Role</InputLabel>
              <Select label="Role" value={role} onChange={(e) => setRole(e.target.value as ControllerRole)}>
                <MenuItem value="operator">Operator</MenuItem>
                <MenuItem value="admin">Admin</MenuItem>
              </Select>
            </FormControl>
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={closeCreateDialog}>Cancel</Button>
          <Button variant="contained" onClick={() => void createUser()} disabled={creating}>
            {creating ? 'Creating…' : 'Create'}
          </Button>
        </DialogActions>
      </Dialog>
    </Stack>
  );
}
