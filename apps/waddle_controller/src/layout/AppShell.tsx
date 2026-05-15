import { useEffect, useState, type ReactNode } from 'react';
import { Link as RouterLink, Outlet, useLocation } from 'react-router-dom';
import {
  AppBar,
  Box,
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
  MenuItem,
  Select,
  FormControl,
  InputLabel,
  Snackbar,
  Alert,
} from '@mui/material';
import MenuIcon from '@mui/icons-material/Menu';
import PeopleIcon from '@mui/icons-material/People';
import BarChartIcon from '@mui/icons-material/BarChart';
import DesktopWindowsIcon from '@mui/icons-material/DesktopWindows';
import ShowChartIcon from '@mui/icons-material/ShowChart';
import LayersIcon from '@mui/icons-material/Layers';
import StorageIcon from '@mui/icons-material/Storage';
import ListAltIcon from '@mui/icons-material/ListAlt';
import SettingsIcon from '@mui/icons-material/Settings';
import { useAuth } from '@/context/AuthContext';
import { useDisplay } from '@/context/DisplayContext';
import { apiFetch, ApiError } from '@/api/client';

const drawerWidth = 260;

const nav = [
  { to: '/curators', label: 'Curators', icon: <PeopleIcon /> },
  { to: '/programs', label: 'Programs', icon: <BarChartIcon /> },
  { to: '/screens', label: 'Screens', icon: <DesktopWindowsIcon /> },
  { to: '/ticker', label: 'Ticker Data', icon: <ShowChartIcon /> },
  { to: '/overlays', label: 'Overlays', icon: <LayersIcon /> },
  { to: '/providers', label: 'Data Providers', icon: <StorageIcon /> },
  { to: '/activity', label: 'Activity Log', icon: <ListAltIcon /> },
];

export function AppShell({ children }: { children?: ReactNode }) {
  const theme = useTheme();
  const isMdUp = useMediaQuery(theme.breakpoints.up('md'));
  const [mobileOpen, setMobileOpen] = useState(false);
  const location = useLocation();
  const { displays, active, setActiveId } = useDisplay();
  const { bootstrapWarning, needsLogin } = useAuth();
  const [snack, setSnack] = useState<string | null>(null);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (!active) return;
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
  }, [active]);

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
        {nav.map((item) => {
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
      <List sx={{ px: 1, py: 1 }}>
        <ListItemButton
          component={RouterLink}
          to="/settings"
          selected={location.pathname.startsWith('/settings')}
          onClick={() => setMobileOpen(false)}
          sx={{ borderRadius: 2 }}
        >
          <ListItemIcon sx={{ color: 'grey.400', minWidth: 40 }}>
            <SettingsIcon />
          </ListItemIcon>
          <ListItemText primary="Settings" />
        </ListItemButton>
      </List>
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
              : nav.find((n) => location.pathname.startsWith(n.to))?.label ?? 'Waddle'}
          </Typography>
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
