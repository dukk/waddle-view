import { useMemo } from 'react';
import { Stack, Typography } from '@mui/material';
import type { SavedDisplay } from '@/storage/displays';
import type { ContentCategoryOption } from '@/components/config/ContentCategorySelectField';
import { SchemaConfigForm } from '@/components/config/SchemaConfigForm';
import type { DisplayThemePreviewGroups } from '@/constants/displayThemePreview';
import { partitionJsonSchemaProperties } from '@/util/schemaTabPartition';
import { prepareRjsfSchema } from '@/util/rjsfSchema';

export type ScreenConfigTab = 'basic' | 'advanced';

type Props = {
  display: SavedDisplay;
  screenType: string;
  schema: unknown;
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
  categories?: ContentCategoryOption[];
  themePreview?: DisplayThemePreviewGroups;
  tab?: ScreenConfigTab;
};

export function ScreenConfigPanel({
  display,
  screenType: _screenType,
  schema,
  formData,
  onChange,
  disabled,
  categories = [],
  themePreview,
  tab = 'basic',
}: Props) {
  const partitionedSchema = useMemo(
    () => prepareRjsfSchema(partitionJsonSchemaProperties(schema, tab)),
    [schema, tab],
  );

  const properties = partitionedSchema.properties as Record<string, unknown> | undefined;
  if (!properties || Object.keys(properties).length === 0) {
    return null;
  }

  const sectionTitle =
    typeof partitionedSchema.title === 'string' && partitionedSchema.title.trim()
      ? partitionedSchema.title.trim()
      : tab === 'advanced'
        ? 'Advanced configuration'
        : 'Configuration';
  const schemaForForm = { ...partitionedSchema };
  delete schemaForForm.title;

  return (
    <Stack spacing={1}>
      <Typography variant="subtitle2">{sectionTitle}</Typography>
      <SchemaConfigForm
        display={display}
        schema={schemaForForm}
        formData={formData}
        onChange={onChange}
        disabled={disabled}
        categories={categories}
        themePreview={themePreview}
      />
    </Stack>
  );
}
