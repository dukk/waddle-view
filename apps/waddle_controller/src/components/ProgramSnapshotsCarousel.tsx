import type { ReactNode } from 'react';
import { Box, Chip, Fade, IconButton, Stack, Typography } from '@mui/material';
import ChevronLeftIcon from '@mui/icons-material/ChevronLeft';
import ChevronRightIcon from '@mui/icons-material/ChevronRight';
import { findProgramIndexByAtMs, programAtMs } from '@/util/programTelemetry';

type Props = {
  programs: Record<string, unknown>[];
  selectedAtMs: number | null;
  onSelectAtMs: (atMs: number) => void;
  isLive?: (atMs: number) => boolean;
  renderProgram: (row: Record<string, unknown>, index: number) => ReactNode;
  emptyMessage?: string;
};

export function ProgramSnapshotsCarousel({
  programs,
  selectedAtMs,
  onSelectAtMs,
  isLive,
  renderProgram,
  emptyMessage = 'No snapshots to show.',
}: Props) {
  const total = programs.length;
  const index =
    selectedAtMs != null ? findProgramIndexByAtMs(programs, selectedAtMs) : -1;
  const safeIndex = index >= 0 ? index : 0;
  const row = total > 0 ? programs[safeIndex] : null;
  const showLive = selectedAtMs != null && isLive?.(selectedAtMs) === true;

  const goPrev = () => {
    if (safeIndex <= 0) return;
    const prev = programs[safeIndex - 1];
    if (prev) onSelectAtMs(programAtMs(prev));
  };

  const goNext = () => {
    if (safeIndex >= total - 1) return;
    const next = programs[safeIndex + 1];
    if (next) onSelectAtMs(programAtMs(next));
  };

  if (total === 0) {
    return (
      <Typography variant="body2" color="text.secondary">
        {emptyMessage}
      </Typography>
    );
  }

  return (
    <Stack spacing={1.5}>
      <Stack direction="row" alignItems="center" spacing={1} flexWrap="wrap">
        <IconButton
          aria-label="Previous program"
          onClick={goPrev}
          disabled={safeIndex <= 0}
          size="small"
        >
          <ChevronLeftIcon />
        </IconButton>
        <Typography variant="body2" color="text.secondary" sx={{ minWidth: 120, textAlign: 'center' }}>
          Program {safeIndex + 1} of {total}
        </Typography>
        <IconButton
          aria-label="Next program"
          onClick={goNext}
          disabled={safeIndex >= total - 1}
          size="small"
        >
          <ChevronRightIcon />
        </IconButton>
        {showLive && <Chip label="Live" size="small" color="success" variant="outlined" />}
        <Box sx={{ flex: 1 }} />
      </Stack>
      <Fade in timeout={200} key={selectedAtMs ?? safeIndex}>
        <Box>{row ? renderProgram(row, safeIndex) : null}</Box>
      </Fade>
    </Stack>
  );
}
