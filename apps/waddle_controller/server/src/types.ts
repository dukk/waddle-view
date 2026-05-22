export type ControllerRole = 'admin' | 'operator';

export type PublicUser = {
  id: string;
  username: string;
  role: ControllerRole;
  disabled: boolean;
  mustChangePassword: boolean;
  lastLoginAt: string | null;
  createdAt: string;
  updatedAt: string;
};

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

export type AboutResponse = {
  app: string;
  version: string;
  build: string;
  productLicense: ProductLicenseInfo;
  dependencies: DependencyInfo[];
  thirdPartyNotices: string;
};

export type StatusResponse = {
  /** Env capability: `WADDLE_CONTROLLER_AUTH_ENABLED=1`. */
  authEnabled: boolean;
  /** Runtime user mode (SQLite). Alias: `userManagementEnabled`. */
  userModeEnabled: boolean;
  userManagementEnabled: boolean;
  needsBootstrap: boolean;
  recoveryExportAvailable: boolean;
  clientIdentifier?: string;
  user?: Pick<PublicUser, 'id' | 'username' | 'role' | 'mustChangePassword'>;
};
