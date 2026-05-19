import { Stack, Typography } from '@mui/material';
import type { SavedDisplay } from '@/storage/displays';
import { prepareRjsfSchema } from '@/util/rjsfSchema';
import { BirthdayConfettiConfigForm } from './BirthdayConfettiConfigForm';
import { FallingImagesConfigForm } from './FallingImagesConfigForm';
import { FloatingBalloonsConfigForm } from './FloatingBalloonsConfigForm';
import { SchemaConfigForm } from './SchemaConfigForm';
import { EdgeGlowConfigForm } from './EdgeGlowConfigForm';
import { MatrixRainConfigForm } from './MatrixRainConfigForm';
import { ShapeRainConfigForm } from './ShapeRainConfigForm';

type Props = {
  display: SavedDisplay;
  overlayType: string;
  schema: unknown;
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
};

function isShapeRainType(t: string): boolean {
  return t === 'shape_rain' || t === 'hearts_rain';
}

export function OverlayConfigPanel({
  display,
  overlayType,
  schema,
  formData,
  onChange,
  disabled,
}: Props) {
  if (isShapeRainType(overlayType)) {
    return <ShapeRainConfigForm formData={formData} onChange={onChange} disabled={disabled} />;
  }
  if (overlayType === 'matrix_rain') {
    return <MatrixRainConfigForm formData={formData} onChange={onChange} disabled={disabled} />;
  }
  if (overlayType === 'edge_glow') {
    return <EdgeGlowConfigForm formData={formData} onChange={onChange} disabled={disabled} />;
  }
  if (overlayType === 'birthday_confetti') {
    return (
      <BirthdayConfettiConfigForm formData={formData} onChange={onChange} disabled={disabled} />
    );
  }
  if (overlayType === 'falling_images') {
    return (
      <FallingImagesConfigForm
        display={display}
        formData={formData}
        onChange={onChange}
        disabled={disabled}
      />
    );
  }
  if (overlayType === 'floating_balloons') {
    return (
      <FloatingBalloonsConfigForm
        formData={formData}
        onChange={onChange}
        disabled={disabled}
      />
    );
  }

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
      />
    </Stack>
  );
}
