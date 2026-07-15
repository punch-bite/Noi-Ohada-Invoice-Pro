// scripts/generate_env.dart
import 'dart:io';

void main() {
  final envFile = File('.env');
  
  if (!envFile.existsSync()) {
    print('📝 Création du fichier .env...');
    envFile.writeAsStringSync('''
# OHADA Invoice Pro - Configuration
FIREBASE_API_KEY=
FIREBASE_APP_ID=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_PROJECT_ID=
FIREBASE_AUTH_DOMAIN=
FIREBASE_STORAGE_BUCKET=
STRIPE_PUBLISHABLE_KEY=
STRIPE_SECRET_KEY=
APP_NAME=OHADA Invoice Pro
APP_VERSION=1.0.0
APP_ENVIRONMENT=development
DEFAULT_CURRENCY=XAF
DEFAULT_TAX_RATE=18
SUPPORT_EMAIL=support@ohada-invoice-pro.com
LEGAL_COMPANY_NAME=OHADA Invoice Pro SAS
LEGAL_TAX_ID=RC123456789
LEGAL_ADDRESS=Douala, Cameroun
LEGAL_TEXT=Conforme aux normes OHADA et SYSCOHADA
''');
    print('✅ Fichier .env créé !');
  } else {
    print('✅ Fichier .env existe déjà');
  }
}