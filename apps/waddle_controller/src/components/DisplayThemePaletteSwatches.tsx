import { Box } from '@mui/material';

type DisplayThemePaletteSwatchesProps = {
  colors: readonly string[];
  size?: number;
};

/** Inline color squares for display theme picker rows (matches Coolors / TV palette order). */
export function DisplayThemePaletteSwatches({
  colors,
  size = 14,
}: DisplayThemePaletteSwatchesProps) {
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
      {colors.map((hex) => (
        <Box
          key={hex}
          sx={{
            width: size,
            height: size,
            borderRadius: 0.5,
            bgcolor: hex,
            border: '1px solid',
            borderColor: 'divider',
            boxShadow: 'inset 0 0 0 1px rgba(0,0,0,0.12)',
          }}
        />
      ))}
    </Box>
  );
}
