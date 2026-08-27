// test/helpers/fake_firebase.dart
//
// 🧪 Initialisation Firebase pour les tests de widgets.
// Enregistre le fake OFFICIEL `TestFirebaseCoreHostApi` (Pigeon) puis
// initialise l'app Firebase par défaut avec des options factices.
// Aucun utilisateur n'est connecté → les appels Firestore/Auth qui
// dépendent de `currentUser` (ex. `DatabaseService.getCompany()`) retournent
// null SANS requête réseau.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart'
    as core_platform_test;
import 'package:shared_preferences/shared_preferences.dart';

/// Fake officiel de la plateforme Firebase Core (Pigeon) pour les tests.
class FakeFirebaseCoreHostApi
    extends core_platform_test.TestFirebaseCoreHostApi {
  @override
  Future<core_platform_test.CoreInitializeResponse> initializeApp(
    String appName,
    core_platform_test.CoreFirebaseOptions options,
  ) async {
    return core_platform_test.CoreInitializeResponse(
      name: appName,
      options: options,
      pluginConstants: const {},
    );
  }

  @override
  Future<List<core_platform_test.CoreInitializeResponse>> initializeCore() async {
    return [];
  }

  @override
  Future<core_platform_test.CoreFirebaseOptions> optionsFromResource() async {
    throw UnimplementedError('Pas de google-services.json en test.');
  }
}

/// Enregistre le fake Firebase (SharedPreferences + Pigeon) et initialise
/// l'app par défaut. À appeler dans `setUpAll`, APRÈS
/// `TestWidgetsFlutterBinding.ensureInitialized()`.
Future<void> setupFakeFirebaseForTests() async {
  SharedPreferences.setMockInitialValues({});
  core_platform_test.TestFirebaseCoreHostApi.setUp(FakeFirebaseCoreHostApi());
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'dummy-test-key',
      appId: 'dummy-test-app',
      messagingSenderId: 'dummy-test-sender',
      projectId: 'dummy-test-project',
    ),
  );
}
