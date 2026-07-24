import {
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { CategoryMultiSelect, type ContentCategoryOption } from '@/components/CategoryMultiSelect';
import { CuratorSliderField } from '@/components/CuratorSliderField';
import { DurationInputField } from '@/components/DurationInputField';
import {
  STATIC_IMAGE_OVERLAY_SCALE_MAX,
  STATIC_IMAGE_OVERLAY_SCALE_MIN,
} from '@/constants/staticImageOverlaySettings';

const ASPECT_OPTIONS = [
  { value: 'any', label: 'Any aspect ratio' },
  { value: 'landscape', label: 'Landscape' },
  { value: 'portrait', label: 'Portrait' },
  { value: 'square', label: 'Square' },
  { value: 'widescreen', label: 'Widescreen (~16:9)' },
  { value: 'standard_4_3', label: 'Standard (~4:3)' },
] as const;

type Props = {
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  categories: ContentCategoryOption[];
  disabled?: boolean;
};

function readNumber(raw: unknown, fallback: number): number {
  return typeof raw === 'number' && Number.isFinite(raw) ? raw : fallback;
}

function readOptionalInt(raw: unknown): number | undefined {
  if (raw === undefined || raw === null || raw === '') return undefined;
  const n = typeof raw === 'number' ? raw : Number.parseInt(String(raw), 10);
  return Number.isFinite(n) && n > 0 ? n : undefined;
}

function readCategoryIds(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  return raw.filter((id): id is string => typeof id === 'string' && id.trim().length > 0);
}

export function PhotoSlideshowOverlayConfigForm({
  formData,
  onChange,
  categories,
  disabled,
}: Props) {
  const x = readNumber(formData.x, 0.05);
  const y = readNumber(formData.y, 0.05);
  const scale = readNumber(formData.scale, 0.12);
  const opacity =
    typeof formData.opacity === 'number' && formData.opacity < 1 ? formData.opacity : 1;
  const intervalSec = readNumber(formData.interval_sec, 60);
  const categoryIds = readCategoryIds(formData.category_ids);
  const aspectRatio =
    typeof formData.aspect_ratio === 'string' && formData.aspect_ratio.trim()
      ? formData.aspect_ratio.trim()
      : 'any';

  const patch = (partial: Record<string, unknown>) => {
    onChange({ ...formData, ...partial });
  };

  return (
    <Stack spacing={2}>
      <Typography variant="body2" sx={{
        color: "text.secondary"
      }}>
        Cycles random photos from the catalog at a viewport position. Assign on a curator
        configuration Overlay tab; respects the global overlay kill-switch.
      </Typography>
      <DurationInputField
        label="Cycle interval"
        valueSeconds={intervalSec}
        onChange={(interval_sec) => patch({ interval_sec })}
        allowedUnits={['sec', 'min', 'hr']}
        minSeconds={5}
        maxSeconds={3600}
        disabled={disabled}
        helperText="Time between random photo picks."
      />
      <CategoryMultiSelect
        id="photo-slideshow-categories"
        label="Photo categories"
        value={categoryIds}
        onChange={(ids) => patch({ category_ids: ids.length > 0 ? ids : undefined })}
        categories={categories}
        disabled={disabled}
      />
      <Typography
        variant="caption"
        sx={{
          color: "text.secondary",
          mt: -1
        }}>
        Leave empty to include all non-suppressed photos.
      </Typography>
      <FormControl fullWidth size="small" disabled={disabled}>
        <InputLabel id="photo-slideshow-aspect-label">Aspect ratio</InputLabel>
        <Select
          labelId="photo-slideshow-aspect-label"
          label="Aspect ratio"
          value={aspectRatio}
          onChange={(e) => {
            const v = String(e.target.value);
            patch({ aspect_ratio: v === 'any' ? undefined : v });
          }}
        >
          {ASPECT_OPTIONS.map((opt) => (
            <MenuItem key={opt.value} value={opt.value}>
              {opt.label}
            </MenuItem>
          ))}
        </Select>
      </FormControl>
      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
        <TextField
          label="Min width (px)"
          type="number"
          size="small"
          fullWidth
          disabled={disabled}
          value={readOptionalInt(formData.min_width) ?? ''}
          onChange={(e) => patch({ min_width: readOptionalInt(e.target.value) })}
        />
        <TextField
          label="Max width (px)"
          type="number"
          size="small"
          fullWidth
          disabled={disabled}
          value={readOptionalInt(formData.max_width) ?? ''}
          onChange={(e) => patch({ max_width: readOptionalInt(e.target.value) })}
        />
      </Stack>
      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
        <TextField
          label="Min height (px)"
          type="number"
          size="small"
          fullWidth
          disabled={disabled}
          value={readOptionalInt(formData.min_height) ?? ''}
          onChange={(e) => patch({ min_height: readOptionalInt(e.target.value) })}
        />
        <TextField
          label="Max height (px)"
          type="number"
          size="small"
          fullWidth
          disabled={disabled}
          value={readOptionalInt(formData.max_height) ?? ''}
          onChange={(e) => patch({ max_height: readOptionalInt(e.target.value) })}
        />
      </Stack>
      <Typography variant="caption" sx={{
        color: "text.secondary"
      }}>
        Dimension filters use blob metadata; photos without width/height are excluded when any
        filter is set.
      </Typography>
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
        min={STATIC_IMAGE_OVERLAY_SCALE_MIN}
        max={STATIC_IMAGE_OVERLAY_SCALE_MAX}
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
        Image width as a fraction of the viewport shortest side (
        {STATIC_IMAGE_OVERLAY_SCALE_MIN}–{STATIC_IMAGE_OVERLAY_SCALE_MAX}).
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
