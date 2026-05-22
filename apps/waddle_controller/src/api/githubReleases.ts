import { bffJson } from '@/api/bffClient';

export type GitHubReleaseAsset = {
  name: string;
  browser_download_url: string;
  size: number;
};

export type WaddleViewReleaseInfo = {
  tag_name: string;
  name: string;
  published_at: string;
  html_url: string;
  body: string;
  pi_asset: GitHubReleaseAsset | null;
};

export async function fetchLatestWaddleViewRelease(): Promise<WaddleViewReleaseInfo> {
  return bffJson<WaddleViewReleaseInfo>('/releases/waddle-view');
}
