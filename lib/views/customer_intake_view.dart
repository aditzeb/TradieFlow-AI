import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/job_service.dart';
import '../theme/glassline_tokens.dart';
import '../widgets/job_card.dart';

class CustomerIntakeView extends StatefulWidget {
  const CustomerIntakeView({super.key, this.service});
  final JobService? service;

  @override
  State<CustomerIntakeView> createState() => _CustomerIntakeViewState();
}

class _CustomerIntakeViewState extends State<CustomerIntakeView> {
  final _form = GlobalKey<FormState>();
  final _suburb = TextEditingController();
  final _postcode = TextEditingController();
  final _description = TextEditingController();
  Uint8List? _image;
  String? _filename;
  String _state = 'NSW';
  bool _consent = false;
  bool _busy = false;
  bool _picking = false;
  String? _error;
  PendingJob? _pending;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _result;

  @override
  void dispose() {
    _suburb.dispose();
    _postcode.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
      );
      if (file == null) return;
      if (await file.length() > maxImageBytes) {
        throw const FormatException('Choose an image smaller than 5 MB.');
      }
      final bytes = await file.readAsBytes();
      imageContentType(bytes);
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      ui.ImageDescriptor? descriptor;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        if (descriptor.width * descriptor.height > 16000000) {
          throw const FormatException(
            'Choose a smaller photo (up to 16 megapixels).',
          );
        }
      } finally {
        descriptor?.dispose();
        buffer.dispose();
      }
      if (mounted) {
        setState(() {
          _image = bytes;
          _filename = file.name;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : 'That image could not be opened. Choose a JPEG, PNG, or WebP photo.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || widget.service == null) return;
    if (!_form.currentState!.validate()) return;
    if (_image == null || !_consent) {
      setState(
        () => _error = _image == null
            ? 'Add a photo of the appliance or issue.'
            : 'Confirm consent to photo and description processing.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _pending ??= widget.service!.prepare(
        bytes: _image!,
        customer: {
          'suburb': _suburb.text.trim(),
          'state': _state,
          'postcode': _postcode.text.trim(),
        },
        description: _description.text.trim(),
      );
      await widget.service!
          .submit(_pending!)
          .timeout(const Duration(seconds: 60));
      if (mounted) {
        setState(() => _result = widget.service!.watchJob(_pending!.id));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Submission could not be confirmed. Check your connection and retry this same request; it will not create a duplicate.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    setState(() {
      _pending = null;
      _result = null;
      _image = null;
      _filename = null;
      _description.clear();
      _consent = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final locked = _busy || _pending != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final intro = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CUSTOMER INTAKE // 01', style: text.labelSmall),
                  const SizedBox(height: 16),
                  Text(
                    'A clearer picture.\nA faster response.',
                    style: constraints.maxWidth > 800
                        ? text.displayLarge?.copyWith(fontSize: 48)
                        : text.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'One photo is the first step. Get an initial assessment of your appliance issue, its urgency, and an indicative repair estimate.',
                    style: text.bodyMedium?.copyWith(
                      color: GlasslineColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  for (final step in [
                    (
                      '01',
                      'Capture the issue',
                      'Include the appliance and a readable model label.',
                    ),
                    (
                      '02',
                      'Add a little context',
                      'Tell us where you are and what you have noticed.',
                    ),
                    (
                      '03',
                      'Get an initial assessment',
                      'AI triage prepares the details for a licensed tradie.',
                    ),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MonoBadge(step.$1),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.$2,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(step.$3, style: text.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 32),
                  Text('NOT AN EMERGENCY SERVICE', style: text.labelSmall),
                  const SizedBox(height: 8),
                  Text(
                    'If there is immediate danger, keep clear and call 000. Do not touch exposed wiring, open equipment, or wait for an AI result.',
                    style: text.bodySmall,
                  ),
                ],
              );
              final form = _result != null
                  ? _resultView(context)
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Instant Trade Triage',
                                style: text.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Start with the details below.',
                                style: text.bodySmall,
                              ),
                              const SizedBox(height: 24),
                              Text('APPLIANCE PHOTO', style: text.labelSmall),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: locked || _picking
                                      ? null
                                      : _pickImage,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                  child: _image != null
                                      ? Column(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: Image.memory(
                                                _image!,
                                                height: 160,
                                                width: double.infinity,
                                                fit: BoxFit.contain,
                                                semanticLabel:
                                                    'Selected appliance photo',
                                                errorBuilder: (_, _, _) =>
                                                    const Text(
                                                      'Preview unavailable',
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              _filename ?? 'Change photo',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const Text(
                                              'Choose a different photo',
                                            ),
                                          ],
                                        )
                                      : Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 24,
                                          ),
                                          child: Column(
                                            children: [
                                              const Icon(
                                                Icons
                                                    .add_photo_alternate_outlined,
                                                size: 32,
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                _picking
                                                    ? 'Opening photo…'
                                                    : 'Select appliance photo',
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'JPEG, PNG or WebP · Up to 5 MB',
                                                style: text.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _suburb,
                                enabled: !locked,
                                decoration: const InputDecoration(
                                  labelText: 'Suburb',
                                  hintText: 'e.g. Balmain',
                                ),
                                autofillHints: const [
                                  AutofillHints.addressCity,
                                ],
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                maxLength: 80,
                                validator: validateSuburb,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      initialValue: _state,
                                      decoration: const InputDecoration(
                                        labelText: 'State',
                                      ),
                                      items: statePostcodes.keys
                                          .map(
                                            (state) => DropdownMenuItem(
                                              value: state,
                                              child: Text(state),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: locked
                                          ? null
                                          : (value) =>
                                                setState(() => _state = value!),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _postcode,
                                      enabled: !locked,
                                      decoration: const InputDecoration(
                                        labelText: 'Postcode',
                                        hintText: '2041',
                                      ),
                                      keyboardType: TextInputType.number,
                                      autofillHints: const [
                                        AutofillHints.postalCode,
                                      ],
                                      textInputAction: TextInputAction.next,
                                      maxLength: 4,
                                      validator: (value) =>
                                          validatePostcode(value, _state),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _description,
                                enabled: !locked,
                                decoration: const InputDecoration(
                                  labelText: 'Observed symptoms (optional)',
                                  hintText: 'What happened? When did it start?',
                                ),
                                minLines: 3,
                                maxLines: 6,
                                maxLength: 4000,
                                validator: (value) =>
                                    (value?.length ?? 0) > 4000
                                    ? 'Keep the description under 4,000 characters.'
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: _consent,
                                onChanged: locked
                                    ? null
                                    : (value) => setState(
                                        () => _consent = value ?? false,
                                      ),
                                title: Text(
                                  'I consent to this photo and description being stored in Firebase and sent through OpenRouter to an AI provider for triage. Processing may occur outside Australia. I have permission to share them.',
                                  style: text.bodySmall,
                                ),
                              ),
                              Text(
                                'Avoid faces, personal documents, and unrelated private information. AI results and pricing require professional review.',
                                style: text.bodySmall,
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _busy ||
                                          _picking ||
                                          widget.service == null
                                      ? null
                                      : _submit,
                                  icon: _busy
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.arrow_forward,
                                          size: 18,
                                        ),
                                  label: Text(
                                    _busy
                                        ? 'Submitting request…'
                                        : _pending != null
                                        ? 'Retry same submission'
                                        : 'Submit for triage',
                                  ),
                                ),
                              ),
                              if (widget.service == null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Preview only. Connect Firebase to submit a real request.',
                                  style: text.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
              if (constraints.maxWidth < 800) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [intro, const SizedBox(height: 32), form],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: intro),
                  const SizedBox(width: 64),
                  Expanded(child: form),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _resultView(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        liveRegion: true,
        child: Text(
          'Request submitted',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'This is an assessment request, not a confirmed booking. Your result updates here automatically.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 20),
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _result,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text(
              'Unable to load the result. Your request was submitted; check the queue or reload when connected.',
            );
          }
          final job = snapshot.data?.data();
          if (job == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return JobCard(job: job, id: _pending!.id, expanded: true);
        },
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: _reset,
        icon: const Icon(Icons.add),
        label: const Text('Start another request'),
      ),
    ],
  );
}
