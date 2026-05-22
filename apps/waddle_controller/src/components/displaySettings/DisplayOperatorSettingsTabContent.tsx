import {
  DisplayOperatorSettingsLoading,
  DisplayOperatorSettingsPanel,
  type DisplayOperatorSettingsPanelVariant,
} from '@/components/displaySettings/DisplayOperatorSettingsPanel';
import { useDisplayOperatorSettingsContext } from '@/context/DisplayOperatorSettingsContext';
import type { SavedDisplay } from '@/storage/displays';

export function DisplayOperatorSettingsTabContent({
  display,
  canWrite,
  variant,
  onKvChanged,
}: {
  display: SavedDisplay;
  canWrite: boolean;
  variant: DisplayOperatorSettingsPanelVariant;
  onKvChanged: () => void;
}) {
  const settings = useDisplayOperatorSettingsContext();
  if (!settings) {
    return <DisplayOperatorSettingsLoading />;
  }
  return (
    <DisplayOperatorSettingsPanel
      variant={variant}
      display={display}
      canWrite={canWrite}
      settings={settings}
      onKvChanged={onKvChanged}
    />
  );
}
