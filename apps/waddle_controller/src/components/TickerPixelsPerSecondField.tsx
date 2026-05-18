import { useState } from 'react';
import { Box, Button, Stack } from '@mui/material';
import { CuratorSliderField } from '@/components/CuratorSliderField';
import { TickerMarqueeSamplePreview } from '@/components/TickerMarqueeSamplePreview';
import { CURATOR_TICKER_PIXELS_PER_SECOND } from '@/constants/curatorDisplaySettings';

type TickerPixelsPerSecondFieldProps = {
  value: number;
  onChange: (value: number) => void;
  disabled?: boolean;
};

export function TickerPixelsPerSecondField({
  value,
  onChange,
  disabled = false,
}: TickerPixelsPerSecondFieldProps) {
  const [sampleActive, setSampleActive] = useState(false);

  return (
    <Box>
      <Stack direction="row" spacing={1} alignItems="flex-start">
        <Box sx={{ flex: 1, minWidth: 0 }}>
          <CuratorSliderField
            label="Ticker pixels per second"
            value={value}
            min={CURATOR_TICKER_PIXELS_PER_SECOND.min}
            max={CURATOR_TICKER_PIXELS_PER_SECOND.max}
            step={CURATOR_TICKER_PIXELS_PER_SECOND.step}
            disabled={disabled}
            formatValue={(v) => `${v} px/s`}
            onChange={onChange}
          />
        </Box>
        <Button
          variant={sampleActive ? 'contained' : 'outlined'}
          size="small"
          sx={{ mt: 3.25, flexShrink: 0 }}
          disabled={disabled}
          onClick={() => setSampleActive((active) => !active)}
        >
          {sampleActive ? 'Stop sample' : 'Play sample'}
        </Button>
      </Stack>
      {sampleActive && <TickerMarqueeSamplePreview pixelsPerSecond={value} />}
    </Box>
  );
}
