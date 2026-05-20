import { useRef, type ReactNode } from 'react';
import { Box, Stack } from '@mui/material';
import { CATALOG_CARD_GRID_GAP_SPACING } from '@/constants/catalogLayout';
import { useCatalogCardGridMetrics } from '@/hooks/useCatalogCardGridMetrics';

export type CatalogListWithTransferSectionProps = {
  toolbar?: ReactNode;
  list: ReactNode;
  transferPanel: ReactNode;
};

export function CatalogListWithTransferSection({
  toolbar,
  list,
  transferPanel,
}: CatalogListWithTransferSectionProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const { supportsSideRail, sidePanelWidthPx } = useCatalogCardGridMetrics(containerRef);

  const mainContent = (
    <Stack spacing={3}>
      {toolbar}
      {list}
    </Stack>
  );

  if (!transferPanel) {
    return <>{mainContent}</>;
  }

  const useSideRail = supportsSideRail;

  return (
    <Box ref={containerRef} sx={{ width: '100%' }}>
      {useSideRail ? (
        <Stack
          direction="row"
          spacing={CATALOG_CARD_GRID_GAP_SPACING}
          alignItems="flex-start"
        >
          <Box sx={{ flex: 1, minWidth: 0 }}>{mainContent}</Box>
          <Box
            sx={{
              width: sidePanelWidthPx,
              maxWidth: sidePanelWidthPx,
              flexShrink: 0,
            }}
          >
            {transferPanel}
          </Box>
        </Stack>
      ) : (
        <Stack spacing={3}>
          {mainContent}
          {transferPanel}
        </Stack>
      )}
    </Box>
  );
}
