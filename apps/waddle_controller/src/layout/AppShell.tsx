import { useEffect, useState, type ReactNode } from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import { Link as RouterLink } from 'react-router';
import {
  AppBar,
  Avatar,
  Box,
  Button,
  Divider,
  Drawer,
  IconButton,
  List,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Toolbar,
  Typography,
  useMediaQuery,
  useTheme,
  Menu,
  MenuItem,
  Select,
  FormControl,
  InputLabel,
  Snackbar,
  Alert,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  RadioGroup,
  FormControlLabel,
  Radio,
} from '@mui/material';
import MenuIcon from '@mui/icons-material/Menu';
import PeopleIcon from '@mui/icons-material/People';
import BarChartIcon from '@mui/icons-material/BarChart';
import DesktopWindowsIcon from '@mui/icons-material/DesktopWindows';
import LayersIcon from '@mui/icons-material/Layers';
import StorageIcon from '@mui/icons-material/Storage';
import DatasetIcon from '@mui/icons-material/Dataset';
import ListAltIcon from '@mui/icons-material/ListAlt';
import SettingsIcon from '@mui/icons-material/Settings';
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown';
import AccountCircleOutlinedIcon from '@mui/icons-material/AccountCircleOutlined';
import LoginIcon from '@mui/icons-material/Login';
import LogoutIcon from '@mui/icons-material/Logout';
import ManageAccountsIcon from '@mui/icons-material/ManageAccounts';
import AdminPanelSettingsIcon from '@mui/icons-material/AdminPanelSettings';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { apiFetch, ApiError } from '@/api/client';
import TheatersIcon from '@mui/icons-material/Theaters';
import type { AuthUser } from '@/storage/sessions';
import { PREVIEWABLE_CONTROLLER_ROLES } from '@/auth/rolePermissions';

const drawerWidth = 260;

function userInitials(user: AuthUser): string {
  const name = user.display_name?.trim();
  if (name) {
    const parts = name.split(/\s+/).filter(Boolean);
    if (parts.length >= 2) {
      const a = parts[0][0];
      const b = parts[parts.length - 1][0];
      if (a && b) return `${a}${b}`.toUpperCase();
    }
    if (parts.length === 1) {
      const p = parts[0];
      return (p.length >= 2 ? p.slice(0, 2) : p[0] ?? '?').toUpperCase();
    }
  }
  const u = user.username?.trim() ?? '';
  if (u.length >= 2) return u.slice(0, 2).toUpperCase();
  return (u[0] ?? '?').toUpperCase();
}

const nav = [
  { to: '/curators', label: 'Curators', icon: <PeopleIcon /> },
  { to: '/programs', label: 'Programs', icon: <BarChartIcon /> },
  { to: '/screens', label: 'Screens', icon: <DesktopWindowsIcon /> },
  { to: '/ticker-tapes', label: 'Ticker Tapes', icon: <TheatersIcon /> },
  { to: '/overlays', label: 'Overlays', icon: <LayersIcon /> },
  { to: '/integrations', label: 'Integrations', icon: <StorageIcon /> },
  { to: '/data', label: 'Data', icon: <DatasetIcon /> },
];

