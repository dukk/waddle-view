import FavoriteIcon from '@mui/icons-material/Favorite';
import GridViewIcon from '@mui/icons-material/GridView';
import PetsIcon from '@mui/icons-material/Pets';
import WaterDropIcon from '@mui/icons-material/WaterDrop';
import { Stack, Typography } from '@mui/material';
import { OverlayEnumCheckboxGroup } from './OverlayEnumCheckboxGroup';

const SHAPE_OPTIONS = [
  { value: 'heart', label: 'Hearts', icon: FavoriteIcon },
  { value: 'raindrop', label: 'Raindrops', icon: WaterDropIcon },
  { value: 'cat', label: 'Cats', icon: PetsIcon },
  { value: 'dog', label: 'Dogs', icon: PetsIcon },
  { value: 'mix', label: 'Mix (all shapes)', icon: GridViewIcon },
] as const;

const DEFAULT_SHAPES = ['heart', 'mix'];

function readShapes(form: Record<string, unknown>): string[] {
  const raw = form.shapes;
  if (!Array.isArray(raw)) {
    return [...DEFAULT_SHAPES];
  }
  const out = raw.filter((v): v is string => typeof v === 'string' && v.trim().length > 0);
  return out.length > 0 ? out : [...DEFAULT_SHAPES];
}

type Props = {
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
};

export function ShapeRainConfigForm({ formData, onChange, disabled }: Props) {
  const shapes = readShapes(formData);

  return (
    <Stack spacing={2}>
      <Typography variant="subtitle2">Configuration</Typography>
      <OverlayEnumCheckboxGroup
        label="Shapes"
        helperText="Theme accent colors tint the drifting glyphs."
        options={[...SHAPE_OPTIONS]}
        value={shapes}
        disabled={disabled}
        onChange={(next) => onChange({ shapes: next })}
      />
    </Stack>
  );
}
