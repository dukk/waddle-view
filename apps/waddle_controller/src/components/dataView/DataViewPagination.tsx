import { TablePagination } from '@mui/material';
import {
  DATA_VIEW_DEFAULT_PAGE_SIZE,
  DATA_VIEW_ROWS_PER_PAGE_OPTIONS,
} from '@/util/listPagination';

type Props = {
  count: number;
  page: number;
  pageSize: number;
  onPageChange: (page: number) => void;
  onPageSizeChange: (pageSize: number) => void;
  rowsPerPageOptions?: readonly number[];
};

export function DataViewPagination({
  count,
  page,
  pageSize,
  onPageChange,
  onPageSizeChange,
  rowsPerPageOptions = DATA_VIEW_ROWS_PER_PAGE_OPTIONS,
}: Props) {
  if (count === 0) return null;

  return (
    <TablePagination
      component="div"
      count={count}
      page={page}
      onPageChange={(_, next) => onPageChange(next)}
      rowsPerPage={pageSize}
      onRowsPerPageChange={(e) => {
        const next = parseInt(e.target.value, 10);
        onPageSizeChange(Number.isFinite(next) ? next : DATA_VIEW_DEFAULT_PAGE_SIZE);
      }}
      rowsPerPageOptions={[...rowsPerPageOptions]}
    />
  );
}
