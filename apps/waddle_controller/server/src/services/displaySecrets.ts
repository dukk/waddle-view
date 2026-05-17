import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'node:crypto';

const KEY_SALT = 'waddle-controller-display-api-keys-v1';
const IV_BYTES = 12;
const TAG_BYTES = 16;

function deriveKey(sessionSecret: string): Buffer {
  return createHash('sha256').update(`${KEY_SALT}:${sessionSecret}`).digest();
}

export type EncryptedSecret = {
  ciphertext: string;
  iv: string;
};

export function encryptDisplayApiKey(sessionSecret: string, apiKey: string): EncryptedSecret {
  const iv = randomBytes(IV_BYTES);
  const cipher = createCipheriv('aes-256-gcm', deriveKey(sessionSecret), iv);
  const encrypted = Buffer.concat([cipher.update(apiKey, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  const payload = Buffer.concat([encrypted, tag]);
  return {
    ciphertext: payload.toString('base64'),
    iv: iv.toString('base64'),
  };
}

export function decryptDisplayApiKey(
  sessionSecret: string,
  ciphertext: string,
  iv: string,
): string {
  const payload = Buffer.from(ciphertext, 'base64');
  if (payload.length < TAG_BYTES + 1) {
    throw new Error('Invalid ciphertext');
  }
  const encrypted = payload.subarray(0, payload.length - TAG_BYTES);
  const tag = payload.subarray(payload.length - TAG_BYTES);
  const decipher = createDecipheriv('aes-256-gcm', deriveKey(sessionSecret), Buffer.from(iv, 'base64'));
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(encrypted), decipher.final()]).toString('utf8');
}
