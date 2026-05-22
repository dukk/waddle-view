import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, describe, expect, it } from 'vitest';
import { useConfirmDialog } from '@/hooks/useConfirmDialog';

function ConfirmHarness({
  onResult,
}: {
  onResult: (value: boolean) => void;
}) {
  const { confirm, ConfirmDialogHost } = useConfirmDialog();

  return (
    <>
      <button
        type="button"
        onClick={() => {
          void confirm({
            title: 'Delete item?',
            message: 'This cannot be undone.',
            confirmLabel: 'Delete',
          }).then(onResult);
        }}
      >
        Open confirm
      </button>
      <ConfirmDialogHost />
    </>
  );
}

describe('useConfirmDialog', () => {
  afterEach(() => {
    cleanup();
  });

  it('resolves false when Cancel is clicked', async () => {
    const results: boolean[] = [];
    render(<ConfirmHarness onResult={(v) => results.push(v)} />);

    fireEvent.click(screen.getByRole('button', { name: 'Open confirm' }));
    expect(screen.getByRole('dialog')).toBeInTheDocument();
    expect(screen.getByText('Delete item?')).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'Cancel' }));

    await waitFor(() => {
      expect(results).toEqual([false]);
    });
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  it('resolves true when Confirm is clicked', async () => {
    const results: boolean[] = [];
    render(<ConfirmHarness onResult={(v) => results.push(v)} />);

    fireEvent.click(screen.getByRole('button', { name: 'Open confirm' }));
    fireEvent.click(screen.getByRole('button', { name: 'Delete' }));

    await waitFor(() => {
      expect(results).toEqual([true]);
    });
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });
});
