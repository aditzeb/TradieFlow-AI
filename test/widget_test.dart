import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradieflow_ai/main.dart';
import 'package:tradieflow_ai/services/job_service.dart';
import 'package:tradieflow_ai/theme/glassline_theme.dart';
import 'package:tradieflow_ai/widgets/job_card.dart';

class _OfflineAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<UserCredential> signInAnonymously() async =>
      throw FirebaseAuthException(code: 'network-request-failed');
}

void main() {
  testWidgets('Failed re-authentication locks and clears the previous role', (
    tester,
  ) async {
    final service = JobService(auth: _OfflineAuth());
    service.isReady = true;
    service.isDispatcher = true;
    var notified = false;
    service.addListener(() => notified = true);
    await expectLater(service.signOut(), throwsA(isA<FirebaseAuthException>()));
    expect(notified, isTrue);
    expect(service.isReady, isFalse);
    expect(service.isDispatcher, isFalse);
    await tester.pumpWidget(TradieFlowApp(service: service));
    expect(find.textContaining('Session locked'), findsOneWidget);
    expect(find.text('Active Inbound Queue'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  test('Australian locations and actual image types are validated', () {
    expect(validateSuburb(' '), isNotNull);
    expect(validateSuburb('Balmain'), isNull);
    expect(validateSuburb('Bal\nmain'), isNotNull);
    expect(validatePostcode('2041', 'NSW'), isNull);
    expect(validatePostcode('0800', 'NT'), isNull);
    expect(validatePostcode('2600', 'ACT'), isNull);
    expect(validatePostcode('3000', 'NSW'), isNotNull);
    expect(validatePostcode('800', 'NT'), isNotNull);
    expect(validatePostcode('9999', 'BAD'), isNotNull);
    expect(
      imageContentType(Uint8List.fromList([255, 216, 255, 224])),
      'image/jpeg',
    );
    final png = Uint8List(24);
    png.setAll(0, [137, 80, 78, 71, 13, 10, 26, 10]);
    ByteData.sublistView(png).setUint32(8, 13);
    png.setAll(12, 'IHDR'.codeUnits);
    ByteData.sublistView(png).setUint32(16, 1);
    ByteData.sublistView(png).setUint32(20, 1);
    expect(imageContentType(png), 'image/png');
    final webp = Uint8List(20);
    webp.setAll(0, 'RIFF'.codeUnits);
    ByteData.sublistView(webp).setUint32(4, 12, Endian.little);
    webp.setAll(8, 'WEBPVP8 '.codeUnits);
    expect(imageContentType(webp), 'image/webp');
    expect(
      () => imageContentType(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    expect(
      () => imageContentType(Uint8List(maxImageBytes + 1)),
      throwsFormatException,
    );
    expect(money(120.5), '\$120.50');
    expect(statusLabel('P1_EMERGENCY'), 'P1 · EMERGENCY');
  });

  for (final size in [const Size(375, 812), const Size(1280, 900)]) {
    testWidgets('Responsive workspace and navigation at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const TradieFlowApp());
      await tester.pumpAndSettle();
      expect(find.text('TradieFlow'), findsOneWidget);
      expect(find.textContaining('PREVIEW WORKSPACE'), findsOneWidget);
      if (size.width < 800) {
        expect(
          find.text('A clearer picture.\nA faster response.'),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Open dispatch queue'));
      } else {
        expect(find.text('Active Inbound Queue'), findsOneWidget);
        await tester.tap(find.text('New request'));
        await tester.pumpAndSettle();
        expect(find.text('Instant Trade Triage'), findsOneWidget);
        await tester.tap(find.text('Dispatch'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Active Inbound Queue'), findsOneWidget);
    });
  }

  testWidgets('Preview does not submit or invent live results', (tester) async {
    await tester.pumpWidget(const TradieFlowApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('New request'));
    await tester.pumpAndSettle();
    final button = tester.widget<ElevatedButton>(
      find
          .ancestor(
            of: find.text('Submit for triage'),
            matching: find.byWidgetPredicate(
              (widget) => widget is ElevatedButton,
            ),
          )
          .first,
    );
    expect(button.onPressed, isNull);
    await tester.tap(find.byTooltip('Firebase setup'));
    await tester.pumpAndSettle();
    expect(find.text('Connect Firebase'), findsOneWidget);
    expect(find.textContaining('OPENROUTER_API_KEY'), findsOneWidget);
  });

  testWidgets(
    'Triage result exposes OCR fallback, safety, clarification and itemized quote',
    (tester) async {
      final job = <String, dynamic>{
        'status': 'TRIAGED',
        'customer': {'suburb': 'Balmain', 'state': 'NSW', 'postcode': '2041'},
        'description': 'Not heating',
        'aiAnalysis': {
          'urgency': 'P1_EMERGENCY',
          'urgencyReasoning':
              'Potential electrical fault requires licensed inspection.',
          'hazardIdentified': true,
          'immediateSafetyAction':
              'Keep clear. Call 000 if there is immediate danger.',
          'appliance': {
            'brand': 'Unknown',
            'modelNumber': 'Unreadable',
            'type': 'Water heater',
            'estimatedAgeBracket': 'Unknown',
          },
          'faultDiagnostic': 'Possible supply fault; inspect on site.',
          'recommendedParts': <String>[],
          'estimatedLaborHours': 1.5,
          'quoteAud': {
            'calloutFee': 100,
            'laborCost': 150,
            'partsCost': 0,
            'gst': 25,
            'totalEstimate': 275,
          },
          'dynamicClarification': 'Can you provide a clearer model label?',
        },
      };
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildGlasslineTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: JobCard(job: job, id: 'test1234', expanded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('POTENTIAL HAZARD · URGENT REVIEW'), findsOneWidget);
      expect(find.textContaining('Model: Unreadable'), findsOneWidget);
      expect(find.text('GST (10%)'), findsOneWidget);
      expect(
        find.text('Can you provide a clearer model label?'),
        findsOneWidget,
      );
      expect(find.text('\$275.00 AUD'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Failure state never displays fabricated diagnosis', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGlasslineTheme(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: JobCard(job: {'status': 'TRIAGE_FAILED'}, id: 'failed'),
          ),
        ),
      ),
    );
    expect(find.text('NEEDS ATTENTION'), findsOneWidget);
    expect(
      find.textContaining('Triage could not be completed'),
      findsOneWidget,
    );
    expect(find.text('Assessment & estimate'), findsNothing);
  });
}
