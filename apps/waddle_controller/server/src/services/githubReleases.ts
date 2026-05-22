const GITHUB_API = 'https://api.github.com';
const REPO = 'dukk/waddle-view';
const PI_TARBALL_RE = /^waddle-view-linux-arm64-.+\.tar\.gz$/;

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

let cache: { atMs: number; data: WaddleViewReleaseInfo } | null = null;
const CACHE_TTL_MS = 5 * 60 * 1000;

function githubHeaders(): Record<string, string> {
  const headers: Record<string, string> = {
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'waddle-controller-bff',
  };
  const token = process.env.GITHUB_TOKEN?.trim() || process.env.GH_TOKEN?.trim();
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }
  return headers;
}

export function pickPiTarballAsset(
  assets: { name?: string; browser_download_url?: string; size?: number }[],
): GitHubReleaseAsset | null {
  for (const asset of assets) {
    const name = asset.name ?? '';
    if (PI_TARBALL_RE.test(name) && typeof asset.browser_download_url === 'string') {
      return {
        name,
        browser_download_url: asset.browser_download_url,
        size: typeof asset.size === 'number' ? asset.size : 0,
      };
    }
  }
  return null;
}

export async function fetchLatestWaddleViewRelease(
  force = false,
): Promise<WaddleViewReleaseInfo> {
  const now = Date.now();
  if (!force && cache && now - cache.atMs < CACHE_TTL_MS) {
    return cache.data;
  }
  const res = await fetch(`${GITHUB_API}/repos/${REPO}/releases/latest`, {
    headers: githubHeaders(),
  });
  if (!res.ok) {
    throw new Error(`GitHub releases API ${res.status}: ${await res.text()}`);
  }
  const json = (await res.json()) as {
    tag_name?: string;
    name?: string;
    published_at?: string;
    html_url?: string;
    body?: string;
    assets?: { name?: string; browser_download_url?: string; size?: number }[];
  };
  const data: WaddleViewReleaseInfo = {
    tag_name: json.tag_name ?? '',
    name: json.name ?? json.tag_name ?? '',
    published_at: json.published_at ?? '',
    html_url: json.html_url ?? `https://github.com/${REPO}/releases/latest`,
    body: json.body ?? '',
    pi_asset: pickPiTarballAsset(json.assets ?? []),
  };
  cache = { atMs: now, data };
  return data;
}

export function clearReleaseCacheForTests(): void {
  cache = null;
}
