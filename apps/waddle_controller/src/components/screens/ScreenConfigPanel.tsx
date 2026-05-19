import { Stack, Typography } from '@mui/material';
import type { SavedDisplay } from '@/storage/displays';
import type { ContentCategoryOption } from '@/components/config/ContentCategorySelectField';
import { SchemaConfigForm } from '@/components/config/SchemaConfigForm';
import { prepareRjsfSchema } from '@/util/rjsfSchema';

type Props = {
  display: SavedDisplay;
  schema: unknown;
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
  categories?: ContentCategoryOption[];
};

export function ScreenConfigPanel({
  display,
  schema,
  formData,
  onChange,
  disabled,
  categories = [],
}: Props) {
  const prepared = prepareRjsfSchema(schema);
  const sectionTitle =
    typeof prepared.title === 'string' && prepared.title.trim()
      ? prepared.title.trim()
      : 'Configuration';
  const schemaForForm = { ...prepared };
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
      />
    </Stack>
  );
}
