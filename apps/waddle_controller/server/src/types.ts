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
