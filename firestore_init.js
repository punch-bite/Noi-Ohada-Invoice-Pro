// firestore_init.js
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

// Charger la clé de service
const serviceAccount = require('./serviceAccountKey.json');

// Initialiser Firebase Admin SDK
initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

// ============================================
// 1. PLANS
// ============================================
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

// ============================================
// 2. ENTREPRISE PAR DÉFAUT
// ============================================
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

// ============================================
// 3. PARAMÈTRES GLOBAUX
// ============================================
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

// ============================================
// 4. MODÈLE DE FACTURE PAR DÉFAUT
// ============================================
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

// ============================================
// 5. UTILISATEUR ADMIN (exemple)
// ============================================
const adminUser = {
  id: 'admin_user_id', // ⚠️ Remplacez par l'UID réel de votre admin
  email: 'admin@ohada-invoice-pro.com',
  displayName: 'Administrateur',
  phone: '+237 6XX XX XX XX',
  companyName: 'NoiOHADA Invoice Pro',
  companyAddress: 'Douala, Cameroun',
  taxId: 'RC123456789',
  subscriptionId: 'sub_admin_default',
  createdAt: new Date(),
  lastLoginAt: new Date(),
  isActive: true,
  roles: ['user', 'admin']
};

// ============================================
// 6. ABONNEMENT ADMIN
// ============================================
const adminSubscription = {
  id: 'sub_admin_default',
  userId: 'admin_user_id', // ⚠️ Même UID que ci-dessus
  planId: 'unlimited',
  startDate: new Date('2024-01-01'),
  endDate: new Date('2099-12-31'),
  status: 'active',
  paymentMethod: 'admin',
  paymentId: 'admin_default',
  amount: 0,
  currency: 'XAF',
  autoRenew: true,
  isActive: true,
  createdAt: new Date(),
  interval: 'year',
  metadata: {
    isAdmin: true,
    unlimited: true
  }
};

// ============================================
// 7. FOURNISSEUR (exemple)
// ============================================
const supplier = {
  id: 'supplier_1',
  name: 'Fournisseur Exemple SARL',
  email: 'contact@fournisseur.com',
  phone: '+237 6XX XX XX XX',
  address: 'Douala, Cameroun',
  taxId: 'RC987654321',
  contactPerson: 'Jean Dupont',
  notes: 'Fournisseur principal pour l\'électronique',
  isActive: true,
  createdAt: new Date(),
  updatedAt: new Date()
};

// ============================================
// 8. PRODUIT (exemple)
// ============================================
const product = {
  id: 'product_1',
  name: 'Ordinateur portable HP',
  description: 'Ordinateur portable HP EliteBook',
  category: 'Électronique',
  price: 150000,
  costPrice: 120000,
  quantity: 10,
  minStock: 3,
  unit: 'pièce',
  barcode: '1234567890123',
  imagePath: '',
  isActive: true,
  createdAt: new Date(),
  updatedAt: new Date(),
  supplierId: 'supplier_1'
};

// ============================================
// 9. CLIENT (exemple)
// ============================================
const client = {
  id: 'client_1',
  name: 'Client Exemple SARL',
  address: 'Douala, Cameroun',
  taxId: 'RC1122334455',
  phone: '+237 6XX XX XX XX',
  email: 'client@exemple.com',
  createdAt: new Date(),
  updatedAt: new Date()
};

// ============================================
// 10. FACTURE (exemple)
// ============================================
const invoice = {
  id: 'invoice_1',
  companyId: 'default_company',
  clientId: 'client_1',
  invoiceNumber: 'FA-2026-001',
  issueDate: new Date('2026-01-15'),
  dueDate: new Date('2026-02-14'),
  items: [
    {
      id: 'item_1',
      description: 'Ordinateur portable HP',
      quantity: 2,
      unitPrice: 150000,
      taxRate: 18,
      total: 354000
    }
  ],
  subtotal: 300000,
  taxRate: 18,
  taxAmount: 54000,
  discount: 0,
  totalAmount: 354000,
  status: 'sent',
  terms: 'Paiement à 30 jours',
  isDevis: false,
  notes: 'Facture pour commande de janvier',
  createdAt: new Date(),
  updatedAt: new Date(),
  userId: 'admin_user_id'
};

// ============================================
// 11. LOG (exemple)
// ============================================
const log = {
  id: 'log_1',
  userId: 'admin_user_id',
  userEmail: 'admin@ohada-invoice-pro.com',
  action: 'login',
  targetId: 'admin_user_id',
  targetType: 'user',
  details: { ip: '192.168.1.1', device: 'Chrome' },
  timestamp: new Date()
};

// ============================================
// EXÉCUTION
// ============================================
async function initializeFirestore() {
  console.log('🚀 Début de l\'initialisation Firestore...');

  try {
    // --- Plans ---
    console.log('📋 Création des plans...');
    const batch1 = db.batch();
    for (const [key, plan] of Object.entries(plans)) {
      const ref = db.collection('plans').doc(key);
      batch1.set(ref, plan);
    }
    await batch1.commit();
    console.log('✅ Plans créés');

    // --- Entreprise ---
    console.log('🏢 Création de l\'entreprise...');
    await db.collection('companies').doc('default_company').set(defaultCompany);
    console.log('✅ Entreprise créée');

    // --- Paramètres ---
    console.log('⚙️ Création des paramètres...');
    await db.collection('settings').doc('global').set(defaultSettings);
    console.log('✅ Paramètres créés');

    // --- Modèle ---
    console.log('📄 Création du modèle...');
    await db.collection('templates').doc('default_1').set(defaultTemplate);
    console.log('✅ Modèle créé');

    // --- Utilisateur Admin ---
    console.log('👤 Création de l\'utilisateur admin...');
    await db.collection('users').doc('admin_user_id').set(adminUser);
    console.log('✅ Utilisateur admin créé');

    // --- Abonnement Admin ---
    console.log('📝 Création de l\'abonnement admin...');
    await db.collection('subscriptions').doc('sub_admin_default').set(adminSubscription);
    console.log('✅ Abonnement admin créé');

    // --- Fournisseur ---
    console.log('🏭 Création du fournisseur...');
    await db.collection('suppliers').doc('supplier_1').set(supplier);
    console.log('✅ Fournisseur créé');

    // --- Produit ---
    console.log('📦 Création du produit...');
    await db.collection('products').doc('product_1').set(product);
    console.log('✅ Produit créé');

    // --- Client ---
    console.log('👥 Création du client...');
    await db.collection('clients').doc('client_1').set(client);
    console.log('✅ Client créé');

    // --- Facture ---
    console.log('📄 Création de la facture...');
    await db.collection('invoices').doc('invoice_1').set(invoice);
    console.log('✅ Facture créée');

    // --- Log ---
    console.log('📝 Création du log...');
    await db.collection('logs').doc('log_1').set(log);
    console.log('✅ Log créé');

    console.log('✅ Initialisation Firestore terminée avec succès !');
    console.log('ℹ️ N\'oubliez pas de remplacer "admin_user_id" par l\'UID réel de votre admin dans la console Firebase.');
  } catch (error) {
    console.error('❌ Erreur lors de l\'initialisation:', error);
  }
}

// Exécution
initializeFirestore();