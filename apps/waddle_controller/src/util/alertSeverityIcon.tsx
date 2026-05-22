import type { SvgIconComponent } from '@mui/icons-material';
import ErrorOutline from '@mui/icons-material/ErrorOutline';
import InfoOutlined from '@mui/icons-material/InfoOutlined';
import LockOutlined from '@mui/icons-material/LockOutlined';
import ReportProblemOutlined from '@mui/icons-material/ReportProblemOutlined';
import SecurityOutlined from '@mui/icons-material/SecurityOutlined';
import WarningAmberRounded from '@mui/icons-material/WarningAmberRounded';

/** Defaults aligned with waddle_shared alert_severity_icons_kv. */
const SEVERITY_ICON_BY_KEY: Record<string, SvgIconComponent> = {
  info: InfoOutlined,
  auth: LockOutlined,
  security: SecurityOutlined,
  warning: WarningAmberRounded,
  error: ErrorOutline,
  critical: ReportProblemOutlined,
};

export function alertSeverityIconComponent(
  severity: string | null | undefined,
): SvgIconComponent {
  const key = (severity ?? '').trim().toLowerCase();
  return SEVERITY_ICON_BY_KEY[key] ?? InfoOutlined;
}
