import { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Card,
  CardActions,
  CardContent,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  InputLabel,
  MenuItem,
  Paper,
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
import { DataViewEmptyState } from '@/components/dataView/DataViewEmptyState';
import { DataViewPagination } from '@/components/dataView/DataViewPagination';
import { DataViewToolbar } from '@/components/dataView/DataViewToolbar';
import { catalogCardGridSx } from '@/constants/catalogLayout';
import { useControllerAuth } from '@/context/ControllerAuthContext';
import { useClientDataView } from '@/hooks/useClientDataView';
import { useListLayoutPreference } from '@/hooks/useListLayoutPreference';
import type { SortOption } from '@/util/clientListPipeline';

const USER_SORT_OPTIONS: SortOption<BffUserRecord>[] = [
  {
    id: 'username_asc',
    label: 'Username (A–Z)',
    compare: (a, b) => a.username.localeCompare(b.username),
  },
  {
    id: 'username_desc',
    label: 'Username (Z–A)',
    compare: (a, b) => b.username.localeCompare(a.username),
  },
  { id: 'role', label: 'Role', compare: (a, b) => a.role.localeCompare(b.role) || a.username.localeCompare(b.username) },
];

function UserCard({
  user,
  onToggleDisabled,
  onRemove,
}: {
  user: BffUserRecord;
  onToggleDisabled: () => void;
  onRemove: () => void;
}) {
  return (
    <Card variant="outlined" sx={{ height: '100%' }}>
      <CardContent>
        <Typography variant="subtitle1" fontWeight={600}>
          {user.username}
        </Typography>
        <Stack direction="row" spacing={1} sx={{ mt: 1 }} flexWrap="wrap">
          <Chip size="small" label={user.role} />
          {user.disabled ? <Chip size="small" color="warning" label="Disabled" /> : null}
        </Stack>
      </CardContent>
      <CardActions sx={{ justifyContent: 'flex-end' }}>
        <Switch checked={user.disabled} onChange={() => onToggleDisabled()} />
        <Button color="error" size="small" onClick={onRemove}>
          Delete
        </Button>
      </CardActions>
    </Card>
  );
}

export function UsersPage() {
  const { status } = useControllerAuth();
  const { layout, setLayout } = useListLayoutPreference('users');
  const [users, setUsers] = useState<BffUserRecord[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [createOpen, setCreateOpen] = useState(false);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState<ControllerRole>('operator');
  const [creating, setCreating] = useState(false);
  const [createErr, setCreateErr] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await listBffUsers();
      setUsers(res.users);
    } catch (e) {
      setError(e instanceof BffError ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const dataView = useClientDataView({
    items: users,
    sortOptions: USER_SORT_OPTIONS,
    defaultSortId: 'username_asc',
    searchMatches: (u, q) =>
      u.username.toLowerCase().includes(q) || u.role.toLowerCase().includes(q),
  });

  const displayRows = dataView.paginated.items;

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
        <Typography variant="h5" fontWeight={600} sx={{ mb: 1 }}>
          BFF operator accounts
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Operator and admin accounts for BFF sign-in to this controller. Disabled users remain in
          the list but cannot authenticate until re-enabled.
        </Typography>
      </Box>
      {error && <Alert severity="error">{error}</Alert>}

      <DataViewToolbar
        layout={layout}
        onLayoutChange={setLayout}
        search={dataView.search}
        onSearchChange={dataView.setSearch}
        searchPlaceholder="Search users…"
        sortOptions={USER_SORT_OPTIONS}
        sortId={dataView.sortId}
        onSortChange={dataView.setSortId}
        onReload={() => void load()}
        reloadDisabled={loading}
        reloadAriaLabel="Reload users"
      >
        <Button variant="contained" onClick={openCreateDialog}>
          Add user
        </Button>
      </DataViewToolbar>

      <Stack spacing={2}>
        <DataViewEmptyState
          hasItems={users.length > 0}
          hasFilteredMatches={displayRows.length > 0}
          emptyMessage="No operator accounts yet."
        />
        {displayRows.length > 0 && layout === 'card' ? (
          <Box sx={catalogCardGridSx}>
            {displayRows.map((u) => (
              <UserCard
                key={u.id}
                user={u}
                onToggleDisabled={() => void toggleDisabled(u)}
                onRemove={() => void remove(u.id)}
              />
            ))}
          </Box>
        ) : displayRows.length > 0 ? (
          <Paper variant="outlined">
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
                {displayRows.map((u) => (
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
          </Paper>
        ) : null}
        <DataViewPagination
          count={dataView.filteredTotal}
          page={dataView.paginated.page}
          pageSize={dataView.paginated.pageSize}
          onPageChange={dataView.setPage}
          onPageSizeChange={dataView.setPageSize}
        />
      </Stack>

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
