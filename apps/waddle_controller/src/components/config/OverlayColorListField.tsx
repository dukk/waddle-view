import AddIcon from '@mui/icons-material/Add';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import {
  Button,
  IconButton,
  Stack,
  TextField,
  Typography,
} from '@mui/material';

const HEX_PATTERN = /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/;

function normalizeHex(raw: string, fallback: string): string {
  const trimmed = raw.trim();
  return HEX_PATTERN.test(trimmed) ? trimmed : fallback;
}

function readColors(form: Record<string, unknown>): string[] {
  const raw = form.colors;
  if (!Array.isArray(raw)) {
    return [];
  }
  return raw
    .filter((e): e is string => typeof e === 'string')
    .map((e) => e.trim())
    .filter((e) => HEX_PATTERN.test(e));
}

type Props = {
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
  defaultColor?: string;
};

export function OverlayColorListField({
  formData,
  onChange,
  disabled,
  defaultColor = '#E53935',
}: Props) {
  const colors = readColors(formData);

  const patchColors = (next: string[]) => onChange({ ...formData, colors: next });

  return (
    <Stack spacing={1}>
      <Typography variant="body2" color="text.secondary">
        Balloon fill colors are chosen at random. Each balloon in a cluster gets a
        distinct color when the palette has enough entries.
      </Typography>
      {colors.map((hex, index) => (
        <Stack key={`${index}-${hex}`} direction="row" spacing={1} alignItems="center">
          <TextField
            type="color"
            value={hex.length === 9 ? hex.slice(0, 7) : hex}
            onChange={(e) => {
              const next = [...colors];
              next[index] = normalizeHex(e.target.value, defaultColor);
              patchColors(next);
            }}
            disabled={disabled}
            slotProps={{ input: { sx: { width: 56, height: 40, p: 0.5 } } }}
          />
          <TextField
            label="Hex"
            value={hex}
            onChange={(e) => {
              const next = [...colors];
              next[index] = e.target.value.trim();
              patchColors(next);
            }}
            disabled={disabled}
            size="small"
            sx={{ flex: 1 }}
          />
          <IconButton
            aria-label="Remove color"
            onClick={() => patchColors(colors.filter((_, i) => i !== index))}
            disabled={disabled}
            size="small"
          >
            <DeleteOutlineIcon fontSize="small" />
          </IconButton>
        </Stack>
      ))}
      <Button
        startIcon={<AddIcon />}
        onClick={() => patchColors([...colors, defaultColor])}
        disabled={disabled}
        size="small"
        sx={{ alignSelf: 'flex-start' }}
      >
        Add color
      </Button>
    </Stack>
  );
}
