import { Accordion, AccordionDetails, AccordionSummary, Typography } from '@mui/material';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';

export function LicenseNoticesPanel({
  title,
  text,
  defaultExpanded = false,
}: {
  title: string;
  text: string;
  defaultExpanded?: boolean;
}) {
  const trimmed = text.trim();
  if (!trimmed) return null;

  return (
    <Accordion defaultExpanded={defaultExpanded} disableGutters variant="outlined">
      <AccordionSummary expandIcon={<ExpandMoreIcon />}>
        <Typography fontWeight={600}>{title}</Typography>
      </AccordionSummary>
      <AccordionDetails>
        <Typography
          component="pre"
          variant="body2"
          sx={{
            whiteSpace: 'pre-wrap',
            fontFamily: 'monospace',
            fontSize: '0.75rem',
            maxHeight: 360,
            overflow: 'auto',
            m: 0,
          }}
        >
          {trimmed}
        </Typography>
      </AccordionDetails>
    </Accordion>
  );
}
