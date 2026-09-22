import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';
import 'services/job_service.dart';
import 'theme/glassline_theme.dart';
import 'theme/glassline_tokens.dart';
import 'views/customer_intake_view.dart';
import 'views/tradie_dispatch_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Startup());
}

class _Startup extends StatefulWidget {
  const _Startup();

  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  JobService? _service;
  bool _loading = DefaultFirebaseOptions.isConfigured;
  bool _failed = false;
  bool _emulatorsConnected = false;

  @override
  void initState() {
    super.initState();
    if (_loading) _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: false,
        );
      }
      if (DefaultFirebaseOptions.useEmulators && !_emulatorsConnected) {
        final host = DefaultFirebaseOptions.emulatorHost;
        await FirebaseAuth.instance.useAuthEmulator(host, 9099);
        FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
        await FirebaseStorage.instance.useStorageEmulator(host, 9199);
        _emulatorsConnected = true;
      }
      _service ??= JobService();
      await _service!.initialize();
    } catch (_) {
      _failed = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _service?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && !_failed) return TradieFlowApp(service: _service);
    return MaterialApp(
      title: 'TradieFlow AI',
      debugShowCheckedModeBanner: false,
      theme: buildGlasslineTheme(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.handyman_outlined, size: 40),
                  const SizedBox(height: 24),
                  const Text(
                    'TradieFlow AI',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  if (_loading) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Connecting your workspace…'),
                  ] else ...[
                    const Text(
                      'Connection unavailable',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check your connection, Firebase web configuration, and that anonymous authentication is enabled. No request has been submitted.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _connect,
                      child: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TradieFlowApp extends StatelessWidget {
  const TradieFlowApp({super.key, this.service});
  final JobService? service;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TradieFlow AI',
    debugShowCheckedModeBanner: false,
    theme: buildGlasslineTheme(),
    home: service == null
        ? const _Workspace()
        : ListenableBuilder(
            listenable: service!,
            builder: (context, _) => service!.isReady
                ? _Workspace(
                    key: ValueKey('${service!.uid}:${service!.isDispatcher}'),
                    service: service,
                  )
                : const Scaffold(
                    body: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Session locked. If reconnection does not complete, reload this page. Previous customer data has been cleared from view.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
          ),
  );
}

class _Workspace extends StatefulWidget {
  const _Workspace({super.key, this.service});
  final JobService? service;

  @override
  State<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<_Workspace> {
  bool? _intake;
  bool _signingOut = false;

  void _configuration() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Connect Firebase'),
      content: const SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: SelectionArea(
            child: Text(
              'This is a UI preview. No sample requests or AI results are presented as real.\n\n'
              'Register a web app in the tradieflow-ai Firebase project and enable Anonymous authentication. Pass the web app values at build time:\n\n'
              'flutter run -d chrome --dart-define=FIREBASE_API_KEY=<web-api-key> --dart-define=FIREBASE_APP_ID=<web-app-id>\n\n'
              'For local emulators:\nflutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true\n\n'
              'Deploy the included security rules, indexes, and Sydney Cloud Function. Store OPENROUTER_API_KEY in Firebase Secret Manager, never in the Flutter app.\n\n'
              'Team dispatch access requires an Email/Password account with the dispatcher custom claim set to true by a trusted administrator. Other accounts can only read their own requests.',
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  void _aboutExoDigital(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(28),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/ExoLogo_web.png',
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TradieFlow AI',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: GlasslineColors.primary.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BY EXO DIGITAL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: GlasslineColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'v1.0.0',
                            style: TextStyle(
                              fontSize: 12,
                              color: GlasslineColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Intelligent Australian trade intake, automated damage classification, safety triage, and real-time dispatcher dispatch.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: GlasslineColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Engineered by Exo Digital, delivering industry-leading digital product design, AI solutions, and engineering excellence.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: GlasslineColors.secondary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse('https://www.exodigital.com.au/'),
                  mode: LaunchMode.platformDefault,
                ),
                icon: const Icon(Icons.language, size: 18),
                label: const Text('Visit exodigital.com.au'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await widget.service!.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Session could not be refreshed. Reload to reconnect.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final intake = _intake ?? constraints.maxWidth < 800;
      final compact = constraints.maxWidth < 600;
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 80,
          titleSpacing: compact ? 16 : 32,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: GlasslineColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.handyman_outlined,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  'TradieFlow',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                Text('AI', style: Theme.of(context).textTheme.labelSmall),
              ],
            ],
          ),
          actions: [
            if (!compact) ...[
              TextButton.icon(
                onPressed: () => setState(() => _intake = false),
                icon: const Icon(Icons.dashboard_outlined, size: 18),
                label: const Text('Dispatch'),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _intake = true),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Intake'),
              ),
            ] else
              IconButton(
                tooltip: intake ? 'Open dispatch queue' : 'Open intake form',
                onPressed: () => setState(() => _intake = !intake),
                icon: Icon(
                  intake ? Icons.dashboard_outlined : Icons.add_circle_outline,
                ),
              ),
            IconButton(
              tooltip: 'About Exo Digital',
              onPressed: () => _aboutExoDigital(context),
              icon: const Icon(Icons.info_outline),
            ),
            if (widget.service == null)
              IconButton(
                tooltip: 'Firebase setup',
                onPressed: _configuration,
                icon: const Icon(Icons.settings_outlined),
              )
            else if (widget.service!.isAnonymous)
              IconButton(
                tooltip: 'Dispatcher sign in',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _SignInDialog(service: widget.service!),
                ),
                icon: const Icon(Icons.person_outline),
              )
            else
              PopupMenuButton<String>(
                tooltip: 'Account',
                enabled: !_signingOut,
                icon: const Icon(Icons.account_circle_outlined),
                onSelected: (_) => _signOut(),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'out', child: Text('Sign out')),
                ],
              ),
            SizedBox(width: compact ? 8 : 24),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (widget.service == null)
                Container(
                  width: double.infinity,
                  color: GlasslineColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      const Text(
                        'PREVIEW WORKSPACE · FIREBASE NOT CONNECTED',
                        style: TextStyle(
                          fontFamily: 'Geist Mono',
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      TextButton(
                        onPressed: _configuration,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Setup instructions'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: IndexedStack(
                  index: intake ? 0 : 1,
                  children: [
                    CustomerIntakeView(service: widget.service),
                    TradieDispatchView(
                      service: widget.service,
                      onNewRequest: () => setState(() => _intake = true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SignInDialog extends StatefulWidget {
  const _SignInDialog({required this.service});
  final JobService service;

  @override
  State<_SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<_SignInDialog> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.signIn(_email.text, _password.text);
      if (mounted) {
        if (widget.service.isDispatcher) {
          Navigator.pop(context);
        } else {
          setState(
            () => _error =
                'Signed in with personal access only. Ask your administrator to grant the dispatcher claim, then sign in again.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to sign in. Check your credentials, connection, and enabled sign-in provider.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Dispatcher sign in'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: AutofillGroup(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Use your administrator-provisioned account. Signing in leaves the anonymous customer session; its requests are only visible to authorized dispatchers.',
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) => value?.contains('@') == true
                        ? null
                        : 'Enter your email.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) => value?.isNotEmpty == true
                        ? null
                        : 'Enter your password.',
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Semantics(liveRegion: true, child: Text(_error!)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Signing in…' : 'Sign in'),
        ),
      ],
    ),
  );
}
