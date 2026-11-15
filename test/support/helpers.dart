import 'package:why_rebuild/why_rebuild.dart';

final WhyRebuild scan = WhyRebuild.instance;

/// First (most rebuilt) call site of [widget], or null when it never rebuilt.
CallSite? site(String widget) {
  final List<CallSite> sites = scan.why(widget).callSites;
  return sites.isEmpty ? null : sites.first;
}

/// The single trigger of [site]; fails when there are several.
String onlyTrigger(CallSite site) => site.triggers.keys.single;
