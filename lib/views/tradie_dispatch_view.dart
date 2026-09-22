import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/job_service.dart';
import '../theme/glassline_tokens.dart';
import '../widgets/job_card.dart';

class TradieDispatchView extends StatefulWidget {
  const TradieDispatchView({
    super.key,
    this.service,
    required this.onNewRequest,
  });
  final JobService? service;
  final VoidCallback onNewRequest;

  @override
  State<TradieDispatchView> createState() => _TradieDispatchViewState();
}

class _TradieDispatchViewState extends State<TradieDispatchView> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;
  String _filter = 'All requests';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _stream = widget.service?.watchJobs();
  }

  void _reload() => setState(() => _stream = widget.service?.watchJobs());

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 24,
                runSpacing: 20,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DISPATCH CONTROL // ${widget.service?.isDispatcher == true ? 'TEAM WORKSPACE' : 'YOUR WORKSPACE'}',
                        style: text.labelSmall,
                      ),
                      const SizedBox(height: 12),
                      Text('Active Inbound Queue', style: text.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Less guesswork. Better prepared for the next job.',
                        style: text.bodyMedium?.copyWith(
                          color: GlasslineColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: widget.onNewRequest,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New request'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _stream,
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  final jobs = docs.map((doc) => doc.data()).toList();
                  final pending = jobs
                      .where(
                        (job) =>
                            ['RECEIVED', 'ANALYZING'].contains(job['status']),
                      )
                      .length;
                  final urgent = jobs
                      .where(
                        (job) =>
                            (job['aiAnalysis'] as Map?)?['urgency'] ==
                            'P1_EMERGENCY',
                      )
                      .length;
                  final triaged = jobs
                      .where((job) => job['status'] == 'TRIAGED')
                      .length;
                  final filtered = docs.where((doc) {
                    final job = doc.data();
                    final ai = job['aiAnalysis'] as Map?;
                    final status = job['status'];
                    final matchesFilter = switch (_filter) {
                      'Analyzing' =>
                        status == 'RECEIVED' || status == 'ANALYZING',
                      'Triaged' => status == 'TRIAGED',
                      'Emergency' => ai?['urgency'] == 'P1_EMERGENCY',
                      'Needs attention' => status == 'TRIAGE_FAILED',
                      _ => true,
                    };
                    final customer = job['customer'] as Map?;
                    final appliance = ai?['appliance'] as Map?;
                    final searchable =
                        '${doc.id} ${customer?['suburb']} ${customer?['postcode']} ${appliance?['brand']} ${appliance?['type']}'
                            .toLowerCase();
                    return matchesFilter &&
                        searchable.contains(_search.toLowerCase());
                  }).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth < 650 ? 2 : 4;
                          final width =
                              (constraints.maxWidth - (columns - 1) * 16) /
                              columns;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              for (final stat in [
                                (
                                  'INBOUND REQUESTS',
                                  docs.length,
                                  Icons.inbox_outlined,
                                ),
                                (
                                  'AWAITING TRIAGE',
                                  pending,
                                  Icons.hourglass_empty,
                                ),
                                (
                                  'EMERGENCY REVIEW',
                                  urgent,
                                  Icons.priority_high,
                                ),
                                ('ASSESSMENTS READY', triaged, Icons.task_alt),
                              ])
                                SizedBox(
                                  width: width,
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            stat.$3,
                                            size: 20,
                                            color: GlasslineColors.secondary,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            snapshot.hasData
                                                ? '${stat.$2}'.padLeft(2, '0')
                                                : '—',
                                            style: text.headlineMedium,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(stat.$1, style: text.labelSmall),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 16,
                                runSpacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  MonoBadge(
                                    widget.service == null
                                        ? 'PREVIEW · NOT CONNECTED'
                                        : snapshot.hasError
                                        ? 'FEED UNAVAILABLE'
                                        : !snapshot.hasData
                                        ? 'CONNECTING'
                                        : snapshot.data!.metadata.isFromCache
                                        ? 'CACHED · RECONNECTING'
                                        : 'LIVE DISPATCH FEED',
                                  ),
                                  Text(
                                    'SYDNEY, NSW · DISPATCH REGION',
                                    style: text.labelSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Search requests',
                                  hintText:
                                      'Suburb, postcode, appliance or reference',
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (value) =>
                                    setState(() => _search = value.trim()),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final filter in [
                                    'All requests',
                                    'Analyzing',
                                    'Triaged',
                                    'Emergency',
                                    'Needs attention',
                                  ])
                                    ChoiceChip(
                                      label: Text(filter),
                                      selected: _filter == filter,
                                      selectedColor: GlasslineColors.primary,
                                      backgroundColor: Colors.white,
                                      labelStyle: TextStyle(
                                        color: _filter == filter
                                            ? Colors.white
                                            : GlasslineColors.secondary,
                                        fontSize: 13,
                                      ),
                                      showCheckmark: false,
                                      onSelected: (_) =>
                                          setState(() => _filter = filter),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (snapshot.hasError)
                        _empty(
                          context,
                          Icons.cloud_off_outlined,
                          'The live feed is unavailable',
                          'Check your connection and server access. Your existing requests have not been changed.',
                          retry: true,
                        )
                      else if (widget.service == null)
                        _empty(
                          context,
                          Icons.link_off,
                          'Connect your workspace',
                          'Live services are not configured. Preview the intake form or configure your backend to start receiving real requests.',
                        )
                      else if (!snapshot.hasData)
                        const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (filtered.isEmpty)
                        _empty(
                          context,
                          Icons.inbox_outlined,
                          docs.isEmpty
                              ? 'A clear queue. Ready for what’s next.'
                              : 'No matching requests',
                          docs.isEmpty
                              ? 'Submitted requests will appear here automatically. Start a new request to triage your first appliance.'
                              : 'Try another suburb, appliance, or status filter.',
                        )
                      else
                        for (final doc in filtered)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: JobCard(
                              key: ValueKey(doc.id),
                              job: doc.data(),
                              id: doc.id,
                            ),
                          ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 24,
                        runSpacing: 8,
                        children: [
                          Text(
                            'LATEST 100 REQUESTS · ${widget.service?.isDispatcher == true ? 'TEAM VIEW' : 'PRIVATE TO YOUR SESSION'}',
                            style: text.labelSmall,
                          ),
                          Text(
                            'AI advisory only. Licensed review required.',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(
    BuildContext context,
    IconData icon,
    String title,
    String message, {
    bool retry = false,
  }) => SizedBox(
    width: double.infinity,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          children: [
            Icon(icon, size: 36, color: GlasslineColors.secondary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (retry) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Reconnect'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
