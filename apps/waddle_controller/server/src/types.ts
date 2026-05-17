export type ControllerRole = 'admin' | 'operator';

export type PublicUser = {
  id: string;
  username: string;
  role: ControllerRole;
  disabled: boolean;
  createdAt: string;
  updatedAt: string;
};

export type StatusResponse = {
  authEnabled: boolean;
  userManagementEnabled: boolean;
  needsBootstrap: boolean;
  clientIdentifier?: string;
  user?: Pick<PublicUser, 'id' | 'username' | 'role'>;
};
