import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ppn/providers/auth_provider.dart';
import 'package:ppn/services/supabase_service.dart';
import 'package:ppn/providers/lead_provider.dart';

/// Provider that exposes company-scoped SLA tracking statistics.
///
/// It watches the [leadProvider] to automatically trigger cache invalidation and
/// reload metrics whenever leads are created, deleted, or stages are updated.
final slaStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authProvider);
  final companyId = authState.profile?.companyId;
  if (companyId == null) {
    return {
      'total_leads': 0,
      'compliant_leads': 0,
      'compliance_rate': 100.0,
      'avg_response_time_seconds': 0.0,
      'overdue_leads': [],
      'agent_breakdown': [],
    };
  }

  // Reload statistics whenever the lead records change
  ref.watch(leadProvider);

  final service = ref.watch(supabaseServiceProvider);
  return service.getCompanySlaStats(companyId);
});
