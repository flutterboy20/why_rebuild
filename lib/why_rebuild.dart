/// Tells you, and your AI coding agent, **why** each widget rebuilt, whether
/// the rebuild was wasted, and how to fix it.
///
/// ```dart
/// void main() {
///   WidgetsFlutterBinding.ensureInitialized();
///   WhyRebuild.instance.install(); // debug-only; no-op elsewhere
///   runApp(const MyApp());
/// }
/// ```
///
/// Query results with [WhyRebuild.report] and [WhyRebuild.why], or over the
/// VM service: `ext.why_rebuild.status`, `record`, `report`, `why`, `reset`,
/// `pause`, `resume`.
library;

export 'src/model/cause.dart' show CauseKind;
export 'src/model/report.dart'
    show
        CallSite,
        RebuildReport,
        RebuildSite,
        ScanState,
        ScanStatus,
        WastedReport,
        WhyReport;
export 'src/scanner.dart' show WhyRebuild;
