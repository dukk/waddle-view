import { ensureNativeModules } from './rebuild-native-modules.mjs';

export default async function setup() {
  ensureNativeModules();
}
