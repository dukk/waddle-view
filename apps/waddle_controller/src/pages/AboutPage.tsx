import { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Link,
  Stack,
  Tab,
  Tabs,
  Typography,
} from '@mui/material';
import {
  fetchDisplayAbout,
  type DisplayAboutPayload,
  type DisplayAboutResult,
} from '@/api/displayAbout';
import { DependencyTable } from '@/components/about/DependencyTable';
import { LicenseNoticesPanel } from '@/components/about/LicenseNoticesPanel';
import { useControllerAbout } from '@/hooks/useControllerAbout';
import { useDisplay } from '@/context/DisplayContext';
import {
  fetchDisplayHealth,
  formatDisplayHostSummary,
  type DisplayReachability,
} from '@/util/displayHealth';

function VersionLine({ label, version, build }: { label: string; version: string; build: string }) {
  return (
    <Typography variant="body1">
      <Typography component="span" variant="subtitle2" sx={{
        color: "text.secondary"
      }}>
        {label}:{' '}
      </Typography>
      <Typography component="span" sx={{ fontFamily: 'monospace' }}>
        {version}+{build}
      </Typography>
    </Typography>
  );
}

function ProductLicenseBlock({
  license,
}: {
  license: { id: string; name: string; url: string; summary: string };
}) {
  return (
    <Box>
      <Typography variant="subtitle1" gutterBottom sx={{
        fontWeight: 600
      }}>
        Product license
      </Typography>
      <Typography variant="body2" gutterBottom>
        <strong>{license.name}</strong> ({license.id})
      </Typography>
      <Typography
        variant="body2"
        sx={{
          color: "text.secondary",
          whiteSpace: 'pre-wrap',
          mb: 1
        }}>
        {license.summary}
      </Typography>
      <Link href={license.url} target="_blank" rel="noopener noreferrer">
        View full license text
      </Link>
      <Typography
        variant="caption"
        sx={{
          color: "text.secondary",
          display: "block",
          mt: 1
        }}>
        Third-party open-source components remain under their original licenses (see notices
        below).
      </Typography>
    </Box>
  );
}

