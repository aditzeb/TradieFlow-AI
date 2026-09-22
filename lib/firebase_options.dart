import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  static const emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
  static const _apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyDHlvwFYZpk0y_XsOwZqxxj7rMtrbNYVQo',
  );
  static const _appId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '1:397848547468:web:d89a8905d93c1131056ba9',
  );

  static bool get isConfigured =>
      useEmulators || (_apiKey.isNotEmpty && _appId.isNotEmpty);

  static FirebaseOptions get currentPlatform => FirebaseOptions(
    apiKey: useEmulators ? 'demo-api-key' : _apiKey,
    appId: useEmulators ? '1:397848547468:web:demo' : _appId,
    messagingSenderId: '397848547468',
    projectId: useEmulators ? 'demo-tradieflow-ai' : 'tradieflow-ai',
    authDomain: 'tradieflow-ai.firebaseapp.com',
    storageBucket: 'tradieflow-ai.firebasestorage.app',
  );
}
