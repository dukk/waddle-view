import { describe, expect, it, vi } from 'vitest';
import { completeDialogSave } from './dialogSave';

describe('completeDialogSave', () => {
  it('awaits onSaved then calls onClose', async () => {
    const order: string[] = [];
    const onSaved = vi.fn(async () => {
      order.push('saved');
    });
    const onClose = vi.fn(() => {
      order.push('close');
    });

    await completeDialogSave(onSaved, onClose);

    expect(onSaved).toHaveBeenCalledOnce();
    expect(onClose).toHaveBeenCalledOnce();
    expect(order).toEqual(['saved', 'close']);
  });

  it('supports synchronous onSaved', async () => {
    const onSaved = vi.fn();
    const onClose = vi.fn();

    await completeDialogSave(onSaved, onClose);

    expect(onSaved).toHaveBeenCalledOnce();
    expect(onClose).toHaveBeenCalledOnce();
  });

  it('does not call onClose when onSaved throws', async () => {
    const onSaved = vi.fn(async () => {
      throw new Error('save failed');
    });
    const onClose = vi.fn();

    await expect(completeDialogSave(onSaved, onClose)).rejects.toThrow('save failed');
    expect(onClose).not.toHaveBeenCalled();
  });
});
