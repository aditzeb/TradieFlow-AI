import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/glassline_tokens.dart';

String money(Object? value) =>
    value is num ? '\$${value.toStringAsFixed(2)}' : '—';

String statusLabel(String status) => switch (status) {
  'RECEIVED' => 'RECEIVED',
  'ANALYZING' => 'ANALYZING',
  'TRIAGED' => 'TRIAGED',
  'TRIAGE_FAILED' => 'NEEDS ATTENTION',
  'P1_EMERGENCY' => 'P1 · EMERGENCY',
  'P2_SAME_DAY' => 'P2 · SAME DAY',
  'P3_ROUTINE' => 'P3 · ROUTINE',
  _ => 'AWAITING UPDATE',
};

class MonoBadge extends StatelessWidget {
  const MonoBadge(this.label, {super.key, this.dark = false});
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: dark ? GlasslineColors.primary : GlasslineColors.neutral,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: dark ? Colors.white : GlasslineColors.primary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.job,
    required this.id,
    this.expanded = false,
  });
  final Map<String, dynamic> job;
  final String id;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final customer = job['customer'] as Map<String, dynamic>? ?? {};
    final ai = job['aiAnalysis'] as Map<String, dynamic>?;
    final appliance = ai?['appliance'] as Map<String, dynamic>? ?? {};
    final quote = ai?['quoteAud'] as Map<String, dynamic>? ?? {};
    final status = job['status'] as String? ?? 'RECEIVED';
    final failed = status == 'TRIAGE_FAILED';
    final pending = status == 'RECEIVED' || status == 'ANALYZING';
    final timestamp = job['createdAt'];
    final created = timestamp is Timestamp
        ? timestamp.toDate().toLocal()
        : null;
    final urgency = ai?['urgency'] as String? ?? status;
    final hazard = ai?['hazardIdentified'] == true;
    final reference = id.length > 8
        ? id.substring(0, 8).toUpperCase()
        : id.toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                MonoBadge(
                  statusLabel(urgency),
                  dark: urgency == 'P1_EMERGENCY',
                ),
                Text('TF–$reference', style: text.labelSmall),
                if (created != null)
                  Text(
                    '${created.day}/${created.month}/${created.year} · ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}',
                    style: text.labelSmall,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${customer['suburb'] ?? 'Location pending'} · ${customer['state'] ?? ''} ${customer['postcode'] ?? ''}',
                  style: text.titleLarge,
                ),
                if (ai != null)
                  Text(
                    '${money(quote['totalEstimate'])} AUD',
                    style: text.titleLarge,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (ai != null) ...[
              Text(
                '${appliance['brand']} / ${appliance['type']}',
                style: text.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                ai['faultDiagnostic'] as String? ?? 'Assessment unavailable.',
              ),
            ] else ...[
              Text(
                failed
                    ? (job['error'] as String? ??
                          'Triage could not be completed. Submit a new request or contact a licensed tradesperson.')
                    : status == 'ANALYZING'
                    ? 'Reading the appliance label and assessing your issue. This usually takes about a minute.'
                    : 'Your request is queued for analysis. No action is needed.',
                style: text.bodyMedium,
              ),
              if (pending) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 12),
                Text(
                  'If this remains unchanged for several minutes, contact a licensed tradesperson. Do not wait for AI in an emergency.',
                  style: text.bodySmall,
                ),
              ],
              if ((job['description'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(job['description'] as String, style: text.bodySmall),
              ],
            ],
            if (hazard || urgency == 'P1_EMERGENCY') ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: GlasslineColors.neutral,
                  border: Border.all(color: GlasslineColors.primary),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'POTENTIAL HAZARD · URGENT REVIEW',
                      style: text.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ai?['immediateSafetyAction'] as String? ??
                          'Keep clear. Contact a licensed tradesperson urgently. Call 000 if there is immediate danger.',
                    ),
                  ],
                ),
              ),
            ],
            if (ai != null) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                initiallyExpanded: expanded,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                shape: const Border(),
                collapsedShape: const Border(),
                title: const Text('Assessment & estimate'),
                subtitle: Text(
                  'AI advisory · professional review required',
                  style: text.bodySmall,
                ),
                children: [
                  _section(
                    context,
                    'URGENCY REASONING',
                    ai['urgencyReasoning'],
                  ),
                  _section(
                    context,
                    'APPLIANCE LABEL',
                    'Brand: ${appliance['brand']}\nModel: ${appliance['modelNumber']}\nEstimated age: ${appliance['estimatedAgeBracket']}',
                  ),
                  _section(
                    context,
                    'SUGGESTED PARTS',
                    (ai['recommendedParts'] as List?)?.isNotEmpty == true
                        ? (ai['recommendedParts'] as List).join(' · ')
                        : 'No parts confirmed. Verify on site.',
                  ),
                  _section(
                    context,
                    'ESTIMATED LABOUR',
                    '${ai['estimatedLaborHours']} hours',
                  ),
                  _section(
                    context,
                    'CUSTOMER DESCRIPTION',
                    (job['description'] as String? ?? '').isEmpty
                        ? 'Not provided.'
                        : job['description'],
                  ),
                  const Divider(height: 24),
                  for (final item in [
                    ('Callout', 'calloutFee'),
                    ('Labour', 'laborCost'),
                    ('Parts', 'partsCost'),
                    ('GST (10%)', 'gst'),
                    ('Estimated total · AUD', 'totalEstimate'),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.$1,
                              style: item.$2 == 'totalEstimate'
                                  ? const TextStyle(fontWeight: FontWeight.w600)
                                  : text.bodySmall,
                            ),
                          ),
                          Text(
                            money(quote[item.$2]),
                            style: const TextStyle(fontFamily: 'Geist Mono'),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 24),
                  _section(
                    context,
                    'FOLLOW-UP QUESTION',
                    ai['dynamicClarification'],
                  ),
                  if (!hazard && urgency != 'P1_EMERGENCY')
                    _section(
                      context,
                      'SAFETY GUIDANCE',
                      ai['immediateSafetyAction'],
                    ),
                  Text(
                    'Photo-based guidance cannot certify AS/NZS compliance or establish safety. Estimates are indicative, include GST, and must be confirmed by a licensed professional.',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String label, Object? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          Text(value?.toString() ?? 'Not available'),
        ],
      ),
    ),
  );
}
