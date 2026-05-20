import { describe, expect, it } from 'vitest';
import {
  QR_OVERLAY_TEMPLATE_CUSTOM,
  QR_OVERLAY_TEMPLATE_HTTP,
  QR_OVERLAY_TEMPLATE_MAILTO,
  QR_OVERLAY_TEMPLATE_TEL,
  QR_OVERLAY_TEMPLATE_WIFI,
  buildQrOverlayPayload,
  syncQrOverlayFormData,
} from './qrOverlayPayload';

describe('buildQrOverlayPayload', () => {
  it('http adds https when scheme missing', () => {
    expect(buildQrOverlayPayload(QR_OVERLAY_TEMPLATE_HTTP, { url: 'example.com' })).toBe(
      'https://example.com',
    );
  });

  it('mailto encodes query params', () => {
    expect(
      buildQrOverlayPayload(QR_OVERLAY_TEMPLATE_MAILTO, {
        email: 'user@example.com',
        subject: 'Hi',
        body: 'There',
      }),
    ).toBe('mailto:user@example.com?subject=Hi&body=There');
  });

  it('tel normalizes spaces', () => {
    expect(buildQrOverlayPayload(QR_OVERLAY_TEMPLATE_TEL, { phone: '+1 555 000 1111' })).toBe(
      'tel:+15550001111',
    );
  });

  it('wifi builds ZXing-style string', () => {
    expect(
      buildQrOverlayPayload(QR_OVERLAY_TEMPLATE_WIFI, {
        ssid: 'Guest',
        securityType: 'WPA',
        password: 'secret',
        hidden: true,
      }),
    ).toBe('WIFI:T:WPA;S:Guest;P:secret;H:true;');
  });

  it('custom reads payload field', () => {
    expect(
      buildQrOverlayPayload(QR_OVERLAY_TEMPLATE_CUSTOM, { payload: 'raw' }),
    ).toBe('raw');
  });
});

describe('syncQrOverlayFormData', () => {
  it('recomputes payload from template_fields', () => {
    const out = syncQrOverlayFormData({
      template: QR_OVERLAY_TEMPLATE_HTTP,
      template_fields: { url: 'https://waddle.test' },
    });
    expect(out.payload).toBe('https://waddle.test');
    expect(out.template).toBe(QR_OVERLAY_TEMPLATE_HTTP);
  });
});
