// lib/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// Modèles
import '../models/delivery.dart';
import '../models/plan.dart';

// Providers
import '../providers/auth_provider.dart';

// Écrans - Auth / Landing
import '../screens/landing/landing_screen_carousel.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/verify_2fa_screen.dart';

// Écrans - Dashboard & Stock
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/dashboard/profile_update_screen.dart';
import '../screens/dashboard/stock/stock_screen.dart';
import '../screens/dashboard/stock/products_screen.dart';
import '../screens/dashboard/stock/product_detail_screen.dart';
import '../screens/dashboard/stock/create_delivery_screen.dart';

// Écrans - Clients, Factures & Fournisseurs
import '../screens/dashboard/clients_screen.dart';
import '../screens/dashboard/create_client_screen.dart';
import '../screens/dashboard/client_detail_screen.dart';
import '../screens/dashboard/invoices_screen.dart';
import '../screens/dashboard/create_invoice_screen.dart';
import '../screens/dashboard/invoice_detail_screen.dart';
import '../screens/dashboard/suppliers/suppliers_screen.dart';
import '../screens/dashboard/suppliers/create_supplier_screen.dart';

// Écrans - Utilitaires & Analytics
import '../screens/dashboard/analytics_screen.dart';
import '../screens/dashboard/settings_screen.dart';
import '../screens/dashboard/company_config_screen.dart';
import '../screens/dashboard/reminders_screen.dart';
import '../screens/status/no_internet_screen.dart';

// Écrans - Customisation, Abonnements & Support
import '../screens/customization/invoice_customization_screen.dart';
import '../screens/customization/templates_screen.dart';
import '../screens/subscription/subscription_screen.dart';
import '../screens/subscription/payment_screen.dart';
import '../screens/notifications/notification_screen.dart';
import '../screens/support/support_screen.dart';
import '../screens/support/faq_screen.dart';
import '../screens/support/contact_support_screen.dart';
import '../screens/security/security_screen.dart';
import '../screens/security/sessions_screen.dart';

// Écrans - Admin
import '../screens/admin/admin_dashboard.dart';
import '../screens/admin/users_list_screen.dart';
import '../screens/admin/user_detail_screen.dart';
import '../screens/admin/user_subscription_screen.dart';
import '../screens/admin/activity_logs_screen.dart';
import '../screens/admin/admin_add_subscription_screen.dart';
import '../screens/admin/admin_template_form_screen.dart';
import '../screens/admin/admin_plan_form_screen.dart';
import '../screens/admin/admin_assign_plan_screen.dart';

class AppRouter {
  static final Listenable authChangeNotifier = ValueNotifier<void>(null);

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: authChangeNotifier,
    redirect: (context, state) {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final isAuthenticated = authProvider.isAuthenticated;
      final needs2Fa = authProvider.needsTwoFactor;
      final location = state.uri.path;

      if (needs2Fa) {
        if (location != '/auth/verify-2fa') {
          return '/auth/verify-2fa';
        }
        return null;
      }

      if (isAuthenticated && (location == '/' || location.startsWith('/auth'))) {
        return '/dashboard';
      }

      if (!isAuthenticated &&
          (location.startsWith('/dashboard') ||
              location.startsWith('/admin') ||
              location.startsWith('/security'))) {
        return '/';
      }

      if (!isAuthenticated && location == '/subscription') {
        return '/auth/login';
      }

      return null;
    },
    routes: [
      // Landing / Accueil
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingScreen(),
      ),

      // Auth group
      GoRoute(
        path: '/auth',
        redirect: (context, state) => '/auth/login',
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/verify-2fa',
        builder: (context, state) => const VerifyTwoFactorScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Abonnement
      GoRoute(
        path: '/subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/subscription/payment',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return PaymentScreen(
            plan: extra?['plan'] as Plan,
            onPaymentComplete: () {},
          );
        },
      ),

