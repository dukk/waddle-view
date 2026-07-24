import {
  Checkbox,
  FormControl,
  FormControlLabel,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { ClockOverlayPlacementFields } from './ClockOverlayPlacementFields';
import {
  QR_OVERLAY_TEMPLATE_CUSTOM,
  QR_OVERLAY_TEMPLATE_LABELS,
  QR_OVERLAY_TEMPLATE_VALUES,
  buildQrOverlayPayload,
  readQrOverlayTemplate,
  readTemplateFields,
  syncQrOverlayFormData,
  type QrOverlayTemplate,
} from '@/util/qrOverlayPayload';

type Props = {
  formData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
  disabled?: boolean;
};

function readString(raw: unknown): string {
  return typeof raw === 'string' ? raw : '';
}

function TemplateFields({
  template,
  fields,
  disabled,
  onFieldsChange,
}: {
  template: QrOverlayTemplate;
  fields: Record<string, unknown>;
  disabled?: boolean;
  onFieldsChange: (next: Record<string, unknown>) => void;
}) {
  const patchField = (key: string, value: unknown) => {
    onFieldsChange({ ...fields, [key]: value });
  };

  const textField = (
    key: string,
    label: string,
    opts?: { multiline?: boolean; helperText?: string },
  ) => (
    <TextField
      key={key}
      label={label}
      value={readString(fields[key])}
      onChange={(e) => patchField(key, e.target.value)}
      disabled={disabled}
      fullWidth
      multiline={opts?.multiline}
      minRows={opts?.multiline ? 3 : undefined}
      helperText={opts?.helperText}
    />
  );

  switch (template) {
    case 'custom':
      return textField('payload', 'QR payload', { multiline: true });
    case 'http':
      return textField('url', 'URL', { helperText: 'https:// added when scheme omitted' });
    case 'mailto':
      return (
        <Stack spacing={2}>
          {textField('email', 'Email address')}
          {textField('subject', 'Subject (optional)')}
          {textField('body', 'Body (optional)', { multiline: true })}
        </Stack>
      );
    case 'tel':
      return textField('phone', 'Phone number');
    case 'sms':
      return (
        <Stack spacing={2}>
          {textField('phone', 'Phone number')}
          {textField('body', 'Message (optional)', { multiline: true })}
        </Stack>
      );
    case 'geo':
      return (
        <Stack spacing={2}>
          {textField('lat', 'Latitude')}
          {textField('lng', 'Longitude')}
          {textField('label', 'Label (optional)')}
        </Stack>
      );
    case 'wifi':
      return (
        <Stack spacing={2}>
          {textField('ssid', 'Network name (SSID)')}
          {textField('securityType', 'Security (WPA, WPA2, WPA3, nopass)', {
            helperText: 'Use nopass for open networks',
          })}
          {textField('password', 'Password (optional for nopass)')}
          <FormControlLabel
            control={
              <Checkbox
                checked={fields.hidden === true}
                disabled={disabled}
                onChange={(e) => patchField('hidden', e.target.checked)}
              />
            }
            label="Hidden network"
          />
        </Stack>
      );
    case 'vcard':
      return (
        <Stack spacing={2}>
          {textField('fullName', 'Full name')}
          <Typography variant="caption" sx={{
            color: "text.secondary"
          }}>
            Or use first + last name below instead of full name.
          </Typography>
          {textField('firstName', 'First name')}
          {textField('lastName', 'Last name')}
          {textField('org', 'Organization (optional)')}
          {textField('phone', 'Phone (optional)')}
          {textField('email', 'Email (optional)')}
          {textField('title', 'Job title (optional)')}
        </Stack>
      );
    case 'vcalendar':
      return (
        <Stack spacing={2}>
          {textField('summary', 'Event title')}
          {textField('dtStart', 'Start (YYYYMMDDTHHMMSS)', {
            helperText: 'Local time without timezone, e.g. 20260615T140000',
          })}
          {textField('dtEnd', 'End (YYYYMMDDTHHMMSS)')}
          {textField('location', 'Location (optional)')}
          {textField('description', 'Description (optional)', { multiline: true })}
        </Stack>
      );
    default:
      return null;
  }
}

export function QrCodeOverlayConfigForm({ formData, onChange, disabled }: Props) {
  const template = readQrOverlayTemplate(formData);
  const templateFields = readTemplateFields(formData);
  const payloadPreview =
    readString(formData.payload) ||
    buildQrOverlayPayload(template, templateFields);

  const apply = (next: Record<string, unknown>) => {
    onChange(syncQrOverlayFormData(next));
  };

  const patch = (partial: Record<string, unknown>) => {
    apply({ ...formData, ...partial });
  };

  const patchTemplateFields = (nextFields: Record<string, unknown>) => {
    apply({ ...formData, template_fields: nextFields });
  };

  return (
    <Stack spacing={2}>
      <Typography variant="body2" sx={{
        color: "text.secondary"
      }}>
        QR code with optional title above and description below. Position and scale match
        other placed overlays (clocks, stock quote).
      </Typography>
      <TextField
        label="Title (optional)"
        value={readString(formData.title)}
        onChange={(e) => patch({ title: e.target.value || undefined })}
        disabled={disabled}
        fullWidth
      />
      <FormControl fullWidth disabled={disabled}>
        <InputLabel id="qr-template-label">Payload template</InputLabel>
        <Select
          labelId="qr-template-label"
          label="Payload template"
          value={template}
          onChange={(e) => {
            const nextTemplate = e.target.value as QrOverlayTemplate;
            apply({
              ...formData,
              template: nextTemplate,
              template_fields: nextTemplate === QR_OVERLAY_TEMPLATE_CUSTOM ? templateFields : {},
            });
          }}
        >
          {QR_OVERLAY_TEMPLATE_VALUES.map((t) => (
            <MenuItem key={t} value={t}>
              {QR_OVERLAY_TEMPLATE_LABELS[t]}
            </MenuItem>
          ))}
        </Select>
      </FormControl>
      <TemplateFields
        template={template}
        fields={templateFields}
        disabled={disabled}
        onFieldsChange={patchTemplateFields}
      />
      {template === QR_OVERLAY_TEMPLATE_CUSTOM ? (
        <TextField
          label="QR payload"
          value={readString(formData.payload)}
          onChange={(e) => patch({ payload: e.target.value })}
          disabled={disabled}
          fullWidth
          multiline
          minRows={3}
        />
      ) : null}
      <Typography variant="caption" component="div" sx={{
        color: "text.secondary"
      }}>
        Encoded payload (saved on submit)
      </Typography>
      <Typography
        variant="body2"
        sx={{ fontFamily: 'monospace', wordBreak: 'break-all', whiteSpace: 'pre-wrap' }}
      >
        {payloadPreview || '(empty — fill template fields)'}
      </Typography>
      <TextField
        label="Description (optional)"
        value={readString(formData.description)}
        onChange={(e) => patch({ description: e.target.value || undefined })}
        disabled={disabled}
        fullWidth
        multiline
        minRows={2}
      />
      <ClockOverlayPlacementFields
        formData={formData}
        onChange={(next) => apply(next)}
        disabled={disabled}
        scaleHelp="QR block width as a fraction of the viewport shortest side."
      />
    </Stack>
  );
}
