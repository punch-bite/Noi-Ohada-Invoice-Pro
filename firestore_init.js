// firestore_init.js
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

// Charger la clé de service
const serviceAccount = require('./serviceAccountKey.json');

// Initialiser Firebase Admin SDK
initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

// ===== PLANS =====
const plans = {
  free: {
    id: 'free',
    name: 'Gratuit',
    description: 'Pour démarrer avec OHADA Invoice Pro',
    price: 0,
    currency: 'XAF',
    interval: 'month',
    maxInvoices: 3,
    maxClients: 5,
    hasPdfExport: true,
    hasCloudSync: false,
    hasTeamAccess: false,
    features: ['3 factures par mois', '5 clients', 'Export PDF', 'Stockage local'],
    isPopular: false,
    isActive: true,
    createdAt: new Date()
  },
  pro: {
    id: 'pro',
    name: 'Pro',
    description: 'Pour les PME en croissance',
    price: 9900,
    currency: 'XAF',
    interval: 'month',
    maxInvoices: -1,
    maxClients: -1,
    hasPdfExport: true,
    hasCloudSync: true,
    hasTeamAccess: false,
    features: [
      'Factures illimitées',
      'Clients illimités',
      'Export PDF illimité',
      'Synchronisation cloud',
      'Support prioritaire'
    ],
    isPopular: true,
    isActive: true,
    createdAt: new Date()
  },
  business: {
    id: 'business',
    name: 'Business',
    description: 'Pour les entreprises et équipes',
    price: 49000,
    currency: 'XAF',
    interval: 'year',
    maxInvoices: -1,
    maxClients: -1,
    hasPdfExport: true,
    hasCloudSync: true,
    hasTeamAccess: true,
    features: [
      'Tout le plan Pro',
      'Accès équipe (5 utilisateurs)',
      'API intégration',
      'Support dédié 24/7',
      'Formation incluse'
    ],
    isPopular: false,
    isActive: true,
    createdAt: new Date()
  },
  unlimited: {
    id: 'unlimited',
    name: 'Illimité',
    description: 'Accès illimité réservé aux administrateurs',
    price: 0,
    currency: 'XAF',
    interval: 'year',
    maxInvoices: -1,
    maxClients: -1,
    hasPdfExport: true,
    hasCloudSync: true,
    hasTeamAccess: true,
    features: [
      'Factures illimitées',
      'Clients illimités',
      'Synchronisation cloud',
      'Accès équipe',
      'Support prioritaire'
    ],
    isPopular: false,
    isActive: true,
    createdAt: new Date()
  }
};

// ===== ENTREPRISE PAR DÉFAUT =====
const defaultCompany = {
  id: 'default_company',
  name: 'NoiOHADA Invoice Pro',
  address: 'Douala, Cameroun',
  taxId: 'RC123456789',
  phone: '+237 6XX XX XX XX',
  email: 'contact@ohada-invoice-pro.com',
  logoPath: '',
  currency: 'XAF',
  defaultTaxRate: 18,
  legalText: 'Conforme aux normes OHADA et SYSCOHADA',
  website: 'https://ohada-invoice-pro.com',
  rccm: 'RC/DLA/2023/1234',
  createdAt: new Date(),
  updatedAt: new Date()
};

// ===== PARAMÈTRES GLOBAUX =====
const defaultSettings = {
  id: 'global',
  appName: 'Noi OHADA Invoice Pro',
  version: '1.0.0',
  maintenanceMode: false,
  contactEmail: 'support@ohada-invoice-pro.com',
  contactPhone: '+237 6XX XX XX XX',
  createdAt: new Date(),
  updatedAt: new Date()
};

// ===== MODÈLE DE FACTURE PAR DÉFAUT =====
const defaultTemplate = {
  id: 'default_1',
  name: 'Classique',
  description: 'Modèle épuré et professionnel',
  primaryColor: 0xFF1A237E,
  textColor: 0xFF000000,
  backgroundColor: 0xFFFFFFFF,
  showLogo: true,
  showTaxDetails: true,
  showPaymentTerms: true,
  showPaymentQR: false,
  isPremium: false,
  isDefault: true,
  fontFamily: 'Roboto',
  fontSize: 12,
  showBorder: true,
  createdAt: new Date()
};

// ===== EXÉCUTION =====
async function initializeFirestore() {
  console.log('🚀 Début de l\'initialisation Firestore...');

  try {
    // 1. Plans
    console.log('📋 Création des plans...');
    const batch = db.batch();
    for (const [key, plan] of Object.entries(plans)) {
      const ref = db.collection('plans').doc(key);
      batch.set(ref, plan);
    }
    await batch.commit();
    console.log('✅ Plans créés avec succès');

    // 2. Entreprise
    console.log('🏢 Création de l\'entreprise...');
    await db.collection('companies').doc('default_company').set(defaultCompany);
    console.log('✅ Entreprise créée');

    // 3. Paramètres
    console.log('⚙️ Création des paramètres...');
    await db.collection('settings').doc('global').set(defaultSettings);
    console.log('✅ Paramètres créés');

    // 4. Modèle
    console.log('📄 Création du modèle...');
    await db.collection('templates').doc('default_1').set(defaultTemplate);
    console.log('✅ Modèle créé');

    console.log('✅ Initialisation Firestore terminée avec succès !');
  } catch (error) {
    console.error('❌ Erreur lors de l\'initialisation:', error);
  }
}

// Exécution
initializeFirestore();