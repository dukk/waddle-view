import { createTheme } from '@mui/material/styles';

export function createAppTheme(mode: 'light' | 'dark') {
  return createTheme({
    palette: {
      mode,
      primary: { main: '#4e5df8' },
      ...(mode === 'light'
        ? {
            background: { default: '#f4f5f7', paper: '#ffffff' },
          }
        : {
            background: { default: '#12131a', paper: '#1a1c26' },
          }),
    },
    typography: {
      fontFamily: '"Inter", "Roboto", "Helvetica", "Arial", sans-serif',
    },
    components: {
      MuiDrawer: {
        styleOverrides: {
          paper: { backgroundColor: '#1a1c2c', color: '#e8e9ef' },
        },
      },
    },
  });
}
