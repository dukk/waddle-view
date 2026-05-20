export const QR_OVERLAY_TEMPLATE_CUSTOM = 'custom';
export const QR_OVERLAY_TEMPLATE_HTTP = 'http';
export const QR_OVERLAY_TEMPLATE_MAILTO = 'mailto';
export const QR_OVERLAY_TEMPLATE_TEL = 'tel';
export const QR_OVERLAY_TEMPLATE_SMS = 'sms';
export const QR_OVERLAY_TEMPLATE_GEO = 'geo';
export const QR_OVERLAY_TEMPLATE_WIFI = 'wifi';
export const QR_OVERLAY_TEMPLATE_VCARD = 'vcard';
export const QR_OVERLAY_TEMPLATE_VCALENDAR = 'vcalendar';

export const QR_OVERLAY_TEMPLATE_VALUES = [
  QR_OVERLAY_TEMPLATE_CUSTOM,
  QR_OVERLAY_TEMPLATE_HTTP,
  QR_OVERLAY_TEMPLATE_MAILTO,
  QR_OVERLAY_TEMPLATE_TEL,
  QR_OVERLAY_TEMPLATE_SMS,
  QR_OVERLAY_TEMPLATE_GEO,
  QR_OVERLAY_TEMPLATE_WIFI,
  QR_OVERLAY_TEMPLATE_VCARD,
  QR_OVERLAY_TEMPLATE_VCALENDAR,
] as const;

export type QrOverlayTemplate = (typeof QR_OVERLAY_TEMPLATE_VALUES)[number];

export const QR_OVERLAY_TEMPLATE_LABELS: Record<QrOverlayTemplate, string> = {
  custom: 'Custom (raw data)',
  http: 'URL (http/https)',
  mailto: 'Email (mailto)',
  tel: 'Phone (tel)',
  sms: 'SMS (smsto)',
  geo: 'Location (geo)',
  wifi: 'Wi‑Fi (WIFI:…)',
  vcard: 'Contact (vCard)',
  vcalendar: 'Event (vCalendar)',
};

function readString(raw: unknown): string {
  if (raw == null) return '';
  if (typeof raw === 'string') return raw.trim();
  return String(raw).trim();
}

function escapeWifiField(value: string): string {
  let out = '';
  for (let i = 0; i < value.length; i++) {
    const c = value[i];
    if (c === '\\' || c === ';' || c === ',' || c === ':') {
      out += '\\';
    }
    out += c;
  }
  return out;
}

function normalizePhone(raw: string): string {
  const trimmed = raw.replace(/\s+/g, '');
  if (!trimmed) return '';
  if (trimmed.startsWith('+')) return trimmed;
  return trimmed;
}

export function buildQrOverlayPayload(
  template: string,
  fields: Record<string, unknown>,
): string {
  const t = template.trim().toLowerCase();
  switch (t) {
    case QR_OVERLAY_TEMPLATE_CUSTOM:
      return readString(fields.payload ?? fields.data);
    case QR_OVERLAY_TEMPLATE_HTTP:
      return buildHttpPayload(fields);
    case QR_OVERLAY_TEMPLATE_MAILTO:
      return buildMailtoPayload(fields);
    case QR_OVERLAY_TEMPLATE_TEL:
      return buildTelPayload(fields);
    case QR_OVERLAY_TEMPLATE_SMS:
      return buildSmsPayload(fields);
    case QR_OVERLAY_TEMPLATE_GEO:
      return buildGeoPayload(fields);
    case QR_OVERLAY_TEMPLATE_WIFI:
      return buildWifiPayload(fields);
    case QR_OVERLAY_TEMPLATE_VCARD:
      return buildVcardPayload(fields);
    case QR_OVERLAY_TEMPLATE_VCALENDAR:
      return buildVcalendarPayload(fields);
    default:
      return '';
  }
}

function buildHttpPayload(fields: Record<string, unknown>): string {
  let url = readString(fields.url);
  if (!url) return '';
  if (!url.includes('://')) {
    url = `https://${url}`;
  }
  return url;
}

function buildMailtoPayload(fields: Record<string, unknown>): string {
  const email = readString(fields.email);
  if (!email) return '';
  const subject = readString(fields.subject);
  const body = readString(fields.body);
  const params: string[] = [];
  if (subject) params.push(`subject=${encodeURIComponent(subject)}`);
  if (body) params.push(`body=${encodeURIComponent(body)}`);
  return params.length > 0 ? `mailto:${email}?${params.join('&')}` : `mailto:${email}`;
}