export function AboutPage() {
  const { active } = useDisplay();
  const { about: controllerAbout, loading: controllerLoading, error: controllerError, reload } =
    useControllerAbout();

  const [depTab, setDepTab] = useState(0);
  const [displayHealth, setDisplayHealth] = useState<DisplayReachability | null>(null);
  const [displayAbout, setDisplayAbout] = useState<DisplayAboutResult | null>(null);
  const [displayLoading, setDisplayLoading] = useState(false);

  const loadDisplay = useCallback(async () => {
    if (!active) {
      setDisplayHealth(null);
      setDisplayAbout(null);
      return;
    }
    setDisplayLoading(true);
    const [health, aboutResult] = await Promise.all([
      fetchDisplayHealth(active),
      fetchDisplayAbout(active),
    ]);
    setDisplayHealth(health);
    setDisplayAbout(aboutResult);
    setDisplayLoading(false);
  }, [active]);

  useEffect(() => {
    void loadDisplay();
  }, [loadDisplay]);

  const displayVersionFromHealth =
    displayHealth?.state === 'online'
      ? {
          version: displayHealth.health.version ?? '—',
          build: displayHealth.health.build ?? '—',
        }
      : null;

  const displayAboutOk =
    displayAbout?.state === 'ok' ? (displayAbout.about as DisplayAboutPayload) : null;

  return (
    <Stack spacing={3} sx={{ maxWidth: 960 }}>
      <Typography variant="h5" sx={{
        fontWeight: 600
      }}>
        About
      </Typography>
      <Typography variant="body2" sx={{
        color: "text.secondary"
      }}>
        Version and license information for the controller you are connected to and the display
        selected in the header.
      </Typography>
      <Box>
        <Typography variant="h6" gutterBottom sx={{
          fontWeight: 600
        }}>
          Controller
        </Typography>
        {controllerLoading && !controllerAbout ? (
          <CircularProgress size={24} />
        ) : controllerError ? (
          <Alert severity="error">{controllerError}</Alert>
        ) : controllerAbout ? (
          <Stack spacing={1}>
            <VersionLine
              label="Build"
              version={controllerAbout.version}
              build={controllerAbout.build}
            />
            <Button size="small" variant="outlined" onClick={() => void reload()} sx={{ alignSelf: 'flex-start' }}>
              Refresh controller info
            </Button>
          </Stack>
        ) : null}
      </Box>
      <Box>
        <Typography variant="h6" gutterBottom sx={{
          fontWeight: 600
        }}>
          Active display
        </Typography>
        {!active ? (
          <Typography variant="body2" sx={{
            color: "text.secondary"
          }}>
            Select a display in the header to see its version and licenses.
          </Typography>
        ) : (
          <Stack spacing={1}>
            <Typography variant="body2">
              <strong>{active.label}</strong>
              <Typography
                component="span"
                variant="body2"
                sx={{
                  color: "text.secondary",
                  ml: 1
                }}>
                {active.baseUrl}
              </Typography>
            </Typography>
            {displayLoading ? (
              <CircularProgress size={24} />
            ) : (
              <>
                {displayHealth?.state === 'online' && (
                  <Typography variant="body2" sx={{
                    color: "text.secondary"
                  }}>
                    {formatDisplayHostSummary(displayHealth.health)}
                  </Typography>
                )}
                {displayHealth?.state === 'offline' && (
                  <Alert severity="warning">{displayHealth.message}</Alert>
                )}
                {displayAbout?.state === 'unsupported' && displayVersionFromHealth && (
                  <>
                    <VersionLine
                      label="Build (from health)"
                      version={displayVersionFromHealth.version}
                      build={displayVersionFromHealth.build}
                    />
                    <Alert severity="info">{displayAbout.message}</Alert>
                  </>
                )}
                {displayAbout?.state === 'offline' && (
                  <Alert severity="warning">{displayAbout.message}</Alert>
                )}
                {displayAboutOk && (
                  <VersionLine
                    label="Build"
                    version={displayAboutOk.version}
                    build={displayAboutOk.build}
                  />
                )}
                <Button
                  size="small"
                  variant="outlined"
                  onClick={() => void loadDisplay()}
                  sx={{ alignSelf: 'flex-start' }}
                >
                  Refresh display info
                </Button>
              </>
            )}
          </Stack>
        )}
      </Box>
      {(() => {
        const license = displayAboutOk?.product_license ?? controllerAbout?.productLicense;
        return license ? <ProductLicenseBlock license={license} /> : null;
      })()}
      <Box>
        <Tabs value={depTab} onChange={(_, v) => setDepTab(v)} sx={{ mb: 2 }}>
          <Tab label="Controller dependencies" />
          <Tab label="Display dependencies" disabled={!displayAboutOk} />
        </Tabs>
        {depTab === 0 && controllerAbout && (
          <DependencyTable
            title="Controller npm packages"
            rows={controllerAbout.dependencies}
            emptyMessage="No dependency metadata in the controller manifest."
          />
        )}
        {depTab === 1 && displayAboutOk && (
          <DependencyTable
            title="Display Dart packages"
            rows={displayAboutOk.dependencies.map((d) => ({
              name: d.name,
              version: d.version,
              license: d.license,
            }))}
          />
        )}
      </Box>
      <Box>
        <Typography variant="h6" gutterBottom sx={{
          fontWeight: 600
        }}>
          Open source notices
        </Typography>
        <Stack spacing={1}>
          {controllerAbout && (
            <LicenseNoticesPanel
              title="Controller third-party notices"
              text={controllerAbout.thirdPartyNotices}
            />
          )}
          {displayAboutOk && (
            <LicenseNoticesPanel
              title="Display third-party licenses"
              text={displayAboutOk.third_party_licenses}
              defaultExpanded
            />
          )}
        </Stack>
      </Box>
    </Stack>
  );
}
