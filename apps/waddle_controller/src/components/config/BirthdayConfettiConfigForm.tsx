import CropSquareIcon from '@mui/icons-material/CropSquare';
import GridViewIcon from '@mui/icons-material/GridView';
import StarIcon from '@mui/icons-material/Star';
import WavesIcon from '@mui/icons-material/Waves';
import { Stack, Typography } from '@mui/material';
import { CuratorSliderField } from '@/components/CuratorSliderField';
import { OverlayEnumCheckboxGroup } from './OverlayEnumCheckboxGroup';

const CONFETTI_SHAPE_OPTIONS = [
  { value: 'rect', label: 'Rectangles', icon: CropSquareIcon },
  { value: 'circle', label: 'Circles', icon: CropSquareIcon },
  { value: 'star', label: 'Stars', icon: StarIcon },
  { value: 'streamer', label: 'Streamers', icon: WavesIcon },
  { value: 'mix', label: 'Mix (all shapes)', icon: GridViewIcon },
] as const;

const DEFAULT_SHAPES = ['mix'];

function readShapes(form: Record<string, unknown>): string[] {
  const raw = form.shapes;
  if (!Array.isArray(raw)) {
    return [...DEFAULT_SHAPES];
  }
  const out = raw.filter((v): v is string => typeof v === 'string' && v.trim().length > 0);
  return out.length > 0 ? out : [...DEFAULT_SHAPES];
}

function readNumber(form: Record<string, unknown>, key: string, fallback: number): number {
  const v = form[key];
  return typeof v === 'number' && Number.isFinite(v) ? v : fallback;
}

type Props = {
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
};

export function BirthdayConfettiConfigForm({ formData, onChange, disabled }: Props) {
  const patch = (partial: Record<string, unknown>) => onChange({ ...formData, ...partial });

  return (
    <Stack spacing={2}>
      <Typography variant="subtitle2">Configuration</Typography>
      <OverlayEnumCheckboxGroup
        label="Confetti shapes"
        options={[...CONFETTI_SHAPE_OPTIONS]}
        value={readShapes(formData)}
        disabled={disabled}
        onChange={(shapes) => patch({ shapes })}
      />
      <CuratorSliderField
        label="Density"
        value={readNumber(formData, 'density', 0.36)}
        onChange={(density) => patch({ density })}
        min={0.15}
        max={0.9}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
      <CuratorSliderField
        label="Fall speed"
        value={readNumber(formData, 'fall_speed', 0.14)}
        onChange={(fall_speed) => patch({ fall_speed })}
        min={0.02}
        max={1.8}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
      <CuratorSliderField
        label="Opacity"
        value={readNumber(formData, 'opacity', 0.46)}
        onChange={(opacity) => patch({ opacity })}
        min={0.12}
        max={0.72}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
    </Stack>
  );
}
