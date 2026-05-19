import { useMemo } from 'react';
import Form from '@rjsf/mui';
import validator from '@rjsf/validator-ajv8';
import type { FieldProps, RegistryFieldsType, RegistryWidgetsType, RJSFSchema } from '@rjsf/utils';
import { Box } from '@mui/material';
import { normalizeSchemaFieldLabels } from '@/util/schemaFieldLabel';
import { prepareRjsfSchema } from '@/util/rjsfSchema';
import { buildUiSchemaFromJsonSchema } from '@/util/schemaConfigForm';
import type { SavedDisplay } from '@/storage/displays';
import { OverlayBlobKeysField } from './OverlayBlobKeysField';
import { WaddleSliderWidget, WaddleSwitchWidget } from './SchemaConfigFormWidgets';

const widgets: RegistryWidgetsType = {
  WaddleSwitchWidget,
  WaddleSliderWidget,
};

type Props = {
  display: SavedDisplay;
  schema: unknown;
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
  /** When false, omit the default submit row (dialog provides Save). */
  showSubmit?: boolean;
  children?: React.ReactNode;
};

export function SchemaConfigForm({
  display,
  schema: rawSchema,
  formData,
  onChange,
  disabled = false,
  showSubmit = false,
  children,
}: Props) {
  const schema = useMemo(() => {
    const prepared = prepareRjsfSchema(rawSchema);
    return normalizeSchemaFieldLabels(structuredClone(prepared));
  }, [rawSchema]);
  const uiSchema = useMemo(() => buildUiSchemaFromJsonSchema(schema), [schema]);

  const fields: RegistryFieldsType = useMemo(
    () => ({
      OverlayBlobKeysField: (fieldProps: FieldProps) => (
        <OverlayBlobKeysField {...fieldProps} display={display} />
      ),
    }),
    [display],
  );

  return (
    <Box sx={{ '& .MuiFormControl-root': { mb: 1.5 } }}>
      <Form
        schema={schema as RJSFSchema}
        uiSchema={uiSchema}
        formData={formData}
        validator={validator}
        widgets={widgets}
        fields={fields}
        disabled={disabled}
        onChange={(e) => onChange((e.formData ?? {}) as Record<string, unknown>)}
      >
        {showSubmit ? children : <span style={{ display: 'none' }} />}
      </Form>
    </Box>
  );
}
