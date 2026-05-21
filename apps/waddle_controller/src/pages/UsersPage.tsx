import { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Checkbox,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  FormControlLabel,
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
import { isUserModeActive, useControllerAuth } from '@/context/ControllerAuthContext';
import { completeDialogSave } from '@/util/dialogSave';

function formatLastLogin(iso: string | null): string {
  if (!iso) return 'Never';
  try {
    return new Date(iso).toLocaleString();
  } catch {
    return iso;
  }
}

export function UsersPage() {
  const { status } = useControllerAuth();
  const [users, setUsers] = useState<BffUserRecord[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [createOpen, setCreateOpen] = useState(false);
  const [editUser, setEditUser] = useState<BffUserRecord | null>(null);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState<ControllerRole>('operator');
  const [mustChangePassword, setMustChangePassword] = useState(false);
  const [creating, setCreating] = useState(false);
  const [createErr, setCreateErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [editErr, setEditErr] = useState<string | null>(null);

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
    setMustChangePassword(false);
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
      await createBffUser({ username, password, role, mustChangePassword });
      closeCreateDialog();
      setUsername('');
      setPassword('');
      setRole('operator');
      setMustChangePassword(false);
      await load();
    } catch (e) {
      setCreateErr(e instanceof BffError ? e.message : String(e));
    } finally {
      setCreating(false);
    }
  };

  const openEdit = (user: BffUserRecord) => {
    setEditUser(user);
    setRole(user.role);
    setPassword('');
    setMustChangePassword(user.mustChangePassword);
    setEditErr(null);
  };

  const closeEdit = () => {
    setEditUser(null);
    setEditErr(null);
    setPassword('');
  };

  const saveEdit = async () => {
    if (!editUser) return;
    setSaving(true);
    setEditErr(null);
    try {
      const patch: {
        role: ControllerRole;
        mustChangePassword: boolean;
        password?: string;
      } = { role, mustChangePassword };
      if (password.trim()) {
        patch.password = password;
      }
      await updateBffUser(editUser.id, patch);
      await completeDialogSave(load, closeEdit);
    } catch (e) {
      setEditErr(e instanceof BffError ? e.message : String(e));
    } finally {
      setSaving(false);
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

  if (!status || !isUserModeActive(status)) {
    return (
      <Alert severity="info">
        User mode is off. Turn it on above to manage controller accounts, or use display recovery on
        the Displays tab if you need to copy server-stored settings into this browser.
      </Alert>
    );
  }

  return (
    <Stack spacing={3} sx={{ maxWidth: 1100 }}>
      <Box>
        <Stack
          direction={{ xs: 'column', sm: 'row' }}
          justifyContent="space-between"
          alignItems={{ xs: 'flex-start', sm: 'center' }}
          spacing={1}
          sx={{ mb: 1 }}
        >
          <Typography variant="h5" fontWeight={600}>
            Controller accounts
          </Typography>
          <Button variant="contained" onClick={openCreateDialog}>
            Add user
          </Button>
        </Stack>
        <Typography variant="body2" color="text.secondary">
          Admin and operator accounts for signing in to this controller. Disabled users cannot sign
          in until re-enabled.
        </Typography>
      </Box>
      {error && <Alert severity="error">{error}</Alert>}
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Username</TableCell>
            <TableCell>Role</TableCell>
            <TableCell>Last login</TableCell>
            <TableCell>Must change password</TableCell>
            <TableCell>Disabled</TableCell>
            <TableCell align="right">Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {users.map((u) => (
            <TableRow key={u.id}>
              <TableCell>{u.username}</TableCell>
              <TableCell>{u.role}</TableCell>
              <TableCell>{formatLastLogin(u.lastLoginAt)}</TableCell>
              <TableCell>{u.mustChangePassword ? 'Yes' : 'No'}</TableCell>
              <TableCell>
                <Switch checked={u.disabled} onChange={() => void toggleDisabled(u)} />
              </TableCell>
              <TableCell align="right">
                <Button size="small" onClick={() => openEdit(u)} sx={{ mr: 0.5 }}>
                  Edit
                </Button>
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
              <Select
                label="Role"
                value={role}
                onChange={(e) => setRole(e.target.value as ControllerRole)}
              >
                <MenuItem value="operator">Operator</MenuItem>
                <MenuItem value="admin">Admin</MenuItem>
              </Select>
            </FormControl>
            <FormControlLabel
              control={
                <Checkbox
                  checked={mustChangePassword}
                  onChange={(e) => setMustChangePassword(e.target.checked)}
                  disabled={creating}
                />
              }
              label="Require password change on next sign-in"
            />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={closeCreateDialog}>Cancel</Button>
          <Button variant="contained" onClick={() => void createUser()} disabled={creating}>
            {creating ? 'Creating…' : 'Create'}
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={editUser !== null} onClose={closeEdit} fullWidth maxWidth="xs">
        <DialogTitle>Edit user</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            {editErr && <Alert severity="error">{editErr}</Alert>}
            <TextField label="Username" value={editUser?.username ?? ''} disabled />
            <FormControl disabled={saving}>
              <InputLabel>Role</InputLabel>
              <Select
                label="Role"
                value={role}
                onChange={(e) => setRole(e.target.value as ControllerRole)}
              >
                <MenuItem value="operator">Operator</MenuItem>
                <MenuItem value="admin">Admin</MenuItem>
              </Select>
            </FormControl>
            <TextField
              label="New password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              helperText="Leave blank to keep current password"
              disabled={saving}
            />
            <FormControlLabel
              control={
                <Checkbox
                  checked={mustChangePassword}
                  onChange={(e) => setMustChangePassword(e.target.checked)}
                  disabled={saving}
                />
              }
              label="Require password change on next sign-in"
            />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={closeEdit}>Cancel</Button>
          <Button variant="contained" onClick={() => void saveEdit()} disabled={saving}>
            {saving ? 'Saving…' : 'Save'}
          </Button>
        </DialogActions>
      </Dialog>
    </Stack>
  );
}
