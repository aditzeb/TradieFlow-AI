import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/glassline_tokens.dart';
import '../widgets/job_card.dart';

class LandingPageView extends StatelessWidget {
  const LandingPageView({
    super.key,
    required this.onStartTriage,
    required this.onOpenDispatch,
  });

  final VoidCallback onStartTriage;
  final VoidCallback onOpenDispatch;

  Future<void> _openExoWebsite() async {
    await launchUrl(
      Uri.parse('https://www.exodigital.com.au/'),
      mode: LaunchMode.platformDefault,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 768;
    final isMobile = width < 500;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : (isCompact ? 24 : 48),
        vertical: isMobile ? 24 : 40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Badge
              Align(
                alignment: isCompact ? Alignment.center : Alignment.centerLeft,
                child: InkWell(
                  onTap: _openExoWebsite,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: GlasslineColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset(
                              'assets/images/ExoLogo_web_v2.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            isMobile
                                ? 'BY EXO DIGITAL · AUSTRALIA'
                                : 'ENGINEERED BY EXO DIGITAL · AUSTRALIA',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Geist Mono',
                              fontSize: isMobile ? 10 : 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: GlasslineColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_outward,
                          size: 13,
                          color: GlasslineColors.secondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Hero Headline & Subtitle
              Wrap(
                alignment: isCompact ? WrapAlignment.center : WrapAlignment.start,
                children: [
                  Text(
                    'Snap a photo.\nGet instant AI trade triage.',
                    textAlign: isCompact ? TextAlign.center : TextAlign.left,
                    style: TextStyle(
                      fontSize: isMobile ? 32 : (isCompact ? 42 : 54),
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.8,
                      height: 1.1,
                      color: GlasslineColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'TradieFlow AI empowers Australian homeowners, facility managers, and licensed trades with instant visual triage, automatic model plate OCR, AS/NZS hazard verification, and itemized AUD quotes — eliminating wasted site visits.',
                textAlign: isCompact ? TextAlign.center : TextAlign.left,
                style: TextStyle(
                  fontSize: isMobile ? 15 : 18,
                  height: 1.55,
                  color: GlasslineColors.secondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 32),

              // Hero CTA Buttons
              Wrap(
                alignment: isCompact ? WrapAlignment.center : WrapAlignment.start,
                spacing: 16,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: onStartTriage,
                    icon: const Icon(Icons.camera_alt_outlined, size: 20),
                    label: const Text(
                      'Start Customer Triage',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlasslineColors.tertiary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 18,
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenDispatch,
                    icon: const Icon(Icons.dashboard_outlined, size: 20),
                    label: const Text(
                      'Tradie Dispatch Portal',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GlasslineColors.primary,
                      side: const BorderSide(color: GlasslineColors.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 18,
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Trust Metrics Row
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: GlasslineColors.secondary.withValues(alpha: 0.12),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceAround,
                  runSpacing: 20,
                  spacing: 24,
                  children: [
                    _metricItem('< 30s', 'Triage turnaround', Icons.bolt),
                    _metricItem('AS/NZS', 'Standards verified', Icons.shield_outlined),
                    _metricItem('100% AUD', 'Itemized estimates', Icons.receipt_long_outlined),
                    _metricItem('Zero-Login', 'Customer upload', Icons.lock_open_outlined),
                  ],
                ),
              ),
              const SizedBox(height: 64),

              // Interactive Product Preview / Walkthrough
              Text(
                'LIVE TRIAGE SIMULATION',
                style: TextStyle(
                  fontFamily: 'Geist Mono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: GlasslineColors.secondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'From raw photo to structured job scope',
                style: TextStyle(
                  fontSize: isMobile ? 24 : 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  color: GlasslineColors.primary,
                ),
              ),
              const SizedBox(height: 20),

              // Side-by-side or stacked preview cards
              if (width >= 960)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _sampleCustomerCard(theme)),
                    const SizedBox(width: 16),
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Icon(Icons.arrow_forward, size: 24, color: GlasslineColors.tertiary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: _sampleTriageResultCard(theme)),
                  ],
                )
              else
                Column(
                  children: [
                    _sampleCustomerCard(theme),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Icon(Icons.arrow_downward, size: 28, color: GlasslineColors.tertiary),
                    ),
                    _sampleTriageResultCard(theme),
                  ],
                ),
              const SizedBox(height: 64),

              // How It Works (3 Steps)
              Text(
                'SIMPLE 3-STEP PROCESS',
                style: TextStyle(
                  fontFamily: 'Geist Mono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: GlasslineColors.secondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'How TradieFlow AI accelerates every job',
                style: TextStyle(
                  fontSize: isMobile ? 24 : 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  color: GlasslineColors.primary,
                ),
              ),
              const SizedBox(height: 24),

              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  _stepCard(
                    number: '01',
                    title: 'Customer Snaps a Photo',
                    description:
                        'The homeowner or building manager uploads a photo of the appliance or issue. No account registration, friction, or app store download needed.',
                    icon: Icons.add_a_photo_outlined,
                  ),
                  _stepCard(
                    number: '02',
                    title: 'Vision AI Analyzes & Triage',
                    description:
                        'Gemini 2.0 Flash inspects the image, reads the manufacturer model plate (OCR), checks AS/NZS safety codes, and prepares a parts checklist.',
                    icon: Icons.psychology_outlined,
                  ),
                  _stepCard(
                    number: '03',
                    title: 'Tradies Arrive Prepared',
                    description:
                        'Dispatchers route the pre-triaged job to technicians who arrive on site with the exact replacement components in their vehicle.',
                    icon: Icons.local_shipping_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 64),

              // Key Features Grid
              Text(
                'BUILT FOR AUSTRALIAN TRADES',
                style: TextStyle(
                  fontFamily: 'Geist Mono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: GlasslineColors.secondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Core capabilities designed for real job sites',
                style: TextStyle(
                  fontSize: isMobile ? 24 : 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  color: GlasslineColors.primary,
                ),
              ),
              const SizedBox(height: 24),

              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  _featureCard(
                    icon: Icons.document_scanner_outlined,
                    title: 'Model Plate OCR',
                    description:
                        'Automatically extracts make, model numbers, and serial tags from weathered, rusted, or poorly lit compliance plates.',
                  ),
                  _featureCard(
                    icon: Icons.warning_amber_outlined,
                    title: 'AS/NZS Hazard Verification',
                    description:
                        'Flags electrical, gas, and plumbing risks against AS/NZS 3000 & 3500 rules. Keeps customers clear and protected.',
                  ),
                  _featureCard(
                    icon: Icons.attach_money_outlined,
                    title: 'Transparent AUD Quotes',
                    description:
                        'Calculates callout fees, labor hours, estimated parts, and exact 10% Australian GST for instant customer clarity.',
                  ),
                  _featureCard(
                    icon: Icons.sync_outlined,
                    title: 'Real-time Dispatch Queue',
                    description:
                        'Incoming jobs stream live to dispatchers via Firebase Firestore with urgency filtering and status tracking.',
                  ),
                ],
              ),
              const SizedBox(height: 64),

              // Exo Digital Spotlight Card
              Container(
                padding: EdgeInsets.all(isMobile ? 24 : 40),
                decoration: BoxDecoration(
                  color: GlasslineColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/images/ExoLogo_web_v2.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Engineered by Exo Digital',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              Text(
                                'www.exodigital.com.au',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Exo Digital is a premier Australian digital product, AI architecture, and engineering consultancy. We partner with ambitious organizations to transform complex workflows into elegant, automated software products.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _openExoWebsite,
                      icon: const Icon(Icons.language, size: 18),
                      label: const Text('Discover Exo Digital Solutions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: GlasslineColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 64),

              // Bottom CTA Section
              Container(
                padding: EdgeInsets.all(isMobile ? 28 : 48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: GlasslineColors.secondary.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Ready to experience intelligent triage?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 26 : 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                        color: GlasslineColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Submit a sample photo and get an immediate diagnostic assessment and quote estimate.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: GlasslineColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: onStartTriage,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Start Triage Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GlasslineColors.tertiary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: onOpenDispatch,
                          icon: const Icon(Icons.login),
                          label: const Text('Dispatcher Console'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: GlasslineColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Footer
              Center(
                child: Column(
                  children: [
                    Text(
                      'TradieFlow AI · An Exo Digital Innovation',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: GlasslineColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Advisory triage tool only. Certified compliance requires a licensed professional on site. In emergencies, call 000.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: GlasslineColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricItem(String title, String subtitle, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: GlasslineColors.tertiary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: GlasslineColors.tertiary, size: 22),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: GlasslineColors.primary,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: GlasslineColors.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sampleCustomerCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                const MonoBadge('CUSTOMER INPUT'),
                Text('Balmain NSW 2041', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: GlasslineColors.neutral,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: GlasslineColors.secondary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.photo_camera_back_outlined, size: 36, color: GlasslineColors.secondary),
                  SizedBox(height: 8),
                  Text(
                    'photo_rheem_stellar.jpg',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text('4.2 MB · Water Heater Label', style: TextStyle(fontSize: 11, color: GlasslineColors.secondary)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Observed symptoms:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '"Hot water system stopped heating overnight. Water pooling around relief valve, pilot light extinguished."',
              style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sampleTriageResultCard(ThemeData theme) {
    final sampleJob = <String, dynamic>{
      'status': 'TRIAGED',
      'customer': {'suburb': 'Balmain', 'state': 'NSW', 'postcode': '2041'},
      'description': 'Hot water system stopped heating overnight.',
      'aiAnalysis': {
        'urgency': 'P1_EMERGENCY',
        'urgencyReasoning':
            'Active water discharge with unlit gas burner requires prompt licensed inspection under AS/NZS 3500 & 5601.',
        'hazardIdentified': true,
        'immediateSafetyAction':
            'Keep occupants clear. Isolate gas control valve if odor persists. Do not attempt manual relight.',
        'appliance': {
          'brand': 'Rheem',
          'modelNumber': 'Stellar 330',
          'type': 'Gas Storage Water Heater',
          'estimatedAgeBracket': '5–10 years',
        },
        'faultDiagnostic':
            'Likely TPR valve seat degradation or thermocouple junction failure. Recommend valve replacement and burner check.',
        'recommendedParts': ['TPR Valve (1400 kPa)', 'Thermocouple Lead'],
        'estimatedLaborHours': 1.5,
        'quoteAud': {
          'calloutFee': 110.0,
          'laborCost': 165.0,
          'partsCost': 85.0,
          'gst': 36.0,
          'totalEstimate': 396.0,
        },
        'dynamicClarification': 'Check if gas meter valve is open or if any gas odor is detectable.',
      },
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                const MonoBadge('AI TRIAGE OUTPUT'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: GlasslineColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'P1 · URGENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            JobCard(job: sampleJob, id: 'SAMPLE-101', expanded: true),
          ],
        ),
      ),
    );
  }

  Widget _stepCard({
    required String number,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 350),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  MonoBadge(number),
                  Icon(icon, color: GlasslineColors.tertiary, size: 24),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: GlasslineColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: GlasslineColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 540),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GlasslineColors.tertiary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: GlasslineColors.tertiary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: GlasslineColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: GlasslineColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
