import { useCallback, useState } from 'react';
import {
  Alert,
  Box,
  Breadcrumbs,
  Button,
  CircularProgress,
  FormControl,
  IconButton,
  InputLabel,
  Link,
  MenuItem,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import FolderOpenIcon from '@mui/icons-material/FolderOpen';
import { fetchMicrosoftGraphDriveChildren } from '@/api/microsoftGraphDriveChildren';
import { ApiError } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import type { IntegrationAccountRow } from '@/util/integrationAccounts';
import { DISPLAY_SETTINGS_ACCOUNTS_LABEL } from '@/constants/displaySettingsTabs';
import {
  CategoryMultiSelect,
  type ContentCategoryOption,
} from '@/components/CategoryMultiSelect';
import {
  isWindowsLocalOneDrivePath,
  newOneDriveAccountBlock,
  newOneDriveSourceId,
  type OneDriveAccountState,
  type OneDriveConfigState,
  type OneDriveSourceState,
} from '@/util/onedriveConfig';

type Props = {
  display: SavedDisplay;
  value: OneDriveConfigState;
  onChange: (next: OneDriveConfigState) => void;
  microsoftAccounts: IntegrationAccountRow[];
  categories: ContentCategoryOption[];
  mediaKind: 'photo' | 'video';
  disabled?: boolean;
};

function errMsg(e: unknown): string {
  return e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
}

function pathSegments(path: string): { label: string; path: string }[] {
  const trimmed = path.trim().replace(/^\/+/, '');
  const crumbs: { label: string; path: string }[] = [
    { label: 'OneDrive', path: '' },
  ];
  if (!trimmed) return crumbs;
  let acc = '';
  for (const part of trimmed.split('/').filter(Boolean)) {
    acc = acc ? `${acc}/${part}` : part;
    crumbs.push({ label: part, path: `/${acc}` });
  }
  return crumbs;
}

export function OneDriveConfigSection({
  display,
  value,
  onChange,
  microsoftAccounts,
  categories,
  mediaKind,
  disabled = false,
}: Props) {
  const configuredAccounts = microsoftAccounts.filter((a) => a.configured);
  const [browseAccountKey, setBrowseAccountKey] = useState('');
  const [browsePath, setBrowsePath] = useState('');
  const [foldersLoading, setFoldersLoading] = useState(false);
  const [foldersError, setFoldersError] = useState<string | null>(null);
  const [folderRows, setFolderRows] = useState<
    { id: string; name: string; path: string }[]
  >([]);

  const patch = (partial: Partial<OneDriveConfigState>) => {
    onChange({ ...value, ...partial });
  };

  const patchAccount = (index: number, partial: Partial<OneDriveAccountState>) => {
    onChange({
      ...value,
      accounts: value.accounts.map((a, i) => (i === index ? { ...a, ...partial } : a)),
    });
  };

  const patchSource = (
    accountIndex: number,
    sourceId: string,
    partial: Partial<OneDriveSourceState>,
  ) => {
    const account = value.accounts[accountIndex];
    if (!account) return;
    patchAccount(accountIndex, {
      sources: account.sources.map((s) =>
        s.sourceId === sourceId ? { ...s, ...partial } : s,
      ),
    });
  };

  const loadFolders = useCallback(
    async (accountKey: string, path: string) => {
      if (!accountKey) {
        setFolderRows([]);
        return;
      }
      setFoldersLoading(true);
      setFoldersError(null);
      try {
        const items = await fetchMicrosoftGraphDriveChildren(display, accountKey, path);
        setFolderRows(
          items.filter((i) => i.folder).map((i) => ({ id: i.id, name: i.name, path: i.path })),
        );
      } catch (e) {
        setFoldersError(errMsg(e));
        setFolderRows([]);
      } finally {
        setFoldersLoading(false);
      }
    },
    [display],
  );

  const addAccount = () => {
    onChange({
      ...value,
      accounts: [...value.accounts, newOneDriveAccountBlock()],
    });
  };

  const removeAccount = (index: number) => {
    onChange({
      ...value,
      accounts: value.accounts.filter((_, i) => i !== index),
    });
  };

  const mediaLabel = mediaKind === 'photo' ? 'photos' : 'videos';
  const mimeHint =
    mediaKind === 'photo'
      ? 'JPEG, PNG, WebP, GIF, and HEIC/HEIF'
      : 'MP4 and QuickTime (MOV)';
  const windowsPathSources = value.accounts.flatMap((a) =>
    a.sources.filter((s) => isWindowsLocalOneDrivePath(s.path)),
  );

  return (
    <Stack spacing={2}>
      <Typography variant="subtitle2">
        OneDrive folder sources ({mediaLabel})
      </Typography>
      <Typography variant="body2" color="text.secondary">
        Browse folders per Microsoft account (paths like <code>/Pictures/MyAlbum</code>, not{' '}
        <code>C:\Users\...\OneDrive\...</code>). Supported {mediaLabel}: {mimeHint}. To sync both
        photos and videos from the same folders, enable and configure both OneDrive integrations.
      </Typography>
      {windowsPathSources.length > 0 ? (
        <Alert severity="warning">
          Remove folder sources that use a Windows local path. Use Browse folders so paths match
          OneDrive in the cloud (for example <code>/Pictures/Family Pictures/...</code>).
        </Alert>
      ) : null}
      {configuredAccounts.length === 0 ? (
        <Alert severity="info">
          Add a Microsoft account under <strong>{DISPLAY_SETTINGS_ACCOUNTS_LABEL}</strong>,
          complete sign-in on the display, then return here.
        </Alert>
      ) : null}
      <TextField
        label="Max downloads per sync"
        type="number"
        size="small"
        fullWidth
        disabled={disabled}
        value={value.globalPerPollLimit}
        onChange={(e) =>
          patch({ globalPerPollLimit: Math.max(1, Number(e.target.value) || 50) })
        }
        inputProps={{ min: 1 }}
        helperText="Total new files downloaded per collect across all accounts and folders."
      />
      <Box sx={{ border: 1, borderColor: 'divider', borderRadius: 1, p: 2 }}>
        <Stack spacing={1.5}>
          <Typography variant="body2" fontWeight={600}>
            Browse folders
          </Typography>
          <FormControl fullWidth size="small" disabled={disabled}>
            <InputLabel id="onedrive-browse-account">Microsoft account</InputLabel>
            <Select
              labelId="onedrive-browse-account"
              label="Microsoft account"
              value={browseAccountKey}
              onChange={(e) => {
                const key = e.target.value;
                setBrowseAccountKey(key);
                setBrowsePath('');
                void loadFolders(key, '');
              }}
            >
              {configuredAccounts.map((a) => (
                <MenuItem key={a.id} value={a.id}>
                  {a.label}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          {browseAccountKey ? (
            <>
              <Breadcrumbs aria-label="OneDrive path">
                {pathSegments(browsePath).map((crumb) => (
                  <Link
                    key={crumb.path || 'root'}
                    component="button"
                    type="button"
                    underline="hover"
                    color="inherit"
                    onClick={() => {
                      setBrowsePath(crumb.path);
                      void loadFolders(browseAccountKey, crumb.path);
                    }}
                  >
                    {crumb.label}
                  </Link>
                ))}
              </Breadcrumbs>
              {foldersError ? <Alert severity="error">{foldersError}</Alert> : null}
              {foldersLoading ? (
                <Stack direction="row" spacing={1} alignItems="center">
                  <CircularProgress size={20} />
                  <Typography variant="body2" color="text.secondary">
                    Loading folders…
                  </Typography>
                </Stack>
              ) : (
                <Stack spacing={0.5}>
                  {folderRows.length === 0 ? (
                    <Typography variant="body2" color="text.secondary">
                      No subfolders here.
                    </Typography>
                  ) : (
                    folderRows.map((f) => (
                      <Stack key={f.id} direction="row" spacing={1} alignItems="center">
                        <Button
                          size="small"
                          startIcon={<FolderOpenIcon />}
                          onClick={() => {
                            setBrowsePath(f.path);
                            void loadFolders(browseAccountKey, f.path);
                          }}
                          disabled={disabled}
                        >
                          {f.name}
                        </Button>
                      </Stack>
                    ))
                  )}
                </Stack>
              )}
              <Button
                variant="outlined"
                size="small"
                disabled={disabled || !browseAccountKey}
                onClick={() => {
                  let accounts = [...value.accounts];
                  let idx = accounts.findIndex((a) => a.graphAccountKey === browseAccountKey);
                  if (idx < 0) {
                    accounts = [
                      ...accounts,
                      { graphAccountKey: browseAccountKey, sources: [] },
                    ];
                    idx = accounts.length - 1;
                  }
                  const account = accounts[idx];
                  if (!account) return;
                  const normalized = browsePath.trim();
                  if (account.sources.some((s) => s.path === normalized)) return;
                  const label =
                    normalized === ''
                      ? 'Drive root'
                      : (normalized.split('/').filter(Boolean).pop() ?? normalized);
                  accounts[idx] = {
                    ...account,
                    sources: [
                      ...account.sources,
                      {
                        sourceId: newOneDriveSourceId(),
                        folderLabel: label,
                        path: normalized,
                        categoryIds: categories[0]?.id ? [categories[0].id] : [],
                        maxFiles: 50,
                      },
                    ],
                  };
                  onChange({ ...value, accounts });
                }}
              >
                Add current folder as source
              </Button>
            </>
          ) : null}
        </Stack>
      </Box>
      {value.accounts.map((account, accountIndex) => (
        <Box
          key={`${account.graphAccountKey}-${accountIndex}`}
          sx={{ border: 1, borderColor: 'divider', borderRadius: 1, p: 2 }}
        >
          <Stack spacing={1.5}>
            <Stack direction="row" alignItems="center" justifyContent="space-between">
              <Typography variant="body2" fontWeight={600}>
                Account {accountIndex + 1}
              </Typography>
              <IconButton
                size="small"
                aria-label="Remove account"
                disabled={disabled}
                onClick={() => removeAccount(accountIndex)}
              >
                <DeleteOutlineIcon fontSize="small" />
              </IconButton>
            </Stack>
            <FormControl fullWidth size="small" disabled={disabled}>
              <InputLabel id={`onedrive-acct-${accountIndex}`}>Microsoft account</InputLabel>
              <Select
                labelId={`onedrive-acct-${accountIndex}`}
                label="Microsoft account"
                value={account.graphAccountKey}
                onChange={(e) => patchAccount(accountIndex, { graphAccountKey: e.target.value })}
              >
                {configuredAccounts.map((a) => (
                  <MenuItem key={a.id} value={a.id}>
                    {a.label}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
            {account.sources.map((source) => (
              <Box
                key={source.sourceId}
                sx={{
                  border: 1,
                  borderColor: 'divider',
                  borderRadius: 1,
                  p: 1.5,
                  bgcolor: 'action.hover',
                }}
              >
                <Stack spacing={1}>
                  <Stack direction="row" justifyContent="space-between" alignItems="center">
                    <Typography variant="body2" fontWeight={600}>
                      {source.folderLabel || source.path || 'Folder'}
                    </Typography>
                    <IconButton
                      size="small"
                      aria-label="Remove folder source"
                      disabled={disabled}
                      onClick={() =>
                        patchAccount(accountIndex, {
                          sources: account.sources.filter(
                            (s) => s.sourceId !== source.sourceId,
                          ),
                        })
                      }
                    >
                      <DeleteOutlineIcon fontSize="small" />
                    </IconButton>
                  </Stack>
                  <Typography variant="caption" color="text.secondary">
                    Path: {source.path.trim() === '' ? '(drive root)' : source.path}
                  </Typography>
                  <CategoryMultiSelect
                    id={`onedrive-cat-${source.sourceId}`}
                    label="Categories"
                    value={source.categoryIds}
                    onChange={(categoryIds) =>
                      patchSource(accountIndex, source.sourceId, { categoryIds })
                    }
                    categories={categories}
                    disabled={disabled}
                  />
                  <TextField
                    label="Max files kept (retention)"
                    type="number"
                    size="small"
                    fullWidth
                    disabled={disabled}
                    value={source.maxFiles}
                    onChange={(e) =>
                      patchSource(accountIndex, source.sourceId, {
                        maxFiles: Math.max(1, Number(e.target.value) || 50),
                      })
                    }
                    inputProps={{ min: 1 }}
                  />
                </Stack>
              </Box>
            ))}
          </Stack>
        </Box>
      ))}
      <Button variant="outlined" size="small" disabled={disabled} onClick={addAccount}>
        Add Microsoft account
      </Button>
    </Stack>
  );
}
