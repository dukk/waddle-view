import { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Card,
  CardContent,
  Chip,
  Stack,
  Typography,
} from '@mui/material';
import ExtensionIcon from '@mui/icons-material/Extension';
import { useDisplay } from '@/context/DisplayContext';
import { apiJson, ApiError } from '@/api/client';
import { DisplayRefreshIndicator } from '@/components/DisplayRefreshIndicator';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { useDisplayRefresh } from '@/hooks/useDisplayRefresh';

type PluginRow = {
  id: string;
  version: string;
  path: string;
  capabilities: string[];
};

export function PluginsPage() {
  const { active } = useDisplay();
  const { loading, wrapRefresh } = useDisplayRefresh();
  const [items, setItems] = useState<PluginRow[]>([]);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!active) return;
    await wrapRefresh(async () => {
      setError(null);
      try {
        const data = await apiJson<{ items: PluginRow[] }>(active, '/v1/plugins');
        setItems(data.items ?? []);
      } catch (e) {
        setError(e instanceof ApiError ? e.message : String(e));
      }
    });
  }, [active, wrapRefresh]);

  useEffect(() => {
    void load();
  }, [load]);

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  return (
    <Stack spacing={3}>
      <DisplayRefreshIndicator loading={loading} />
      <Box>
        <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 0.5 }}>
          <ExtensionIcon color="action" />
          <Typography variant="h6" fontWeight={600}>
            Plugins
          </Typography>
        </Stack>
        <Typography variant="body2" color="text.secondary">
          Extensions loaded on the active display (see WADDLE_DISPLAY_PLUGINS_DIR).
        </Typography>
      </Box>
      {error ? (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      ) : null}
      <Stack spacing={2}>
        {items.length === 0 ? (
          <Typography color="text.secondary">
            No plugins loaded. Set WADDLE_DISPLAY_PLUGINS_DIR and restart the display.
          </Typography>
        ) : (
          items.map((p) => (
            <Card key={p.id}>
              <CardContent>
                <Typography variant="h6">{p.id}</Typography>
                <Typography variant="body2" color="text.secondary">
                  v{p.version} — {p.path}
                </Typography>
                <Stack direction="row" spacing={1} sx={{ mt: 1 }} flexWrap="wrap">
                  {p.capabilities.map((c) => (
                    <Chip key={c} size="small" label={c} />
                  ))}
                </Stack>
              </CardContent>
            </Card>
          ))
        )}
      </Stack>
    </Stack>
  );
}
