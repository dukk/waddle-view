enum AlertSeverity { info, warning, critical }

class AlertCreateRequest {
  const AlertCreateRequest({
    required this.title,
    required this.body,
    this.severity = AlertSeverity.warning,
    this.priority = 10,
  });

  final String title;
  final String body;
  final AlertSeverity severity;
  final int priority;

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'severity': severity.name,
        'priority': priority,
      };
}