export function AppShell({ children }: { children?: ReactNode }) {
  const theme = useTheme();
  const isMdUp = useMediaQuery(theme.breakpoints.up('md'));
  const [mobileOpen, setMobileOpen] = useState(false);
  const [userMenuAnchor, setUserMenuAnchor] = useState<null | HTMLElement>(null);
  const location = useLocation();
  const { displays, active, setActiveId } = useDisplay();
  const {
    bootstrapWarning,
    needsLogin,
    session,
    logout,
    openLoginDialog,
    isAdminUser,
    viewAsRole,
    setViewAsRole,
    clearViewAsRole,
    hasPermission,
    isProgramsOnlyControllerUser,
  } = useAuth();

  const drawerNavItems = isProgramsOnlyControllerUser
    ? nav.filter(
        (item) =>
          item.to === '/programs' ||
          (item.to === '/data' &&
            (hasPermission('content.moderate') || hasPermission('content.catalog_read'))),
      )
    : nav;
  const [snack, setSnack] = useState<string | null>(null);
  const [rolePreviewOpen, setRolePreviewOpen] = useState(false);
  const [rolePreviewChoice, setRolePreviewChoice] =
    useState<(typeof PREVIEWABLE_CONTROLLER_ROLES)[number]>('operator');

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (!active) return;
      if (!hasPermission('navigation.control')) return;
      const t = e.target as HTMLElement | null;
      if (t && ['INPUT', 'TEXTAREA', 'SELECT'].includes(t.tagName)) return;
      if (t?.isContentEditable) return;
      let surface: 'screen' | 'ticker' | null = null;
      let direction: 'back' | 'forward' | null = null;
      if (e.key === 'ArrowLeft') {
        surface = 'screen';
        direction = 'back';
      } else if (e.key === 'ArrowRight') {
        surface = 'screen';
        direction = 'forward';
      } else if (e.key === 'ArrowUp') {
        surface = 'ticker';
        direction = 'back';
      } else if (e.key === 'ArrowDown') {
        surface = 'ticker';
        direction = 'forward';
      }
      if (!surface || !direction) return;
      e.preventDefault();
      void (async () => {
        try {
          await apiFetch(active, '/v1/display/navigation', {
            method: 'POST',
            body: JSON.stringify({ surface, direction }),
          });
        } catch (err) {
          const msg =
            err instanceof ApiError ? `${err.status}: ${err.message}` : String(err);
          setSnack(msg);
        }
      })();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [active, hasPermission]);

  const drawer = (
    <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <Toolbar>
        <Typography variant="h6" fontWeight={700}>
          Waddle Controller
        </Typography>
      </Toolbar>
      <Divider sx={{ borderColor: 'rgba(255,255,255,0.12)' }} />
      {displays.length > 1 && (
        <Box sx={{ px: 2, py: 1.5 }}>
          <FormControl fullWidth size="small" variant="outlined">
            <InputLabel id="display-select" sx={{ color: 'grey.400' }}>
              Display
            </InputLabel>
            <Select
              labelId="display-select"
              label="Display"
              value={active?.id ?? ''}
              onChange={(ev) => setActiveId(ev.target.value as string)}
              sx={{ color: 'common.white', '.MuiOutlinedInput-notchedOutline': { borderColor: 'rgba(255,255,255,0.3)' } }}
            >
              {displays.map((d) => (
                <MenuItem key={d.id} value={d.id}>
                  {d.label}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
        </Box>
      )}
      <List sx={{ flex: 1, px: 1 }}>
        {drawerNavItems.map((item) => {
          const selected = location.pathname.startsWith(item.to);
          return (
            <ListItemButton
              key={item.to}
              component={RouterLink}
              to={item.to}
              selected={selected}
              onClick={() => setMobileOpen(false)}
              sx={{
                borderRadius: 2,
                my: 0.5,
                '&.Mui-selected': { bgcolor: 'primary.main', color: 'primary.contrastText' },
              }}
            >
              <ListItemIcon sx={{ color: selected ? 'inherit' : 'grey.400', minWidth: 40 }}>
                {item.icon}
              </ListItemIcon>
              <ListItemText primary={item.label} />
            </ListItemButton>
          );
        })}
      </List>
      <Divider sx={{ borderColor: 'rgba(255,255,255,0.12)' }} />
      {!isProgramsOnlyControllerUser && (
        <List sx={{ px: 1, py: 1 }}>
          <ListItemButton
            component={RouterLink}
            to="/activity"
            selected={location.pathname.startsWith('/activity')}
            onClick={() => setMobileOpen(false)}
            sx={{
              borderRadius: 2,
              my: 0.5,
              '&.Mui-selected': { bgcolor: 'primary.main', color: 'primary.contrastText' },
            }}
          >
            <ListItemIcon
              sx={{
                color: location.pathname.startsWith('/activity') ? 'inherit' : 'grey.400',
                minWidth: 40,
              }}
            >
              <ListAltIcon />
            </ListItemIcon>
            <ListItemText primary="Activity Log" />
          </ListItemButton>
          <ListItemButton
            component={RouterLink}
            to="/settings"
            selected={location.pathname.startsWith('/settings')}
            onClick={() => setMobileOpen(false)}
            sx={{
              borderRadius: 2,
              my: 0.5,
              '&.Mui-selected': { bgcolor: 'primary.main', color: 'primary.contrastText' },
            }}
          >
            <ListItemIcon
              sx={{
                color: location.pathname.startsWith('/settings') ? 'inherit' : 'grey.400',
                minWidth: 40,
              }}
            >
              <SettingsIcon />
            </ListItemIcon>
            <ListItemText primary="Settings" />
          </ListItemButton>
        </List>
      )}
    </Box>
  );

  return (
    <Box sx={{ display: 'flex', minHeight: '100vh' }}>
      <AppBar
        position="fixed"
        elevation={0}
        sx={{
          bgcolor: 'background.paper',
          color: 'text.primary',
          borderBottom: 1,
          borderColor: 'divider',
          width: { md: `calc(100% - ${drawerWidth}px)` },
          ml: { md: `${drawerWidth}px` },
        }}
      >
        <Toolbar>
          {!isMdUp && (
            <IconButton edge="start" onClick={() => setMobileOpen(true)} sx={{ mr: 1 }}>
              <MenuIcon />
            </IconButton>
          )}
          <Typography variant="h6" fontWeight={600} sx={{ flexGrow: 1 }}>
            {location.pathname.startsWith('/settings')
              ? 'Settings'
              : location.pathname.startsWith('/account')
                ? 'Account'
                : location.pathname.startsWith('/activity')
                  ? 'Activity Log'
                  : location.pathname.startsWith('/data')
                  ? 'Data'
                  : drawerNavItems.find((n) => location.pathname.startsWith(n.to))?.label ??
                    nav.find((n) => location.pathname.startsWith(n.to))?.label ??
                    'Waddle'}
          </Typography>
          {active && (
            <>
              {session && !needsLogin ? (
                <>
                  <Button
                    color="inherit"
                    id="user-menu-button"
                    aria-controls={userMenuAnchor ? 'user-menu' : undefined}
                    aria-haspopup="true"
                    aria-expanded={userMenuAnchor ? 'true' : undefined}
                    onClick={(e) => setUserMenuAnchor(e.currentTarget)}
                    startIcon={
                      <Avatar
                        aria-hidden
                        sx={{
                          width: 32,
                          height: 32,
                          fontSize: '0.8125rem',
                          fontWeight: 700,
                          bgcolor: 'primary.main',
                          color: 'primary.contrastText',
                        }}
                      >
                        {userInitials(session.user)}
                      </Avatar>
                    }
                    endIcon={<KeyboardArrowDownIcon />}
                    sx={{ fontWeight: 600, textTransform: 'none', maxWidth: { xs: 160, sm: 280 } }}
                  >
                    <Typography component="span" noWrap variant="body1" fontWeight={600}>
                      {session.user.display_name?.trim() || session.user.username}
                    </Typography>
                  </Button>
                  <Menu
                    id="user-menu"
                    anchorEl={userMenuAnchor}
                    open={Boolean(userMenuAnchor)}
                    onClose={() => setUserMenuAnchor(null)}
                    anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
                    transformOrigin={{ vertical: 'top', horizontal: 'right' }}
                    slotProps={{ list: { 'aria-labelledby': 'user-menu-button' } }}
                  >
                    <MenuItem
                      component={RouterLink}
                      to="/account"
                      onClick={() => setUserMenuAnchor(null)}
                    >
                      <ListItemIcon>
                        <AccountCircleOutlinedIcon fontSize="small" />
                      </ListItemIcon>
                      <ListItemText>Account</ListItemText>
                    </MenuItem>
                    {isAdminUser && viewAsRole && (
                      <MenuItem
                        onClick={() => {
                          setUserMenuAnchor(null);
                          clearViewAsRole();
                        }}
                      >
                        <ListItemIcon>
                          <AdminPanelSettingsIcon fontSize="small" />
                        </ListItemIcon>
                        <ListItemText>Return to admin view</ListItemText>
                      </MenuItem>
                    )}
                    {isAdminUser && !viewAsRole && (
                      <MenuItem
                        onClick={() => {
                          setUserMenuAnchor(null);
                          setRolePreviewChoice('operator');
                          setRolePreviewOpen(true);
                        }}
                      >
                        <ListItemIcon>
                          <ManageAccountsIcon fontSize="small" />
                        </ListItemIcon>
                        <ListItemText>View UI as role…</ListItemText>
                      </MenuItem>
                    )}
                    <MenuItem
                      onClick={() => {
                        setUserMenuAnchor(null);
                        void logout();
                      }}
                    >
                      <ListItemIcon>
                        <LogoutIcon fontSize="small" />
                      </ListItemIcon>
                      <ListItemText>Log out</ListItemText>
                    </MenuItem>
                  </Menu>
                  <Dialog
                    open={rolePreviewOpen}
                    onClose={() => setRolePreviewOpen(false)}
                    aria-labelledby="role-preview-title"
                    maxWidth="xs"
                    fullWidth
                  >
                    <DialogTitle id="role-preview-title">View UI as role</DialogTitle>
                    <DialogContent>
                      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                        The controller hides controls you would not have with that role. API calls still
                        use your signed-in session and server permission checks still apply.
                      </Typography>
                      <RadioGroup
                        value={rolePreviewChoice}
                        onChange={(e) =>
                          setRolePreviewChoice(e.target.value as (typeof PREVIEWABLE_CONTROLLER_ROLES)[number])
                        }
                      >
                        {PREVIEWABLE_CONTROLLER_ROLES.map((r) => (
                          <FormControlLabel key={r} value={r} control={<Radio />} label={r} />
                        ))}
                      </RadioGroup>
                    </DialogContent>
                    <DialogActions>
                      <Button onClick={() => setRolePreviewOpen(false)}>Cancel</Button>
                      <Button
                        variant="contained"
                        onClick={() => {
                          setViewAsRole(rolePreviewChoice);
                          setRolePreviewOpen(false);
                        }}
                      >
                        Apply
                      </Button>
                    </DialogActions>
                  </Dialog>
                </>
              ) : (
                <Button
                  color="inherit"
                  onClick={() => openLoginDialog()}
                  sx={{ fontWeight: 600, textTransform: 'none' }}
                  startIcon={<LoginIcon />}
                >
                  Sign in
                </Button>
              )}
            </>
          )}
        </Toolbar>
      </AppBar>

      <Box component="nav" sx={{ width: { md: drawerWidth }, flexShrink: { md: 0 } }}>
        <Drawer
          variant="temporary"
          open={mobileOpen}
          onClose={() => setMobileOpen(false)}
          ModalProps={{ keepMounted: true }}
          sx={{
            display: { xs: 'block', md: 'none' },
            '& .MuiDrawer-paper': { boxSizing: 'border-box', width: drawerWidth },
          }}
        >
          {drawer}
        </Drawer>
        <Drawer
          variant="permanent"
          sx={{
            display: { xs: 'none', md: 'block' },
            '& .MuiDrawer-paper': { boxSizing: 'border-box', width: drawerWidth },
          }}
          open
        >
          {drawer}
        </Drawer>
      </Box>

      <Box
        component="main"
        sx={{
          flexGrow: 1,
          p: 3,
          mt: 8,
          width: { md: `calc(100% - ${drawerWidth}px)` },
          bgcolor: 'background.default',
          minHeight: '100vh',
        }}
      >
        {isAdminUser && viewAsRole && !needsLogin && (
          <Alert severity="info" sx={{ mb: 2 }}>
            Previewing the UI with <strong>{viewAsRole}</strong> permissions. Use{' '}
            <strong>Return to admin view</strong> in the user menu when finished.
          </Alert>
        )}
        {bootstrapWarning && !needsLogin && (
          <Alert severity="warning" sx={{ mb: 2 }}>
            You are signed in as the bootstrap user <strong>display</strong>. Create a named user
            account in Settings — the bootstrap account is disabled once another user exists.
          </Alert>
        )}
        {children ?? <Outlet />}
      </Box>

      <Snackbar open={!!snack} autoHideDuration={6000} onClose={() => setSnack(null)}>
        <Alert severity="error" onClose={() => setSnack(null)}>
          {snack}
        </Alert>
      </Snackbar>
    </Box>
  );
}