      // Support
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: '/support/faq',
        builder: (context, state) => const FaqScreen(),
      ),
      GoRoute(
        path: '/support/contact',
        builder: (context, state) => const ContactSupportScreen(),
      ),

      // Sécurité & Sessions
      GoRoute(
        path: '/security',
        builder: (context, state) => const SecurityScreen(),
      ),
      GoRoute(
        path: '/security/sessions',
        builder: (context, state) => const SessionsScreen(),
      ),

      // Customisation visuelle des factures
      GoRoute(
        path: '/customization',
        builder: (context, state) => const InvoiceCustomizationScreen(),
      ),
      GoRoute(
        path: '/templates',
        builder: (context, state) => const TemplatesScreen(),
      ),

      // Notifications
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),

      // Relances / Rappels
      GoRoute(
        path: '/dashboard/reminders',
        builder: (context, state) => const RemindersScreen(),
      ),

      // Erreur réseau
      GoRoute(
        path: '/no-internet',
        builder: (context, state) => const NoInternetScreen(
          onRetry: null, // onRetry sera géré par le wrapper
        ),
      ),

      // ========== ESPACE DASHBOARD ==========
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/dashboard/profile',
        builder: (context, state) => const ProfileUpdateScreen(),
      ),

      // Stock & Produits
      GoRoute(
        path: '/dashboard/stock',
        builder: (context, state) => const StockScreen(),
      ),
      GoRoute(
        path: '/dashboard/stock/products',
        builder: (context, state) => const ProductsScreen(),
      ),
      GoRoute(
        path: '/dashboard/stock/products/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ProductDetailScreen(productId: id);
        },
      ),
      GoRoute(
        path: '/dashboard/stock/create-delivery',
        builder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? '';
          final name = state.uri.queryParameters['name'] ?? '';
          return CreateDeliveryScreen(
            productId: id,
            productName: name,
            type: DeliveryType.out,
          );
        },
      ),

      // Clients
      GoRoute(
        path: '/dashboard/clients',
        builder: (context, state) => const ClientsScreen(),
      ),
      GoRoute(
        path: '/dashboard/clients/create',
        builder: (context, state) => const CreateClientScreen(),
      ),
      GoRoute(
        path: '/dashboard/clients/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ClientDetailScreen(clientId: id);
        },
      ),

      // Factures
      GoRoute(
        path: '/dashboard/invoices',
        builder: (context, state) => const InvoicesScreen(),
      ),
      GoRoute(
        path: '/dashboard/invoices/create',
        builder: (context, state) => const CreateInvoiceScreen(),
      ),
      GoRoute(
        path: '/dashboard/invoices/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return InvoiceDetailScreen(invoiceId: id);
        },
      ),

      // Statistiques & Entreprise
      GoRoute(
        path: '/dashboard/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/dashboard/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/dashboard/company-config',
        builder: (context, state) => const CompanyConfigScreen(),
      ),

      // Fournisseurs
      GoRoute(
        path: '/suppliers',
        builder: (context, state) => const SuppliersScreen(),
      ),
      GoRoute(
        path: '/suppliers/create',
        builder: (context, state) => const CreateSupplierScreen(),
      ),

      // ========== ESPACE ADMINISTRATION ==========
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminDashboard(),
        redirect: (context, state) {
          final auth = Provider.of<AppAuthProvider>(context, listen: false);
          if (auth.user?.isAdmin != true) {
            return '/dashboard';
          }
          return null;
        },
        routes: [
          GoRoute(
            path: 'users',
            name: 'admin-users',
            builder: (context, state) => const UsersListScreen(),
          ),
          GoRoute(
            path: 'users/:userId',
            name: 'admin-user-detail',
            builder: (context, state) {
              final userId = state.pathParameters['userId']!;
              return UserDetailScreen(userId: userId);
            },
          ),
          GoRoute(
            path: 'users/:userId/subscriptions',
            name: 'admin-user-subscriptions',
            builder: (context, state) {
              final userId = state.pathParameters['userId']!;
              return UserSubscriptionScreen(userId: userId);
            },
          ),
          GoRoute(
            path: 'logs',
            name: 'admin-logs',
            builder: (context, state) {
              final userId = state.uri.queryParameters['userId'];
              return ActivityLogsScreen(userId: userId);
            },
          ),
          GoRoute(
            path: 'add-subscription',
            name: 'admin-add-subscription',
            builder: (context, state) => const AdminAddSubscriptionScreen(),
          ),
          GoRoute(
            path: 'users/:userId/add-subscription',
            name: 'admin-add-subscription-user',
            builder: (context, state) {
              final userId = state.pathParameters['userId']!;
              return AdminAddSubscriptionScreen(userId: userId);
            },
          ),
          GoRoute(
            path: 'templates/create',
            name: 'admin-template-create',
            builder: (context, state) => const AdminTemplateFormScreen(
              templateId: null,
            ),
          ),
          GoRoute(
            path: 'templates/edit/:id',
            name: 'admin-template-edit',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return AdminTemplateFormScreen(templateId: id);
            },
          ),

          // ✅ Gestion des plans personnalisés
          GoRoute(
            path: 'plans/create',
            name: 'admin-plan-create',
            builder: (context, state) => const AdminPlanFormScreen(),
          ),
          GoRoute(
            path: 'plans/edit/:id',
            name: 'admin-plan-edit',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return AdminPlanFormScreen(planId: id);
            },
          ),
          GoRoute(
            path: 'assign-plan',
            name: 'admin-assign-plan',
            builder: (context, state) => const AdminAssignPlanScreen(),
          ),
        ],
      ),
    ],
  );
}