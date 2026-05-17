import { renderHook, act } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { useDisplayRefresh } from './useDisplayRefresh';

describe('useDisplayRefresh', () => {
  it('starts idle and toggles loading around async work', async () => {
    const { result } = renderHook(() => useDisplayRefresh());
    expect(result.current.loading).toBe(false);

    let resolve!: () => void;
    const pending = new Promise<void>((r) => {
      resolve = r;
    });

    let wrapped: Promise<void> | undefined;
    act(() => {
      wrapped = result.current.wrapRefresh(async () => {
        await pending;
      });
    });
    expect(result.current.loading).toBe(true);

    await act(async () => {
      resolve();
      await wrapped;
    });
    expect(result.current.loading).toBe(false);
  });

  it('keeps loading until all overlapping refreshes finish', async () => {
    const { result } = renderHook(() => useDisplayRefresh());

    let resolveA!: () => void;
    let resolveB!: () => void;
    const pendingA = new Promise<void>((r) => {
      resolveA = r;
    });
    const pendingB = new Promise<void>((r) => {
      resolveB = r;
    });

    let wrappedA: Promise<void> | undefined;
    let wrappedB: Promise<void> | undefined;
    act(() => {
      wrappedA = result.current.wrapRefresh(async () => {
        await pendingA;
      });
      wrappedB = result.current.wrapRefresh(async () => {
        await pendingB;
      });
    });
    expect(result.current.loading).toBe(true);

    await act(async () => {
      resolveA();
      await wrappedA;
    });
    expect(result.current.loading).toBe(true);

    await act(async () => {
      resolveB();
      await wrappedB;
    });
    expect(result.current.loading).toBe(false);
  });
});
