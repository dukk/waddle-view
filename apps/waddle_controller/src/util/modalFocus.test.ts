import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import {
  blurFocusedElementWithinAppRoot,
  hasOpenMuiModal,
  isFocusableWithinAppRoot,
  reconcileModalFocusWithAppRoot,
} from './modalFocus';

describe('modalFocus', () => {
  let root: HTMLDivElement;
  let button: HTMLButtonElement;
  let modal: HTMLDivElement;

  beforeEach(() => {
    document.body.innerHTML = '';
    root = document.createElement('div');
    root.id = 'root';
    button = document.createElement('button');
    button.type = 'button';
    button.textContent = 'Save';
    root.append(button);
    modal = document.createElement('div');
    modal.className = 'MuiModal-root';
    document.body.append(root, modal);
  });

  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('detects focused descendants of #root', () => {
    button.focus();
    expect(isFocusableWithinAppRoot(document.activeElement, root)).toBe(true);
    expect(isFocusableWithinAppRoot(modal, root)).toBe(false);
  });

  it('blurs focused descendants of #root', () => {
    button.focus();
    expect(blurFocusedElementWithinAppRoot(document.activeElement, root)).toBe(true);
    expect(document.activeElement).toBe(document.body);
  });

  it('reports open MUI modals', () => {
    expect(hasOpenMuiModal(document.querySelectorAll('.MuiModal-root'))).toBe(true);
    modal.remove();
    expect(hasOpenMuiModal(document.querySelectorAll('.MuiModal-root'))).toBe(false);
  });

  it('reconciles focus only while a modal is open', () => {
    button.focus();
    modal.remove();
    expect(reconcileModalFocusWithAppRoot(document.activeElement, root, document.querySelectorAll('.MuiModal-root'))).toBe(
      false,
    );
    expect(document.activeElement).toBe(button);

    document.body.append(modal);
    button.focus();
    expect(reconcileModalFocusWithAppRoot(document.activeElement, root, document.querySelectorAll('.MuiModal-root'))).toBe(
      true,
    );
    expect(document.activeElement).toBe(document.body);
  });
});
