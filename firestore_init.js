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
// ID ADMIN (⚠️ à remplacer par l'UID réel Firebase Auth)
// ============================================
const ADMIN_UID = crypto.randomUUID();

// ============================================
// 1. PLANS
// ============================================
const plans = {
  free: {
    id: 'free',
    name: 'Gratuit',
    description: 'Pour démarrer avec OHADA Invoice Pro',
    price: 0.0,
    currency: 'XAF',
    interval: 'month',
    maxInvoices: 10,
    maxClients: 5,
    maxProducts: 5,
    hasPdfExport: true,
    hasCloudSync: false,
    hasTeamAccess: false,
    maxTeamMembers: 0,
    hasGoogleDriveSync: false,
    features: ['10 factures', '5 clients', '5 produits', 'Export PDF', 'Stockage Firestore'],
    isPopular: false,
    isActive: true,
    createdAt: new Date()
  },
  pro: {
    id: 'pro',
    name: 'Pro',
    description: 'Pour les PME en croissance',
    price: 9900.0,
    currency: 'XAF',
    interval: 'month',
    maxInvoices: -1,
    maxClients: 200,
    maxProducts: 25,
    hasPdfExport: true,
    hasCloudSync: true,
    hasTeamAccess: false,
    maxTeamMembers: 0,
    hasGoogleDriveSync: false,
    features: [
      'Factures illimitées',
      '200 clients',
      '25 produits',
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
    price: 49000.0,
    currency: 'XAF',
    interval: 'year',
    maxInvoices: -1,
    maxClients: -1,
    maxProducts: -1,
    hasPdfExport: true,
    hasCloudSync: true,
    hasTeamAccess: true,
    maxTeamMembers: 20,
    hasGoogleDriveSync: true,
    features: [
      'Tout le plan Pro',
      'Clients / produits / factures illimités',
      'Module équipe (20 utilisateurs)',
      'Invitation par lien e-mail',
      'Synchronisation Google Drive',
      'Support dédié 24/7'
    ],
    isPopular: false,
    isActive: true,
    createdAt: new Date()
  },
  unlimited: {
    id: 'unlimited',
    name: 'Illimité',
    description: 'Accès illimité réservé aux administrateurs',
    price: 0.0,
    currency: 'XAF',
    interval: 'year',
        maxInvoices: -1,
    maxClients: -1,
    maxProducts: -1,
    hasPdfExport: true,
    hasCloudSync: true,
    hasTeamAccess: true,
    maxTeamMembers: 1000,
    hasGoogleDriveSync: true,
    features: [
      'Factures illimitées',
      'Clients illimités',
      'Produits illimités',
      'Synchronisation cloud',
      'Accès équipe',
      'Google Drive',
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
  name: 'Noi OHADA Invoice Pro',
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
  contactPhone: '+237 620 40 93 83',
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
  category: 'classique',
  createdAt: new Date()
};

// ============================================
// 5. UTILISATEUR ADMIN (conforme au modèle AppUser)
// ============================================
const adminUser = {
  id: ADMIN_UID, // ⚠️ À remplacer par l'UID réel de votre admin
  email: 'nixmmobilier@gmail.com',
  displayName: 'Administrateur',
  phone: '+237 620409383',
  companyName: 'NOI OHADA Invoice Pro',
  companyAddress: 'Douala, Cameroun',
  taxId: 'RC123456789',
  subscriptionId: 'sub_admin_default',
  createdAt: new Date(),
  lastLoginAt: new Date(),
  isActive: true,
  roles: ['user', 'admin']
};

// ============================================
// 6. ABONNEMENT ADMIN (conforme au modèle Subscription)
// ============================================
const adminSubscription = {
  id: 'sub_admin_default',
  userId: adminUser.id, // ⚠️ Même UID que ci-dessus
  planId: 'unlimited',
  startDate: new Date('2024-01-01'),
  endDate: new Date('2099-12-31'),
  status: 'active',
  paymentMethod: 'admin',
  paymentId: 'admin_default',
  amount: 0.0,
  currency: 'XAF',
  autoRenew: true,
  canceledAt: null,
  isActive: true,
  createdAt: new Date(),
  interval: 'year',
  metadata: {
    isAdmin: true,
    unlimited: true
  }
};

// ============================================
// 7. FOURNISSEUR (conforme au modèle Supplier)
// ============================================
const supplier = {
  id: 'supplier_1',
  userId: adminUser.id,
  name: 'Fournisseur Exemple SARL',
  email: 'contact@fournisseur.com',
  phone: '+237 6XX XX XX XX',
  address: 'Douala, Cameroun',
  taxId: 'RC987654321',
  contactPerson: 'Jean Dupont',
  notes: 'Fournisseur principal pour l\'électronique',
  isActive: true,
  createdAt: new Date(),
  updatedAt: new Date(),
  isSynced: true
};

// ============================================
// 8. PRODUIT (conforme au modèle Product)
// ============================================
const product = {
  id: 'product_1',
  userId: adminUser.id,
  name: 'Ordinateur portable HP',
  description: 'Ordinateur portable HP EliteBook',
  category: 'Électronique',
  price: 150000.0,
  costPrice: 120000.0,
  quantity: 10,
  minStock: 3,
  unit: 'pièce',
  barcode: '1234567890123',
  imagePath: '',
  isActive: true,
  createdAt: new Date(),
  updatedAt: new Date(),
  supplierId: 'supplier_1',
  isSynced: true
};

// ============================================
// 9. CLIENT (conforme au modèle Client)
// ============================================
const client = {
  id: 'client_1',
  userId: adminUser.id,
  name: 'Client Exemple SARL',
  address: 'Douala, Cameroun',
  taxId: 'RC1122334455',
  phone: '+237 6XX XX XX XX',
  email: 'client@exemple.com',
  createdAt: new Date(),
  updatedAt: new Date(),
  isActive: true,
  isSynced: true
};

// ============================================
// 10. FACTURE (conforme au modèle Invoice)
// ============================================
const invoice = {
  id: 'invoice_1',
  userId: adminUser.id, // ⚠️ Requis par les règles de sécurité
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
      unitPrice: 150000.0,
      taxRate: 18.0,
      total: 354000.0
    }
  ],
  subtotal: 300000.0,
  taxRate: 18.0,
  taxAmount: 54000.0,
  discount: 0.0,
  totalAmount: 354000.0,
  status: 'sent',
  terms: 'Paiement à 30 jours',
  isDevis: false,
  notes: 'Facture pour commande de janvier',
  updatedAt: new Date(),
  syncedAt: new Date()
};

// ============================================
// 11. LOG (conforme au modèle ActivityLog)
// ============================================
const log = {
  id: 'log_1',
  userId: adminUser.id,
  userEmail: adminUser.email,
  action: 'login',
  targetId: adminUser.id,
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
    await db.collection('users').doc(ADMIN_UID).set(adminUser);
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

    // --- Notification (exemple) ---
    const notification1 = { id: 'notif_1', userId: ADMIN_UID, type: 'welcome', title: 'Bienvenue !', body: 'Configurez votre entreprise.', isRead: false, createdAt: new Date() };
        await db.collection('notifications').doc('notif_1').set(notification1);
    console.log('✅ Notification créée');

    // --- Équipe (module Business) ---
    const team = { id: 'team_1', name: 'Équipe de direction', ownerId: ADMIN_UID, memberIds: [ADMIN_UID], adminIds: [ADMIN_UID], invitationLink: '', isActive: true, createdAt: new Date(), updatedAt: new Date() };
    await db.collection('teams').doc('team_1').set(team);
    console.log('✅ Équipe créée');

    // --- Synchronisation Google Drive (état) ---
    const driveSync = { id: 'drive_sync_1', userId: ADMIN_UID, enabled: false, folderId: '', lastSyncAt: null, intervalDays: 7, createdAt: new Date(), updatedAt: new Date() };
    await db.collection('drive_sync').doc('drive_sync_1').set(driveSync);
    console.log('✅ Google Drive sync état créé');

        console.log('✅ Initialisation Firestore terminée avec succès !');
    console.log(`ℹ️ N'oubliez pas de remplacer "${ADMIN_UID}" par l'UID réel de votre admin dans la console Firebase.`);
  } catch (error) {
    console.error('❌ Erreur lors de l\'initialisation:', error);
  }
}

// Exécution
initializeFirestore();