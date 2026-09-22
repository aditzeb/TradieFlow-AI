# Development Specification Document: TradieFlow AI (Glassline & OpenRouter Edition)

**Document Version:** 3.0 (Development-Only Edition)

**Project Context:** Stage 2 Assignment - AI Solutions Engineer

**Development Timebox:** 8 Hours

**Core Stack:** Flutter Web (PWA), Cloud Firestore, Firebase Storage, Cloud Functions (2nd Gen), OpenRouter API (OpenAI Node SDK)

**Design System:** Glassline (Flat neutrals with a single cobalt action driver)

---

## 1. System Architecture

TradieFlow AI uses an event-driven serverless architecture. The client runs as a responsive, zero-install Flutter Progressive Web App (PWA) styled under the **Glassline** design language.

```
[Flutter PWA (Glassline UI)]
          │ 
          ├─► 1. Media Upload: Storage path /jobs/{jobId}/photo.jpg
          └─► 2. Write Document: /triageJobs/{jobId} (status: "RECEIVED")
                     │
                     ▼
          [Cloud Functions (2nd Gen) - Sydney: australia-southeast1]
                     │
                     ├─► 3. Download image buffer from Firebase Storage
                     ├─► 4. Call OpenRouter API (Base URL: https://openrouter.ai/api/v1)
                     │      - Model: google/gemini-2.0-flash-001 or anthropic/claude-3.5-sonnet
                     │      - Multimodal extraction (OCR, AS/NZS compliance, AUD pricing)
                     │      - Response format: Validated via Zod
                     │
                     ▼
          [Cloud Firestore: Update /triageJobs/{jobId}]
          (status: "TRIAGED", aiAnalysis: { ... })
                     │
                     ▼
[Flutter PWA (Tradie Dispatch)] ◄── Real-time reactive stream via StreamBuilder

```

---

## 2. Design System Tokens: Glassline

The user interface strictly adheres to the **Glassline** specification: flat compositions, generous fog-grey neutral space (`#F1F3F5`), high-contrast dark typography (`#0F1419`), and a single interactive cobalt accent (`#2C5EF5`) per screen. No gradients or multi-colored status badges are permitted.

### 2.1 Token Reference

```dart
// lib/theme/glassline_tokens.dart
import 'package:flutter/material.dart';

class GlasslineColors {
  static const Color primary = Color(0xFF0F1419);      // Headlines and core text
  static const Color secondary = Color(0xFF4A5568);    // Borders, captions, metadata
  static const Color tertiary = Color(0xFF2C5EF5);     // Sole interaction driver (Cobalt)
  static const Color neutral = Color(0xFFF1F3F5);      // Page canvas / foundation
  static const Color surface = Color(0xFFFFFFFF);      // Cards and containers
  static const Color onPrimary = Color(0xFFFFFFFF);    // Label on tertiary button
}

class GlasslineRadii {
  static const double sm = 6.0;
  static const double md = 10.0;
  static const double lg = 16.0;
}

class GlasslineSpacing {
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 32.0;
}

```

### 2.2 Global Flutter Theme Configuration

```dart
// lib/theme/glassline_theme.dart
import 'package:flutter/material.dart';
import 'glassline_tokens.dart';

ThemeData buildGlasslineTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: GlasslineColors.neutral,
    fontFamily: 'Geist',
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: GlasslineColors.primary,
      onPrimary: GlasslineColors.onPrimary,
      secondary: GlasslineColors.secondary,
      onSecondary: GlasslineColors.surface,
      error: GlasslineColors.primary,
      onError: GlasslineColors.surface,
      surface: GlasslineColors.surface,
      onSurface: GlasslineColors.primary,
    ),
    // Card Component Token: rounded: 16px, background: surface, padding: 24px
    cardTheme: CardTheme(
      color: GlasslineColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GlasslineRadii.lg),
        side: const BorderSide(color: GlasslineColors.neutral, width: 1),
      ),
    ),
    // Primary Button Token: background: tertiary, rounded: 10px, padding: 12px 20px
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: GlasslineColors.tertiary,
        foregroundColor: GlasslineColors.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GlasslineRadii.md),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: 'Geist',
          fontSize: 15.2, // 0.95rem
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    // Typography Hierarchy
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Geist',
        fontSize: 60, // 3.75rem
        fontWeight: FontWeight.w600,
        letterSpacing: -1.8, // -0.03em
        color: GlasslineColors.primary,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Geist',
        fontSize: 36, // 2.25rem
        fontWeight: FontWeight.w600,
        letterSpacing: -0.72, // -0.02em
        color: GlasslineColors.primary,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Geist',
        fontSize: 15.2, // 0.95rem
        height: 1.55,
        color: GlasslineColors.primary,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Geist Mono',
        fontSize: 12, // 0.75rem
        letterSpacing: 0,
        color: GlasslineColors.secondary,
      ),
    ),
  );
}

```

