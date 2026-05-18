/** After a successful dialog save: refresh parent state, then close the dialog. */
export async function completeDialogSave(
  onSaved: () => void | Promise<void>,
  onClose: () => void,
): Promise<void> {
  await onSaved();
  onClose();
}
