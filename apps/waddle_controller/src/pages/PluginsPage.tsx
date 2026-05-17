import { useCallback, useEffect, useState } from 'react';
import {
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
import { CatalogPageToolbar } from '@/components/CatalogPageToolbar';
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
  const { activeDisplay } = useDisplay();
  const [items, setItems] = useState<PluginRow[]>([]);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!activeDisplay) {
      return;
    }
    try {
      const data = await apiJson<{ items: PluginRow[] }>('/v1/plugins');
      setItems(data.items ?? []);
      setError(null);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : String(e));
    }
  }, [activeDisplay]);

  const refresh = useDisplayRefresh(load);

  useEffect(() => {
    void load();
  }, [load]);

  if (!activeDisplay) {
    return <NoDisplayPlaceholder />;
  }

  return (
    <Box>
      <CatalogPageToolbar
        title="Plugins"
        icon={<ExtensionIcon />}
        actions={<DisplayRefreshIndicator refresh={refresh} />}
      />
      {error ? (
        <Typography color="error" sx={{ mb: 2 }}>
          {error}
        </Typography>
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
    </Box>
  );
}
