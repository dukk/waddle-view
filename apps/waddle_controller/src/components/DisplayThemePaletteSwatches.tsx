import { Box } from '@mui/material';

import type { DisplayThemePreviewGroups } from '@/constants/displayThemePreview';

type DisplayThemePaletteSwatchesProps = {
  /** Legacy flat list (still supported). */
  colors?: readonly string[];
  /** Role-grouped preview matching display runtime theme fills. */
  groups?: DisplayThemePreviewGroups;
  size?: number;
};

function Swatch({ hex, size }: { hex: string; size: number }) {
  return (
    <Box
      sx={{
        width: size,
        height: size,
        borderRadius: 0.5,
        bgcolor: hex,
        border: '1px solid',
        borderColor: 'divider',
        boxShadow: 'inset 0 0 0 1px rgba(0,0,0,0.12)',
        flexShrink: 0,
      }}
    />
  );
}

/** Inline color squares for display theme picker (display → slide → ticker → accents). */
export function DisplayThemePaletteSwatches({
  colors,
  groups,
  size = 14,
}: DisplayThemePaletteSwatchesProps) {
  if (groups) {
    const sections = [
      groups.display,
      groups.primaryContainer,
      groups.secondaryContainer,
      groups.accents,
    ].filter((section) => section.length > 0);

    return (
      <Box
        component="span"
        sx={{
          display: 'inline-flex',
          gap: 0.75,
          alignItems: 'center',
          flexShrink: 0,
          ml: 'auto',
        }}
        aria-hidden
      >
        {sections.map((section, index) => (
          <Box
            key={`section-${index}`}
            component="span"
            sx={{ display: 'inline-flex', gap: 0.375, alignItems: 'center' }}
          >
            {section.map((hex) => (
              <Swatch key={`${index}-${hex}`} hex={hex} size={size} />
            ))}
          </Box>
        ))}
      </Box>
    );
  }

  return (
    <Box
      component="span"
      sx={{
        display: 'inline-flex',
        gap: 0.375,
        alignItems: 'center',
        flexShrink: 0,
        ml: 'auto',
      }}
      aria-hidden
    >
      {(colors ?? []).map((hex) => (
        <Swatch key={hex} hex={hex} size={size} />
      ))}
    </Box>
  );
}
