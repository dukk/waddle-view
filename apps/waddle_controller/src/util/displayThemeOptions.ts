import type { DisplayThemePreviewGroups } from '@/constants/displayThemePreview';
import type { CuratorThemeOption } from '@/constants/curatorDisplaySettings';
import type { DisplayCustomTheme, DisplayThemePickerOption } from '@/constants/displayThemes';

export function mergeBuiltinAndCustomThemes(
  builtins: readonly CuratorThemeOption[],
  customs: readonly DisplayCustomTheme[],
): DisplayThemePickerOption[] {
  const builtinOptions: DisplayThemePickerOption[] = builtins.map((t) => ({
    id: t.id,
    label: t.label,
    preview: t.preview,
    isCustom: false,
  }));
  const customOptions: DisplayThemePickerOption[] = customs.map((t) => ({
    id: t.id,
    label: t.label,
    preview: t.preview,
    isCustom: true,
  }));
  return [...builtinOptions, ...customOptions];
}

export function displayThemeOptionById(
  options: readonly DisplayThemePickerOption[],
  id: string,
): DisplayThemePickerOption | undefined {
  return options.find((t) => t.id === id);
}

export function clonePreviewGroups(
  groups: DisplayThemePreviewGroups,
): DisplayThemePreviewGroups {
  return {
    display: [...groups.display],
    primaryContainer: [...groups.primaryContainer],
    secondaryContainer: [...groups.secondaryContainer],
    accents: [...groups.accents],
  };
}
