import { alpha, createTheme } from '@mui/material/styles';

const lightPrimary = '#4e5df8';
/** Lighter primary for dark surfaces — default #4e5df8 fails contrast on #12131a / #1a1c26. */
const darkPrimary = '#a8b4ff';
const darkPrimaryHover = '#c5ceff';

export function createAppTheme(mode: 'light' | 'dark') {
  const isDark = mode === 'dark';

  return createTheme({
    palette: {
      mode,
      primary: isDark
        ? {
            main: darkPrimary,
            light: darkPrimaryHover,
            dark: '#7d8ef5',
            contrastText: '#0f1118',
          }
        : { main: lightPrimary },
      ...(isDark
        ? {
            background: { default: '#12131a', paper: '#1a1c26' },
            text: {
              primary: '#e8e9ef',
              secondary: alpha('#e8e9ef', 0.72),
            },
          }
        : {
            background: { default: '#f4f5f7', paper: '#ffffff' },
          }),
    },
    typography: {
      fontFamily: '"Inter", "Roboto", "Helvetica", "Arial", sans-serif',
    },
    components: {
      MuiCssBaseline: {
        styleOverrides: isDark
          ? {
              a: {
                color: darkPrimary,
                textDecorationColor: alpha(darkPrimary, 0.5),
                '&:visited': { color: darkPrimaryHover },
                '&:hover': { color: darkPrimaryHover },
              },
            }
          : {},
      },
      MuiLink: {
        defaultProps: { underline: 'hover' },
      },
      MuiButton: {
        styleOverrides: {
          root: isDark
            ? {
                '&.MuiButton-textPrimary': {
                  color: darkPrimary,
                },
                '&.MuiButton-textPrimary:hover': {
                  backgroundColor: alpha(darkPrimary, 0.12),
                  color: darkPrimaryHover,
                },
              }
            : {},
        },
      },
      MuiTab: {
        styleOverrides: {
          root: isDark
            ? {
                '&.Mui-selected': {
                  color: darkPrimaryHover,
                },
              }
            : {},
        },
      },
      MuiDrawer: {
        styleOverrides: {
          paper: { backgroundColor: '#1a1c2c', color: '#e8e9ef' },
        },
      },
    },
  });
}