---

## 3. Environment & Target Infrastructure

Bound directly to the pre-configured project instance:

| Parameter | Configuration |
| --- | --- |
| **Project Name** | TradieFlow AI

 |
| **Project ID** | `tradieflow-ai`<br> |
| **Project Number** | `397848547468`<br> |
| **Target GCP Region** | `australia-southeast1` (Sydney) |
| **Hosting Domain** | `[https://tradieflow-ai.web.app](https://tradieflow-ai.web.app)` |
| **Storage Bucket** | `gs://tradieflow-ai.firebasestorage.app` |

---

## 4. Backend Implementation: Cloud Functions & OpenRouter

### 4.1 Schema Definition (`functions/src/schemas.ts`)

```typescript
import { z } from "zod";

export const TriageOutputSchema = z.object({
  urgency: z.enum(["P1_EMERGENCY", "P2_SAME_DAY", "P3_ROUTINE"]),
  urgencyReasoning: z.string().describe("AS/NZS compliance basis"),
  hazardIdentified: z.boolean(),
  immediateSafetyAction: z.string(),
  appliance: z.object({
    brand: z.string(),
    modelNumber: z.string(),
    type: z.string(),
    estimatedAgeBracket: z.enum(["< 5 years", "5-10 years", "> 10 years", "Unknown"])
  }),
  faultDiagnostic: z.string(),
  recommendedParts: z.array(z.string()),
  estimatedLaborHours: z.number().min(0.5).max(12.0),
  quoteAud: z.object({
    calloutFee: z.number(),
    laborCost: z.number(),
    partsCost: z.number(),
    gst: z.number(),
    totalEstimate: z.number()
  }),
  dynamicClarification: z.string()
});

export type TriageOutput = z.infer<typeof TriageOutputSchema>;

```

### 4.2 Function Handler (`functions/src/index.ts`)

```typescript
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import OpenAI from "openai";
import { TriageOutputSchema } from "./schemas";

admin.initializeApp();
const db = admin.firestore();
const storage = admin.storage();

export const processJobTriage = onDocumentCreated(
  {
    document: "triageJobs/{jobId}",
    region: "australia-southeast1",
    secrets: ["OPENROUTER_API_KEY"],
    timeoutSeconds: 60,
    memory: "1GiB",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    if (data.status !== "RECEIVED") return;

    const jobId = event.params.jobId;
    const docRef = db.collection("triageJobs").doc(jobId);

    await docRef.update({ status: "ANALYZING" });

    try {
      const openRouterApiKey = process.env.OPENROUTER_API_KEY;
      if (!openRouterApiKey) {
        throw new Error("Missing OPENROUTER_API_KEY secret.");
      }

      const openai = new OpenAI({
        baseURL: "https://openrouter.ai/api/v1",
        apiKey: openRouterApiKey,
        defaultHeaders: {
          "HTTP-Referer": "https://tradieflow-ai.web.app",
          "X-Title": "TradieFlow AI",
        },
      });

      const bucket = storage.bucket();
      const file = bucket.file(data.media.storagePath);
      const [fileBuffer] = await file.download();
      const base64Image = `data:image/jpeg;base64,${fileBuffer.toString("base64")}`;

      const systemPrompt = `
You are an expert Australian trade triage technician.
Analyze the equipment photo and user issue according to AS/NZS 3500 and AS/NZS 3000.
Calculate line items in Australian Dollars (AUD).
Return ONLY a valid JSON object matching the requested schema.
`;

      const response = await openai.chat.completions.create({
        model: "google/gemini-2.0-flash-001",
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: systemPrompt },
          {
            role: "user",
            content: [
              {
                type: "text",
                text: `Location: ${data.customer.suburb}, ${data.customer.state} ${data.customer.postcode}\nDescription: ${data.description || "None provided"}`
              },
              {
                type: "image_url",
                image_url: { url: base64Image }
              }
            ]
          }
        ]
      });

      const rawJson = response.choices[0].message.content;
      if (!rawJson) throw new Error("Empty response from OpenRouter");

      const validatedOutput = TriageOutputSchema.parse(JSON.parse(rawJson));

      await docRef.update({
        status: "TRIAGED",
        aiAnalysis: validatedOutput,
        triagedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error("AI Triage Processing Failed:", error);
      await docRef.update({
        status: "TRIAGE_FAILED",
        error: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }
);

```

