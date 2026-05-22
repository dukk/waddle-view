import { bffJson } from '@/api/bffClient';

export type ProductLicenseInfo = {
  id: string;
  name: string;
  url: string;
  summary: string;
};

export type DependencyInfo = {
  name: string;
  version: string;
  license?: string;
};

export type AboutPayload = {
  app: string;
  version: string;
  build: string;
  productLicense: ProductLicenseInfo;
  dependencies: DependencyInfo[];
  thirdPartyNotices: string;
};

export function fetchControllerAbout(): Promise<AboutPayload> {
  return bffJson<AboutPayload>('/about');
}