function buildTelPayload(fields: Record<string, unknown>): string {
  const phone = normalizePhone(readString(fields.phone));
  return phone ? `tel:${phone}` : '';
}

function buildSmsPayload(fields: Record<string, unknown>): string {
  const phone = normalizePhone(readString(fields.phone));
  if (!phone) return '';
  const body = readString(fields.body);
  return body ? `smsto:${phone}?body=${encodeURIComponent(body)}` : `smsto:${phone}`;
}

function buildGeoPayload(fields: Record<string, unknown>): string {
  const lat = readString(fields.lat);
  const lng = readString(fields.lng);
  if (!lat || !lng) return '';
  const label = readString(fields.label);
  return label ? `geo:${lat},${lng}?q=${encodeURIComponent(label)}` : `geo:${lat},${lng}`;
}

function buildWifiPayload(fields: Record<string, unknown>): string {
  const ssid = readString(fields.ssid);
  if (!ssid) return '';
  const security = readString(fields.securityType);
  const t = security || 'nopass';
  const password = readString(fields.password);
  const hidden = fields.hidden === true;
  let out = `WIFI:T:${escapeWifiField(t)};S:${escapeWifiField(ssid)};`;
  if (t !== 'nopass' && t !== 'NOPASS' && password) {
    out += `P:${escapeWifiField(password)};`;
  }
  if (hidden) {
    out += 'H:true;';
  }
  return out;
}

function buildVcardPayload(fields: Record<string, unknown>): string {
  const firstName = readString(fields.firstName);
  const lastName = readString(fields.lastName);
  const fullName = readString(fields.fullName);
  const fn =
    fullName || [firstName, lastName].filter((s) => s.length > 0).join(' ').trim();
  if (!fn) return '';
  const lines = ['BEGIN:VCARD', 'VERSION:3.0', `FN:${fn}`];
  const org = readString(fields.org);
  if (org) lines.push(`ORG:${org}`);
  const phone = readString(fields.phone);
  if (phone) lines.push(`TEL:${phone}`);
  const email = readString(fields.email);
  if (email) lines.push(`EMAIL:${email}`);
  const title = readString(fields.title);
  if (title) lines.push(`TITLE:${title}`);
  lines.push('END:VCARD');
  return lines.join('\n');
}

function buildVcalendarPayload(fields: Record<string, unknown>): string {
  const summary = readString(fields.summary);
  const dtStart = readString(fields.dtStart);
  const dtEnd = readString(fields.dtEnd);
  if (!summary || !dtStart || !dtEnd) return '';
  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'BEGIN:VEVENT',
    `SUMMARY:${summary}`,
    `DTSTART:${dtStart}`,
    `DTEND:${dtEnd}`,
  ];
  const location = readString(fields.location);
  if (location) lines.push(`LOCATION:${location}`);
  const description = readString(fields.description);
  if (description) lines.push(`DESCRIPTION:${description}`);
  lines.push('END:VEVENT', 'END:VCALENDAR');
  return lines.join('\n');
}

export function readQrOverlayTemplate(raw: Record<string, unknown>): QrOverlayTemplate {
  const t = readString(raw.template).toLowerCase();
  if ((QR_OVERLAY_TEMPLATE_VALUES as readonly string[]).includes(t)) {
    return t as QrOverlayTemplate;
  }
  return QR_OVERLAY_TEMPLATE_CUSTOM;
}

export function readTemplateFields(raw: Record<string, unknown>): Record<string, unknown> {
  const f = raw.template_fields;
  if (f != null && typeof f === 'object' && !Array.isArray(f)) {
    return { ...(f as Record<string, unknown>) };
  }
  return {};
}

export function syncQrOverlayFormData(formData: Record<string, unknown>): Record<string, unknown> {
  const template = readQrOverlayTemplate(formData);
  const templateFields = readTemplateFields(formData);
  let payload = buildQrOverlayPayload(template, templateFields);
  if (!payload && template === QR_OVERLAY_TEMPLATE_CUSTOM) {
    payload = readString(formData.payload);
  }
  return {
    ...formData,
    template,
    template_fields: templateFields,
    payload,
  };
}
