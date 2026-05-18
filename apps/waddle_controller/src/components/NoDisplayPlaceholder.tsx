import { Box, Button, Stack, Typography } from '@mui/material';
import { Link as RouterLink } from 'react-router';
import { WaddleBrandMark } from '@/components/brand/WaddleBrandMark';

export function NoDisplayPlaceholder() {
  return (
    <Box sx={{ maxWidth: 480, mx: 'auto', py: 2, textAlign: 'center' }}>
      <Stack spacing={2} alignItems="center">
        <WaddleBrandMark variant="mascot" size="md" sx={{ mx: 'auto' }} />
        <Typography variant="h6" fontWeight={600}>
          No display adopted yet
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Pair this browser with a display to configure programs, screens, and integrations.
        </Typography>
        <Button component={RouterLink} to="/controller-settings" variant="contained">
          Open display settings
        </Button>
      </Stack>
    </Box>
  );
}