---

## 5. Frontend Implementation (Flutter PWA with Glassline)

### 5.1 App Entry Point (`lib/main.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'theme/glassline_theme.dart';
import 'views/customer_intake_view.dart';
import 'views/tradie_dispatch_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAuth.instance.signInAnonymously();
  runApp(const TradieFlowApp());
}

class TradieFlowApp extends StatelessWidget {
  const TradieFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TradieFlow AI',
      debugShowCheckedModeBanner: false,
      theme: buildGlasslineTheme(),
      home: LayoutBuilder(
        builder: (context, constraints) {
          return constraints.maxWidth < 800
              ? const CustomerIntakeView()
              : const TradieDispatchView();
        },
      ),
    );
  }
}

```

### 5.2 Customer Intake View (`lib/views/customer_intake_view.dart`)

Adheres to the single cobalt action rule: the sole accent is the **"Initiate Emergency Triage"** submission button.

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../theme/glassline_tokens.dart';

class CustomerIntakeView extends StatefulWidget {
  const CustomerIntakeView({super.key});

  @override
  State<CustomerIntakeView> createState() => _CustomerIntakeViewState();
}

class _CustomerIntakeViewState extends State<CustomerIntakeView> {
  Uint8List? _imageBytes;
  bool _isSubmitting = false;
  final _descController = TextEditingController();
  final _suburbController = TextEditingController();

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _submitJob() async {
    if (_imageBytes == null || _suburbController.text.isEmpty) return;
    setState(() => _isSubmitting = true);

    final jobId = const Uuid().v4();
    final storagePath = 'jobs/$jobId/photo.jpg';

    // 1. Upload to Firebase Storage
    await FirebaseStorage.instance.ref(storagePath).putData(
      _imageBytes!,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    // 2. Initialize Firestore Triage Document
    await FirebaseFirestore.instance.collection('triageJobs').doc(jobId).set({
      'id': jobId,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'RECEIVED',
      'customer': {
        'suburb': _suburbController.text.trim(),
        'state': 'NSW',
        'postcode': '2041',
      },
      'description': _descController.text.trim(),
      'media': {'storagePath': storagePath},
    });

    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GlasslineSpacing.lg),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('INTAKE // 01', style: textTheme.labelSmall),
                const SizedBox(height: GlasslineSpacing.sm),
                Text('Instant Trade Triage', style: textTheme.headlineMedium),
                const SizedBox(height: GlasslineSpacing.sm),
                Text(
                  'Upload a photo of the appliance or issue. Our automated engine assesses urgency and parts on submission.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: GlasslineSpacing.lg),
                // Card Surface Container
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: _pickImage,
                          borderRadius: BorderRadius.circular(GlasslineRadii.md),
                          child: Container(
                            height: 160,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: GlasslineColors.neutral,
                              borderRadius: BorderRadius.circular(GlasslineRadii.md),
                              border: Border.all(color: GlasslineColors.secondary.withOpacity(0.3)),
                            ),
                            child: _imageBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(GlasslineRadii.md),
                                    child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.photo_camera_outlined, color: GlasslineColors.secondary),
                                      const SizedBox(height: GlasslineSpacing.sm),
                                      Text('SELECT APPLIANCE PHOTO', style: textTheme.labelSmall),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: GlasslineSpacing.md),
                        TextField(
                          controller: _suburbController,
                          decoration: InputDecoration(
                            labelText: 'SUBURB / POSTCODE',
                            labelStyle: textTheme.labelSmall,
                            filled: true,
                            fillColor: GlasslineColors.neutral,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(GlasslineRadii.sm),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: GlasslineSpacing.md),
                        TextField(
                          controller: _descController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'OBSERVED SYMPTOMS (OPTIONAL)',
                            labelStyle: textTheme.labelSmall,
                            filled: true,
                            fillColor: GlasslineColors.neutral,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(GlasslineRadii.sm),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: GlasslineSpacing.lg),
                        // Sole Cobalt Interaction Driver
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitJob,
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('SUBMIT FOR TRIAGE'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

```

