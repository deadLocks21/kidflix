/// Severity of a log record.
///
/// Maps onto the OpenTelemetry `SeverityNumber` scale used by Signoz so
/// the infrastructure adapter doesn't have to invent its own translation:
///
/// | Level   | OTel severityNumber | OTel severityText |
/// |---------|--------------------:|-------------------|
/// | debug   | 5                   | DEBUG             |
/// | info    | 9                   | INFO              |
/// | warn    | 13                  | WARN              |
/// | error   | 17                  | ERROR             |
///
/// Kept intentionally short — Kidflix has no need for `trace`/`fatal`
/// granularity, and adding levels later is a non-breaking change.
enum LogLevel {
  debug(5, 'DEBUG'),
  info(9, 'INFO'),
  warn(13, 'WARN'),
  error(17, 'ERROR');

  const LogLevel(this.otelSeverityNumber, this.otelSeverityText);

  /// OpenTelemetry numeric severity. Used by the OTLP exporter.
  final int otelSeverityNumber;

  /// OpenTelemetry textual severity. Displayed as-is in Signoz UI.
  final String otelSeverityText;
}
