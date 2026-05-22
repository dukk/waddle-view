import { Stack, Typography } from '@mui/material';
import type { ReactNode } from 'react';

type Props = {
  title: string;
  description?: ReactNode;
  children: ReactNode;
};

/** Shared shell for integration enable/edit config blocks (Outlook / OneDrive pattern). */
export function IntegrationConfigSection({ title, description, children }: Props) {
  return (
    <Stack spacing={2}>
      <Typography variant="subtitle2">{title}</Typography>
      {description != null ? (
        <Typography variant="body2" color="text.secondary" component="div">
          {description}
        </Typography>
      ) : null}
      {children}
    </Stack>
  );
}