### 5.3 Tradie Dispatch View (`lib/views/tradie_dispatch_view.dart`)

Uses monochromatic metadata badges (Geist Mono label tokens) to honor the single-accent rule.

```dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/glassline_tokens.dart';

class TradieDispatchView extends StatelessWidget {
  const TradieDispatchView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GlasslineSpacing.lg,
          vertical: GlasslineSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DISPATCH CONTROL // LIVE FEED', style: textTheme.labelSmall),
                    const SizedBox(height: GlasslineSpacing.sm),
                    Text('Active Inbound Queue', style: textTheme.headlineMedium),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: GlasslineColors.surface,
                    borderRadius: BorderRadius.circular(GlasslineRadii.sm),
                    border: Border.all(color: GlasslineColors.secondary.withOpacity(0.3)),
                  ),
                  child: Text('AS/NZS 3500 ENGINE ACTIVE', style: textTheme.labelSmall),
                ),
              ],
            ),
            const SizedBox(height: GlasslineSpacing.lg),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('triageJobs')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Stream Error', style: textTheme.bodyMedium));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: GlasslineColors.primary));
                  }

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Text('NO ACTIVE TICKETS IN REGION', style: textTheme.labelSmall),
                    );
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: GlasslineSpacing.md),
                    itemBuilder: (context, index) {
                      final job = docs[index].data() as Map<String, dynamic>;
                      final ai = job['aiAnalysis'] as Map<String, dynamic>?;
                      final status = job['status'] as String? ?? 'RECEIVED';

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Monochrome Label Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: GlasslineColors.neutral,
                                      borderRadius: BorderRadius.circular(GlasslineRadii.sm),
                                    ),
                                    child: Text(
                                      ai?['urgency'] ?? status,
                                      style: textTheme.labelSmall?.copyWith(
                                        color: GlasslineColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    ai != null ? '\$${ai['quoteAud']['totalEstimate']} AUD' : '--',
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: GlasslineSpacing.md),
                              Text(
                                '${job['customer']['suburb']} — ${ai?['appliance']['brand'] ?? 'Extracting appliance metadata...'}',
                                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: GlasslineSpacing.sm),
                              Text(
                                ai?['faultDiagnostic'] ?? 'OpenRouter multimodal agent parsing plate...',
                                style: textTheme.bodyMedium?.copyWith(color: GlasslineColors.secondary),
                              ),
                              if (ai?['hazardIdentified'] == true) ...[
                                const SizedBox(height: GlasslineSpacing.md),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: GlasslineColors.neutral,
                                    borderRadius: BorderRadius.circular(GlasslineRadii.sm),
                                    border: Border.all(color: GlasslineColors.primary),
                                  ),
                                  child: Text(
                                    'STATUTORY HAZARD: ${ai?['immediateSafetyAction']}',
                                    style: textTheme.labelSmall?.copyWith(color: GlasslineColors.primary),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

```

---

## 6. Execution Roadmap (8-Hour Timebox)

| Phase | Timebox | Key Deliverables |
| --- | --- | --- |
| **1. Token Setup & Firebase** | 00:00 – 01:00 | Configure `glassline_tokens.dart` and `glassline_theme.dart`. Set `OPENROUTER_API_KEY` secret. Apply CORS policy to Storage. |
| **2. OpenRouter 2nd Gen Function** | 01:00 – 03:00 | Deploy `processJobTriage` to Sydney region. Validate multimodal image parsing and Zod output serialization. |
| **3. Glassline Flutter PWA** | 03:00 – 05:30 | Implement `CustomerIntakeView` and `TradieDispatchView`. Verify typography hierarchy (`Geist` / `Geist Mono`), single cobalt button rule, and flat cards. |
| **4. End-to-End Stress Test** | 05:30 – 06:30 | Run live intake uploads: obscured label (`modelNumber: "Unreadable"` fallback) and statutory electrical hazards (`hazardIdentified: true`). |
| **5. Build & Loom Recording** | 06:30 – 08:00 | Compile `flutter build web` and deploy to Firebase Hosting. Record the 15-minute presentation addressing all 8 criteria with a live split-screen demo.

 |