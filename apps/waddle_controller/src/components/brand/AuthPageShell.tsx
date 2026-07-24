import { alpha, Box, Paper, Stack, Typography } from '@mui/material';
import type { ReactNode } from 'react';
import { WaddleBrandMark } from '@/components/brand/WaddleBrandMark';

type Props = {
  title: string;
  subtitle?: ReactNode;
  children: ReactNode;
  maxWidth?: number;
};

export function AuthPageShell({ title, subtitle, children, maxWidth = 440 }: Props) {
  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        p: 3,
        background: (theme) =>
          `linear-gradient(165deg, ${alpha(theme.palette.primary.main, theme.palette.mode === 'dark' ? 0.14 : 0.08)} 0%, ${theme.palette.background.default} 55%)`,
      }}
    >
      <WaddleBrandMark variant="mascot" size="lg" sx={{ mb: 2 }} />
      <Paper
        elevation={2}
        sx={{
          width: '100%',
          maxWidth,
          p: { xs: 2.5, sm: 3 },
        }}
      >
        <Stack spacing={2.5}>
          <Stack direction="row" spacing={1.5} sx={{
            alignItems: "center"
          }}>
            <WaddleBrandMark variant="headshot" size="sm" />
            <Box sx={{ minWidth: 0 }}>
              <Typography variant="h5" sx={{
                fontWeight: 600
              }}>
                {title}
              </Typography>
              {subtitle != null && (
                <Typography
                  variant="body2"
                  sx={{
                    color: "text.secondary",
                    mt: 0.5
                  }}>
                  {subtitle}
                </Typography>
              )}
            </Box>
          </Stack>
          {children}
        </Stack>
      </Paper>
    </Box>
  );
}
