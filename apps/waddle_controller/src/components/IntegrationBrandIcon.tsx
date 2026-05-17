import { useMemo, useState } from 'react';
import { Avatar } from '@mui/material';
import {
  integrationIconImageUrl,
  integrationIconSource,
  integrationMuiIconSource,
} from '@/util/integrationIcon';

type Props = {
  integrationType: string;
  baseUrl?: string | null;
  size?: number;
};

function avatarSx(size: number) {
  return {
    width: size,
    height: size,
    flexShrink: 0,
    bgcolor: 'action.hover',
    '& img': { objectFit: 'contain', p: 0.5 },
  } as const;
}

function MuiAvatar({
  integrationType,
  size,
}: {
  integrationType: string;
  size: number;
}) {
  const source = integrationMuiIconSource(integrationType);
  const Icon = source.Icon;
  return (
    <Avatar sx={avatarSx(size)} aria-hidden>
      <Icon sx={{ fontSize: Math.round(size * 0.55), color: 'action.active' }} />
    </Avatar>
  );
}

/** Brand or family icon for an integration card or dialog header. */
export function IntegrationBrandIcon({ integrationType, baseUrl, size = 40 }: Props) {
  const source = useMemo(
    () => integrationIconSource(integrationType, baseUrl),
    [integrationType, baseUrl],
  );
  const imageUrl = useMemo(() => integrationIconImageUrl(source), [source]);
  const [imageFailed, setImageFailed] = useState(false);

  if (source.kind === 'mui' || imageUrl == null || imageFailed) {
    return <MuiAvatar integrationType={integrationType} size={size} />;
  }

  return (
    <Avatar
      src={imageUrl}
      sx={avatarSx(size)}
      imgProps={{
        alt: '',
        onError: () => setImageFailed(true),
      }}
      aria-hidden
    />
  );
}
