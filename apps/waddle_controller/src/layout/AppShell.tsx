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
import { ProgramsPlayoutIcon } from '@/icons/ProgramsPlayoutIcon';
import { ScreenCarouselIcon } from '@/icons/ScreenCarouselIcon';
import { TickerTapeIcon } from '@/icons/TickerTapeIcon';
import LayersIcon from '@mui/icons-material/Layers';
import StorageIcon from '@mui/icons-material/Storage';
import DatasetIcon from '@mui/icons-material/Dataset';
import SettingsRemoteIcon from '@mui/icons-material/SettingsRemote';
import ListAltIcon from '@mui/icons-material/ListAlt';
import SettingsIcon from '@mui/icons-material/Settings';
import TuneIcon from '@mui/icons-material/Tune';
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown';
import LoginIcon from '@mui/icons-material/Login';
import LogoutIcon from '@mui/icons-material/Logout';
import ManageAccountsIcon from '@mui/icons-material/ManageAccounts';
import AdminPanelSettingsIcon from '@mui/icons-material/AdminPanelSettings';
import { useAuth } from '@/context/AuthContext';
import { useControllerAuth } from '@/context/ControllerAuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { dismissActiveDisplayAlert, postDisplayNavigation } from '@/util/displayRemote';
import { PREVIEWABLE_CONTROLLER_ROLES } from '@/auth/rolePermissions';
import { DisplaySelector } from '@/components/DisplaySelector';

const drawerWidth = 260;
const appVersion = __APP_VERSION__;

function clientInitials(identifier: string): string {
  const id = identifier.trim();
  if (id.length >= 2) return id.slice(0, 2).toUpperCase();
  return (id[0] ?? '?').toUpperCase();
}

type NavItem = {
  to: string;
  label: string;
  icon: ReactNode;
  requiresNavigationControl?: boolean;
};

const realtimeNav: NavItem[] = [
  { to: '/remote', label: 'Remote', icon: <SettingsRemoteIcon />, requiresNavigationControl: true },
  { to: '/programs', label: 'Programs', icon: <ProgramsPlayoutIcon /> },
];

const configNav: NavItem[] = [
  { to: '/curators', label: 'Curators', icon: <TuneIcon /> },
  { to: '/screens', label: 'Screens', icon: <ScreenCarouselIcon /> },
  { to: '/ticker-tapes', label: 'Ticker Tapes', icon: <TickerTapeIcon /> },
  { to: '/overlays', label: 'Overlays', icon: <LayersIcon /> },
  { to: '/integrations', label: 'Integrations', icon: <StorageIcon /> },
  { to: '/data', label: 'Data', icon: <DatasetIcon /> },
];

const nav = [...realtimeNav, ...configNav];

