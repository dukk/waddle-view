import { useEffect, useMemo, useState, type RefObject } from 'react';
import { useTheme } from '@mui/material';
import {
  CATALOG_CARD_GRID_GAP_SPACING,
  catalogCardColumnCount,
  catalogSupportsTransferSideRail,
  catalogTwoCardWidthPx,
} from '@/constants/catalogLayout';

export function useCatalogCardGridMetrics(
  containerRef: RefObject<HTMLElement | null>,
): {
  columnCount: number;
  supportsSideRail: boolean;
  sidePanelWidthPx: number;
  gapPx: number;
} {
  const theme = useTheme();
  const gapPx = parseFloat(theme.spacing(CATALOG_CARD_GRID_GAP_SPACING));
  const [containerWidthPx, setContainerWidthPx] = useState(0);

  useEffect(() => {
    const el = containerRef.current;
    if (!el) {
      return;
    }
    const measure = () => {
      setContainerWidthPx(el.clientWidth);
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, [containerRef]);

  const columnCount = useMemo(
    () => catalogCardColumnCount(containerWidthPx, gapPx),
    [containerWidthPx, gapPx],
  );

  const supportsSideRail = catalogSupportsTransferSideRail(columnCount);

  const sidePanelWidthPx = useMemo(
    () => catalogTwoCardWidthPx(containerWidthPx, columnCount, gapPx),
    [containerWidthPx, columnCount, gapPx],
  );

  return { columnCount, supportsSideRail, sidePanelWidthPx, gapPx };
}
