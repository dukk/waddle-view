/// <reference types="vite/client" />
/// <reference types="react" />
/// <reference types="react-dom" />

declare const __APP_VERSION__: string;

declare module '@novnc/novnc' {
  export default class RFB {
    constructor(
      target: HTMLElement,
      url: string,
      options?: { credentials?: { password?: string } },
    );
    scaleViewport: boolean;
    resizeSession: boolean;
    disconnect(): void;
    addEventListener(type: string, listener: (ev: Event) => void): void;
  }
}