export function AppShell({ children }: { children?: ReactNode }) {
  const theme = useTheme();
  const isMdUp = useMediaQuery(theme.breakpoints.up('md'));
  const [mobileOpen, setMobileOpen] = useState(false);
  const [userMenuAnchor, setUserMenuAnchor] = useState<null | HTMLElement>(null);
  const location = useLocation();
  const { active } = useDisplay();
  const {
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
  const { status: bffStatus, logout: controllerLogout } = useControllerAuth();

  const signedIn = Boolean(session && !needsLogin);
  const showUserMenu = Boolean(bffStatus?.authEnabled);

  const filterDrawerNav = (items: NavItem[]) =>
    items.filter((item) => {
      if (item.requiresNavigationControl && !hasPermission('navigation.control')) return false;
      if (!isProgramsOnlyControllerUser) return true;
      return (
        item.to === '/programs' ||
        item.to === '/remote' ||
        (item.to === '/data' &&
          (hasPermission('content.moderate') || hasPermission('content.catalog_read')))
      );
    });

  const drawerRealtimeNav = filterDrawerNav(realtimeNav);
  const drawerConfigNav = filterDrawerNav(configNav);
  const drawerNavItems = [...drawerRealtimeNav, ...drawerConfigNav];
  const showNavSectionDivider =
    drawerRealtimeNav.length > 0 && drawerConfigNav.length > 0;
  const [snack, setSnack] = useState<string | null>(null);
  const [rolePreviewOpen, setRolePreviewOpen] = useState(false);
  const [rolePreviewChoice, setRolePreviewChoice] =
    useState<(typeof PREVIEWABLE_CONTROLLER_ROLES)[number]>('operator');

  useEffect(() => {
    if (!signedIn) {
      setMobileOpen(false);
    }
  }, [signedIn]);

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
      if (surface && direction) {
        e.preventDefault();
        void (async () => {
          const err = await postDisplayNavigation(active, surface, direction);
          if (err) setSnack(err);
        })();
        return;
      }
      if (
        (e.key === 'Enter' || e.key === 'NumpadEnter') &&
        hasPermission('alerts.write')
      ) {
        e.preventDefault();
        void (async () => {
          const err = await dismissActiveDisplayAlert(active);
          if (err) setSnack(err);
        })();
      }
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

      {signedIn && (
        <>
          <Divider sx={{ borderColor: 'rgba(255,255,255,0.12)' }} />
          <List sx={{ flex: 1, px: 1 }}>
            {drawerRealtimeNav.map((item) => {
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
            {showNavSectionDivider && (
              <Divider sx={{ my: 1, borderColor: 'rgba(255,255,255,0.12)' }} />
            )}
            {drawerConfigNav.map((item) => {
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
          <Typography variant="body2" color="text.secondary" sx={{ px: 1, py: 0.5 }}>
            v{appVersion}
          </Typography>
          <Divider sx={{ borderColor: 'rgba(255,255,255,0.12)' }} />
          <List sx={{ px: 1, py: 1 }}>
            {!isProgramsOnlyControllerUser && (
              <>
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
                  to="/display-settings"
                  selected={location.pathname.startsWith('/display-settings')}
                  onClick={() => setMobileOpen(false)}
                  sx={{
                    borderRadius: 2,
                    my: 0.5,
                    '&.Mui-selected': { bgcolor: 'primary.main', color: 'primary.contrastText' },
                  }}
                >
                  <ListItemIcon
                    sx={{
                      color: location.pathname.startsWith('/display-settings')
                        ? 'inherit'
                        : 'grey.400',
                      minWidth: 40,
                    }}
                  >
                    <SettingsIcon />
                  </ListItemIcon>
                  <ListItemText primary="Display Settings" />
                </ListItemButton>
              </>
            )}
          </List>
        </>
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
          width: { md: signedIn ? `calc(100% - ${drawerWidth}px)` : '100%' },
          ml: { md: signedIn ? `${drawerWidth}px` : 0 },
        }}
      >
        <Toolbar>
          {!isMdUp && signedIn && (
            <IconButton edge="start" onClick={() => setMobileOpen(true)} sx={{ mr: 1 }}>
              <MenuIcon />
            </IconButton>
          )}
          
          <Typography variant="h6" fontWeight={600} sx={{ flexGrow: 1 }}>
          {location.pathname.startsWith('/controller-settings')
              ? 'Controller Settings'
              : location.pathname.startsWith('/display-settings')
                ? 'Display Settings'
                : location.pathname.startsWith('/curators')
                  ? 'Curators'
                  : location.pathname.startsWith('/account')
                ? 'Preferences'
                : location.pathname.startsWith('/activity')
                  ? 'Activity Log'
                  : location.pathname.startsWith('/data')
                  ? 'Data'
                  : drawerNavItems.find((n) => location.pathname.startsWith(n.to))?.label ??
                    nav.find((n) => location.pathname.startsWith(n.to))?.label ??
                    'Waddle'}
          </Typography>
          <DisplaySelector  />
          {active && (
            <>
              {session && !needsLogin ? (
                showUserMenu ? (
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
                        {clientInitials(session.identifier)}
                      </Avatar>
                    }
                    endIcon={<KeyboardArrowDownIcon />}
                    sx={{ fontWeight: 600, textTransform: 'none', maxWidth: { xs: 160, sm: 280 } }}
                  >
                    <Typography component="span" noWrap variant="body1" fontWeight={600}>
                      {session.identifier}
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
                    {bffStatus?.authEnabled && (
                      <MenuItem
                        onClick={() => {
                          setUserMenuAnchor(null);
                          void controllerLogout();
                        }}
                      >
                        <ListItemIcon>
                          <LogoutIcon fontSize="small" />
                        </ListItemIcon>
                        <ListItemText>Controller sign out</ListItemText>
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
                      <ListItemText>Display log out</ListItemText>
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
                ) : null
              ) : (
                <Button
                  color="inherit"
                  onClick={() => openLoginDialog()}
                  sx={{ fontWeight: 600, textTransform: 'none' }}
                  startIcon={<LoginIcon />}
                >
                  Adopt display
                </Button>
              )}
            </>
          )}
        </Toolbar>
      </AppBar>

      {signedIn && (
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
      )}

      <Box
        component="main"
        sx={{
          flexGrow: 1,
          p: 3,
          mt: 8,
          width: { md: signedIn ? `calc(100% - ${drawerWidth}px)` : '100%' },
          bgcolor: 'background.default',
          minHeight: '100vh',
        }}
      >
        {isAdminUser && viewAsRole && !needsLogin && showUserMenu && (
          <Alert severity="info" sx={{ mb: 2 }}>
            Previewing the UI with <strong>{viewAsRole}</strong> permissions. Use{' '}
            <strong>Return to admin view</strong> in the user menu when finished.
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
