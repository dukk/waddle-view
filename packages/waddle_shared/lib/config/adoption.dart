/// Alert [Alerts.source] value for REST adoption challenges.
const String kAdoptionAlertSource = 'adoption';

/// Pending adoption challenge lifetime.
const int kAdoptionChallengeTtlMs = 5 * 60 * 1000;

/// When `'false'`, new adoption challenges from other controllers are rejected.
/// Admin instant grant (`Authorization: Bearer` on `/v1/adoption/request`) still works.
///
/// Superseded by [kAdoptionAllowedRolesKvKey] when that key is present; kept in sync on PUT.
const String kAdoptionAllowNewRequestsKvKey = 'adoption.allow_new_requests';

/// JSON array of role ids (`viewer`, `power_viewer`, `operator`, `admin`) allowed to
/// start adoption challenges. Empty array rejects all public requests.
const String kAdoptionAllowedRolesKvKey = 'adoption.allowed_roles';
