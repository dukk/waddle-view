import { Stack, Typography } from '@mui/material';
import { SchemaConfigForm } from '@/components/config/SchemaConfigForm';
import type { ContentCategoryOption } from '@/components/config/ContentCategorySelectField';
import type { SavedDisplay } from '@/storage/displays';
import { prepareRjsfSchema } from '@/util/rjsfSchema';
import { TickerTypeExtraConfig } from './TickerTypeExtraConfig';

type Props = {
  display: SavedDisplay;
  tickerType: string;
  schema: unknown;
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
  categories?: ContentCategoryOption[];
};

const TYPES_WITH_EXTRA = new Set(['time', 'weather', 'news', 'stocks']);

export function TickerConfigPanel({
  display,
  tickerType,
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

  const type = tickerType.trim().toLowerCase();
  const showExtra = TYPES_WITH_EXTRA.has(type);
  const properties =
    schemaForForm.properties != null &&
    typeof schemaForForm.properties === 'object'
      ? Object.keys(schemaForForm.properties as object)
      : [];
  const showRjsf =
    properties.length > 0 &&
    !(showExtra && ['time', 'weather', 'news', 'stocks'].includes(type));

  return (
    <Stack spacing={1}>
      <Typography variant="subtitle2">{sectionTitle}</Typography>
      {showExtra ? (
        <TickerTypeExtraConfig
          display={display}
          tickerType={type}
          formData={formData}
          onChange={onChange}
          disabled={disabled}
          categories={categories}
        />
      ) : null}
      {showRjsf ? (
        <SchemaConfigForm
          display={display}
          schema={schemaForForm}
          formData={formData}
          onChange={onChange}
          disabled={disabled}
          categories={categories}
        />
      ) : null}
    </Stack>
  );
}
