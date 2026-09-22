import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

const maxImageBytes = 5 * 1024 * 1024;
const statePostcodes = <String, List<(int, int)>>{
  'NSW': [(1000, 2599), (2619, 2899), (2921, 2999)],
  'VIC': [(3000, 3999), (8000, 8999)],
  'QLD': [(4000, 4999), (9000, 9999)],
  'SA': [(5000, 5999)],
  'WA': [(6000, 6797), (6800, 6999)],
  'TAS': [(7000, 7999)],
  'NT': [(800, 999)],
  'ACT': [(200, 299), (2600, 2618), (2900, 2920)],
};

String? validateSuburb(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ||
          text.length > 80 ||
          RegExp(r'[\x00-\x1F\x7F-\x9F]').hasMatch(text)
      ? 'Enter a suburb (1–80 characters).'
      : null;
}

String? validatePostcode(String? value, String state) {
  final text = value?.trim() ?? '';
  final number = int.tryParse(text);
  return !RegExp(r'^\d{4}$').hasMatch(text) ||
          number == null ||
          !(statePostcodes[state]?.any(
                (range) => number >= range.$1 && number <= range.$2,
              ) ??
              false)
      ? 'Enter a valid four-digit $state postcode.'
      : null;
}

String imageContentType(
  Uint8List bytes, {
  String? mimeType,
  String? filename,
}) {
  if (bytes.isEmpty) {
    throw const FormatException('Selected file is empty. Please select a photo.');
  }
  if (bytes.length > maxImageBytes) {
    final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
    throw FormatException(
      'Photo is too large ($mb MB). Please choose an image up to 5 MB.',
    );
  }
  // Check for iPhone HEIC/HEIF signature
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp') {
    final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
    if (brand.contains('heic') ||
        brand.contains('mif1') ||
        brand.contains('msf1') ||
        brand.contains('heix')) {
      throw const FormatException(
        'iPhone HEIC format detected. Please select a JPEG, PNG, or WebP photo (or take a photo directly).',
      );
    }
  }
  // JPEG: Starts with 0xFF, 0xD8 (SOI marker)
  if (bytes.length >= 2 && bytes[0] == 255 && bytes[1] == 216) {
    return 'image/jpeg';
  }
  // PNG: 8-byte signature
  if (bytes.length >= 8 &&
      listEquals(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10])) {
    return 'image/png';
  }
  // WebP: RIFF ... WEBP
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  // Fallback to mimeType if provided by browser picker
  if (mimeType != null && mimeType.isNotEmpty) {
    final lower = mimeType.toLowerCase();
    if (lower.contains('jpeg') || lower.contains('jpg')) return 'image/jpeg';
    if (lower.contains('png')) return 'image/png';
    if (lower.contains('webp')) return 'image/webp';
  }
  // Fallback to filename extension
  if (filename != null && filename.isNotEmpty) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      throw const FormatException(
        'HEIC photos are not supported directly in the browser. Please upload as JPEG, PNG, or WebP.',
      );
    }
  }
  throw const FormatException('Choose a JPEG, PNG, or WebP image.');
}

class PendingJob {
  PendingJob({
    required this.id,
    required this.ownerId,
    required this.bytes,
    required this.customer,
    required this.description,
  });
  final String id;
  final String ownerId;
  final Uint8List bytes;
  final Map<String, String> customer;
  final String description;
  bool uploaded = false;
}

class JobService extends ChangeNotifier {
  JobService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;
  bool isDispatcher = false;
  bool isReady = false;

  void _clearSession() {
    isReady = false;
    isDispatcher = false;
    notifyListeners();
  }

  String get uid => _auth.currentUser!.uid;
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;
  CollectionReference<Map<String, dynamic>> get jobs =>
      _db.collection('triageJobs');

  Future<void> initialize() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
    await refreshRole();
  }

  Future<void> refreshRole() async {
    _clearSession();
    final token = await _auth.currentUser!.getIdTokenResult(true);
    isDispatcher = token.claims?['dispatcher'] == true;
    isReady = true;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await refreshRole();
  }

  Future<void> signOut() async {
    _clearSession();
    await _auth.signOut();
    await initialize();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchJobs() {
    Query<Map<String, dynamic>> query = jobs;
    if (!isDispatcher) query = query.where('ownerId', isEqualTo: uid);
    return query
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots(includeMetadataChanges: true);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchJob(String id) =>
      jobs.doc(id).snapshots(includeMetadataChanges: true);

  PendingJob prepare({
    required Uint8List bytes,
    required Map<String, String> customer,
    required String description,
  }) {
    imageContentType(bytes);
    if (validateSuburb(customer['suburb']) != null ||
        validatePostcode(customer['postcode'], customer['state'] ?? '') !=
            null ||
        description.length > 4000) {
      throw const FormatException('Check the location and description.');
    }
    return PendingJob(
      id: jobs.doc().id,
      ownerId: uid,
      bytes: bytes,
      customer: customer,
      description: description,
    );
  }

  Future<void> submit(PendingJob job) async {
    if (job.ownerId != uid) {
      throw StateError('Your session changed. Reload before submitting.');
    }
    if (!job.uploaded) {
      final photo = _storage.ref('jobs/${job.id}/photo.jpg');
      try {
        await photo.putData(
          job.bytes,
          SettableMetadata(
            contentType: imageContentType(job.bytes),
            customMetadata: {'ownerId': job.ownerId},
            cacheControl: 'private, no-store',
          ),
        );
      } on FirebaseException {
        final metadata = await photo.getMetadata();
        if (metadata.customMetadata?['ownerId'] != job.ownerId ||
            metadata.size != job.bytes.length) {
          rethrow;
        }
      }
      job.uploaded = true;
    }
    try {
      await jobs.doc(job.id).set({
        'id': job.id,
        'ownerId': job.ownerId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'RECEIVED',
        'customer': job.customer,
        'description': job.description,
        'media': {'storagePath': 'jobs/${job.id}/photo.jpg'},
      });
    } on FirebaseException {
      final existing = await jobs
          .doc(job.id)
          .get(const GetOptions(source: Source.server));
      if (!existing.exists || existing.data()?['ownerId'] != job.ownerId) {
        rethrow;
      }
    }
  }
}
