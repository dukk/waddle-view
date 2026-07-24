import AddIcon from '@mui/icons-material/Add';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutlined';
import {
  Button,
  FormControl,
  FormControlLabel,
  IconButton,
  Radio,
  RadioGroup,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { useState } from 'react';

import type { DisplayThemePreviewGroups } from '@/constants/displayThemePreview';
import {
  DISPLAY_THEME_CHROME_MAX_STOPS,
  DISPLAY_THEME_CHROME_MIN_STOPS,
} from '@/constants/displayThemes';
import {
  buildDisplayStops,
  CONTAINER_CHROME_GRADIENT_MAX,
  CONTAINER_CHROME_GRADIENT_MIN,
  displayGradientStops,
  displaySolidColor,
  inferDisplayBackgroundMode,
  joinContainerGroup,
  splitContainerGroup,
  type DisplayBackgroundFillMode,
} from '@/util/displayThemeChromeForm';

const HEX_PATTERN = /^#[0-9A-Fa-f]{6}$/;

function normalizeHex(raw: string, fallback: string): string {
  const trimmed = raw.trim();
  if (HEX_PATTERN.test(trimmed)) {
    return trimmed.toUpperCase();
  }
  const withHash = trimmed.startsWith('#') ? trimmed : `#${trimmed}`;
  return HEX_PATTERN.test(withHash) ? withHash.toUpperCase() : fallback;
}

type ColorRowProps = {
  label?: string;
  hex: string;
  fallback: string;
  disabled?: boolean;
  onChange: (hex: string) => void;
  onRemove?: () => void;
  removeDisabled?: boolean;
};

function ColorRow({
  label,
  hex,
  fallback,
  disabled,
  onChange,
  onRemove,
  removeDisabled,
}: ColorRowProps) {
  const colorInput = hex.length >= 7 ? hex.slice(0, 7) : fallback;
  return (
    <Stack direction="row" spacing={1} sx={{
      alignItems: "center"
    }}>
      <TextField
        type="color"
        value={colorInput}
        onChange={(e) => onChange(normalizeHex(e.target.value, fallback))}
        disabled={disabled}
        slotProps={{ input: { sx: { width: 56, height: 40, p: 0.5 } } }}
      />
      <TextField
        label={label ?? 'Hex'}
        value={hex}
        onChange={(e) => onChange(e.target.value.trim())}
        onBlur={() => onChange(normalizeHex(hex, fallback))}
        disabled={disabled}
        size="small"
        sx={{ flex: 1 }}
      />
      {onRemove ? (
        <IconButton
          aria-label="Remove color"
          onClick={onRemove}
          disabled={disabled || removeDisabled}
          size="small"
        >
          <DeleteOutlineIcon fontSize="small" />
        </IconButton>
      ) : null}
    </Stack>
  );
}

type GradientStopsEditorProps = {
  caption: string;
  colors: string[];
  fallback: string;
  minStops: number;
  maxStops: number;
  disabled?: boolean;
  onChange: (colors: string[]) => void;
};

function GradientStopsEditor({
  caption,
  colors,
  fallback,
  minStops,
  maxStops,
  disabled,
  onChange,
}: GradientStopsEditorProps) {
  return (
    <Stack spacing={1}>
      <Typography variant="caption" sx={{
        color: "text.secondary"
      }}>
        {caption}
      </Typography>
      {colors.map((hex, index) => (
        <ColorRow
          key={`grad-${index}-${hex}`}
          label={`Stop ${index + 1}`}
          hex={hex}
          fallback={fallback}
          disabled={disabled}
          onChange={(next) => {
            const copy = [...colors];
            copy[index] = next;
            onChange(copy);
          }}
          onRemove={() => onChange(colors.filter((_, i) => i !== index))}
          removeDisabled={colors.length <= minStops}
        />
      ))}
      <Button
        startIcon={<AddIcon />}
        onClick={() => onChange([...colors, fallback])}
        disabled={disabled || colors.length >= maxStops}
        size="small"
        sx={{ alignSelf: 'flex-start' }}
      >
        Add gradient stop
      </Button>
    </Stack>
  );
}

type Props = {
  preview: DisplayThemePreviewGroups;
  disabled?: boolean;
  onChange: (preview: DisplayThemePreviewGroups) => void;
};

export function DisplayThemeChromeEditor({ preview, disabled, onChange }: Props) {
  const displayFallback = preview.display[0] ?? '#0D1B2A';

  const [displayMode, setDisplayMode] = useState<DisplayBackgroundFillMode>(() =>
    inferDisplayBackgroundMode(preview.display),
  );
  const [displaySolid, setDisplaySolid] = useState(() => displaySolidColor(preview.display));
  const [displayGradient, setDisplayGradient] = useState(() =>
    displayGradientStops(preview.display, inferDisplayBackgroundMode(preview.display)),
  );

  const screen = splitContainerGroup(preview.primaryContainer);
  const ticker = splitContainerGroup(preview.secondaryContainer);

  const patch = (partial: Partial<DisplayThemePreviewGroups>) => {
    onChange({ ...preview, ...partial });
  };

  const applyDisplayBackground = (
    mode: DisplayBackgroundFillMode,
    solid: string,
    gradient: string[],
  ) => {
    patch({ display: buildDisplayStops(mode, solid, gradient) });
  };

  const setDisplayModeAndPersist = (mode: DisplayBackgroundFillMode) => {
    setDisplayMode(mode);
    applyDisplayBackground(
      mode,
      displaySolid,
      mode === 'gradient' ? displayGradient : [displaySolid, displaySolid],
    );
  };

  return (
    <Stack spacing={2.5}>
      <Stack spacing={1}>
        <Typography variant="subtitle2" sx={{
          fontWeight: 600
        }}>
          Display background
        </Typography>
        <FormControl disabled={disabled}>
          <RadioGroup
            row
            value={displayMode}
            onChange={(_, value) =>
              setDisplayModeAndPersist(value as DisplayBackgroundFillMode)
            }
          >
            <FormControlLabel value="solid" control={<Radio size="small" />} label="Solid" />
            <FormControlLabel value="gradient" control={<Radio size="small" />} label="Gradient" />
          </RadioGroup>
        </FormControl>
        {displayMode === 'solid' ? (
          <ColorRow
            label="Background color"
            hex={displaySolid}
            fallback={displayFallback}
            disabled={disabled}
            onChange={(hex) => {
              setDisplaySolid(hex);
              applyDisplayBackground('solid', hex, displayGradient);
            }}
          />
        ) : (
          <GradientStopsEditor
            caption={`Viewport gradient (${DISPLAY_THEME_CHROME_MIN_STOPS}–${DISPLAY_THEME_CHROME_MAX_STOPS} stops).`}
            colors={displayGradient}
            fallback={displaySolid}
            minStops={DISPLAY_THEME_CHROME_MIN_STOPS}
            maxStops={DISPLAY_THEME_CHROME_MAX_STOPS}
            disabled={disabled}
            onChange={(stops) => {
              setDisplayGradient(stops);
              applyDisplayBackground('gradient', displaySolid, stops);
            }}
          />
        )}
      </Stack>
      <Stack spacing={1}>
        <Typography variant="subtitle2" sx={{
          fontWeight: 600
        }}>
          Screen chrome
        </Typography>
        <Typography variant="caption" sx={{
          color: "text.secondary"
        }}>
          Text color on screen content panels, plus the panel background gradient behind it.
        </Typography>
        <ColorRow
          label="Screen text color"
          hex={screen.foreground}
          fallback={screen.foreground}
          disabled={disabled}
          onChange={(foreground) => {
            patch({
              primaryContainer: joinContainerGroup(foreground, screen.chromeStops),
            });
          }}
        />
        <GradientStopsEditor
          caption={`Screen panel background (${CONTAINER_CHROME_GRADIENT_MIN}–${CONTAINER_CHROME_GRADIENT_MAX} gradient stops).`}
          colors={screen.chromeStops}
          fallback={screen.foreground}
          minStops={CONTAINER_CHROME_GRADIENT_MIN}
          maxStops={CONTAINER_CHROME_GRADIENT_MAX}
          disabled={disabled}
          onChange={(chromeStops) => {
            patch({
              primaryContainer: joinContainerGroup(screen.foreground, chromeStops),
            });
          }}
        />
      </Stack>
      <Stack spacing={1}>
        <Typography variant="subtitle2" sx={{
          fontWeight: 600
        }}>
          Ticker chrome
        </Typography>
        <ColorRow
          label="Ticker text color"
          hex={ticker.foreground}
          fallback={ticker.foreground}
          disabled={disabled}
          onChange={(foreground) => {
            patch({
              secondaryContainer: joinContainerGroup(foreground, ticker.chromeStops),
            });
          }}
        />
        <GradientStopsEditor
          caption={`Ticker strip background (${CONTAINER_CHROME_GRADIENT_MIN}–${CONTAINER_CHROME_GRADIENT_MAX} gradient stops).`}
          colors={ticker.chromeStops}
          fallback={ticker.foreground}
          minStops={CONTAINER_CHROME_GRADIENT_MIN}
          maxStops={CONTAINER_CHROME_GRADIENT_MAX}
          disabled={disabled}
          onChange={(chromeStops) => {
            patch({
              secondaryContainer: joinContainerGroup(ticker.foreground, chromeStops),
            });
          }}
        />
      </Stack>
      <Stack spacing={1}>
        <Typography variant="subtitle2" sx={{
          fontWeight: 600
        }}>
          Accents
        </Typography>
        <Typography variant="caption" sx={{
          color: "text.secondary"
        }}>
          Four accent colors used across screens and ticker highlights.
        </Typography>
        {preview.accents.map((hex, index) => (
          <ColorRow
            key={`accent-${index}`}
            label={`Accent ${index + 1}`}
            hex={hex}
            fallback={displayFallback}
            disabled={disabled}
            onChange={(next) => {
              const accents = [...preview.accents];
              accents[index] = next;
              patch({ accents });
            }}
          />
        ))}
      </Stack>
    </Stack>
  );
}
