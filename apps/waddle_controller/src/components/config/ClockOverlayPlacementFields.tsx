import { Stack, Typography } from '@mui/material';
import { CuratorSliderField } from '@/components/CuratorSliderField';
import {
  CLOCK_OVERLAY_SCALE_DEFAULT,
  CLOCK_OVERLAY_SCALE_MAX,
  CLOCK_OVERLAY_SCALE_MIN,
  readClockOverlayPlacement,
} from '@/constants/clockOverlaySettings';

type Props = {
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
  scaleHelp?: string;
};

export function ClockOverlayPlacementFields({
  formData,
  onChange,
  disabled,
  scaleHelp = 'Clock size as a fraction of the viewport shortest side.',
}: Props) {
  const placement = readClockOverlayPlacement(formData);
  const x = placement.x;
  const y = placement.y;
  const scale = placement.scale;
  const opacity = placement.opacity ?? 1;

  const patch = (partial: Record<string, unknown>) => {
    onChange({ ...formData, ...partial });
  };

  return (
    <Stack spacing={2}>
      <CuratorSliderField
        label="Horizontal position"
        value={x}
        onChange={(next) => patch({ x: next })}
        min={0}
        max={1}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => `${Math.round(v * 100)}%`}
      />
      <Typography
        variant="caption"
        sx={{
          color: "text.secondary",
          mt: -1.5,
          display: 'block'
        }}>
        0% = left edge; 100% = right edge (clock anchors at top-left).
      </Typography>
      <CuratorSliderField
        label="Vertical position"
        value={y}
        onChange={(next) => patch({ y: next })}
        min={0}
        max={1}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => `${Math.round(v * 100)}%`}
      />
      <CuratorSliderField
        label="Scale"
        value={scale}
        onChange={(next) => patch({ scale: next })}
        min={CLOCK_OVERLAY_SCALE_MIN}
        max={CLOCK_OVERLAY_SCALE_MAX}
        step={0.01}
        disabled={disabled}
        formatValue={(v) => v.toFixed(2)}
      />
      <Typography
        variant="caption"
        sx={{
          color: "text.secondary",
          mt: -1.5,
          display: 'block'
        }}>
        {scaleHelp} ({CLOCK_OVERLAY_SCALE_MIN}–{CLOCK_OVERLAY_SCALE_MAX}; default{' '}
        {CLOCK_OVERLAY_SCALE_DEFAULT}).
      </Typography>
      <CuratorSliderField
        label="Opacity"
        value={opacity}
        onChange={(next) => patch({ opacity: next >= 1 ? undefined : next })}
        min={0}
        max={1}
        step={0.05}
        disabled={disabled}
        formatValue={(v) => `${Math.round(v * 100)}%`}
      />
    </Stack>
  );
}
