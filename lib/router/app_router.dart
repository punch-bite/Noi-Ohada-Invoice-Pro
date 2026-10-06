// lib/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:noi_ohada_invoice_pro/screens/landing/landing_screen.dart';
import 'package:noi_ohada_invoice_pro/screens/teams/create_team_screen.dart';
import 'package:noi_ohada_invoice_pro/screens/teams/team_detail_screen.dart';
import 'package:noi_ohada_invoice_pro/screens/teams/team_invitations_screen.dart';
import 'package:noi_ohada_invoice_pro/screens/teams/team_chat_screen.dart';
import 'package:noi_ohada_invoice_pro/screens/webview/webview_screen.dart';
import 'package:provider/provider.dart';

// Modèles
import '../models/delivery.dart';
import '../models/plan.dart';

// Providers
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';

// Écrans - Auth / Landing
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/verify_2fa_screen.dart';

// Écrans - Dashboard & Stock
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/dashboard/profile_update_screen.dart';
import '../screens/dashboard/stock/stock_screen.dart';
import '../screens/dashboard/stock/product_detail_screen.dart';
import '../screens/dashboard/stock/create_delivery_screen.dart';

// Écrans - Clients, Factures & Fournisseurs
import '../screens/dashboard/clients_screen.dart';
import '../screens/dashboard/create_client_screen.dart';
import '../screens/dashboard/client_detail_screen.dart';
import '../screens/dashboard/invoices_screen.dart';
import '../screens/dashboard/create_invoice_screen.dart';
import '../screens/dashboard/invoice_detail_screen.dart';
import '../screens/dashboard/invoice_print_preview_screen.dart';
import '../screens/dashboard/suppliers/suppliers_screen.dart';
import '../screens/dashboard/suppliers/create_supplier_screen.dart';

// Écrans - Utilitaires & Analytics
import '../screens/dashboard/analytics_screen.dart';
import '../screens/dashboard/settings_screen.dart';
import '../screens/dashboard/invoice_settings_edit_screen.dart';
import '../screens/dashboard/data_export_screen.dart';
import '../screens/dashboard/wallet_screen.dart';
import '../screens/dashboard/company_config_screen.dart';
import '../screens/dashboard/reminders_screen.dart';
import '../screens/dashboard/relance_screen.dart';
import '../screens/dashboard/drive_sync_screen.dart';
import '../screens/status/no_internet_screen.dart';

// Écrans - Customisation, Abonnements & Support
import '../screens/customization/template_store_screen.dart';
import '../screens/customization/template_checkout_screen.dart';
import '../screens/customization/my_templates_screen.dart';
import '../screens/customization/templates_screen.dart';
import '../screens/customization/template_workspace_screen.dart';
import '../screens/customization/template_preview_screen.dart';
import '../screens/dev/enkap_test_screen.dart';
import '../models/invoice_template.dart';
import '../screens/subscription/subscription_screen.dart';
import '../screens/subscription/payment_screen.dart';
import '../screens/notifications/notification_screen.dart';
import '../screens/support/support_screen.dart';
import '../screens/support/faq_screen.dart';
import '../screens/support/contact_support_screen.dart';
import '../screens/support/legal_screen.dart';
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
import '../screens/admin/admin_templates_screen.dart';
import '../screens/admin/admin_withdrawals_screen.dart';
import '../screens/admin/admin_plan_form_screen.dart';
import '../screens/admin/admin_assign_plan_screen.dart';

// Écrans - Teams (partage)
import '../screens/teams/team_shared_with_me_screen.dart';
import '../screens/teams/teams_screen.dart';

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

      // 🔐 2FA en cours → forcer la page de vérification.
      if (needs2Fa) {
        if (location != '/auth/verify-2fa') {
          return '/auth/verify-2fa';
        }
        return null;
      }

      // ✅ Déjà connecté → rediriger vers le dashboard depuis la racine/auth.
      if (isAuthenticated &&
          (location == '/' || location.startsWith('/auth'))) {
        return '/dashboard';
      }

      // 🚫 Non connecté → protéger les zones privées.
      if (!isAuthenticated &&
          (location.startsWith('/dashboard') ||
              location.startsWith('/admin') ||
              location.startsWith('/security'))) {
        return '/';
      }

      // 🚫 Non connecté → abonnement protégé.
      if (!isAuthenticated && location == '/subscription') {
        return '/auth/login';
      }

      return null;
    },
    routes: [
      // ══════════════════════════════════════════════════════════
      //  LANDING
      // ══════════════════════════════════════════════════════════
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingScreen(),
      ),

      // ══════════════════════════════════════════════════════════
      //  AUTH
      // ══════════════════════════════════════════════════════════
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

      // ══════════════════════════════════════════════════════════
      //  ABONNEMENT
      // ══════════════════════════════════════════════════════════
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

      // ══════════════════════════════════════════════════════════
      //  ÉQUIPES
      // ══════════════════════════════════════════════════════════
      GoRoute(
        path: '/teams',
        builder: (context, state) => const TeamsScreen(),
      ),
      // 🔒 La création est réservée au premium.
      GoRoute(
        path: '/teams/create',
        redirect: (context, state) {
          final sub = Provider.of<SubscriptionProvider>(context, listen: false);
          if (!sub.hasTeamAccess) return '/subscription';
          return null;
        },
        builder: (context, state) => const CreateTeamScreen(),
      ),
      GoRoute(
        path: '/teams/invitations',
        builder: (context, state) => const TeamInvitationsScreen(),
      ),
      // 💬 Messagerie d'équipe (temps réel + historique local Hive).
      GoRoute(
        path: '/teams/chat',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            return TeamChatScreen(
              teamId: extra['teamId']?.toString() ?? '',
              teamName: extra['teamName']?.toString() ?? 'Équipe',
            );
          }
          return const SizedBox.shrink();
        },
      ),
      // ✅ `/teams/shared-with-me` DOIT passer AVANT `/teams/:id`,
      // sinon `shared-with-me` est capturé comme un ID d'équipe.
      GoRoute(
        path: '/teams/shared-with-me',
        name: 'team-shared-with-me',
        builder: (context, state) {
          final extra = state.extra;
          String teamId = '';
          if (extra is Map && extra['teamId'] is String) {
            teamId = extra['teamId'] as String;
          }
          return TeamSharedWithMeScreen(teamId: teamId);
        },
      ),
      GoRoute(
        path: '/teams/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TeamDetailScreen(teamId: id);
        },
      ),

      // ══════════════════════════════════════════════════════════
      //  WEBVIEW
      // ══════════════════════════════════════════════════════════
      GoRoute(
        path: '/webview',
        builder: (context, state) {
          final extra = state.extra;
          final query = state.uri.queryParameters;
          final url = (extra is Map<String, dynamic>
                  ? extra['url']?.toString()
                  : null) ??
              query['url'] ??
              'https://noiconcept.com';
          final title = (extra is Map<String, dynamic>
                  ? extra['title']?.toString()
                  : null) ??
              query['title'] ??
              'Navigation';
          return WebViewScreen(url: url, title: title);
        },
      ),

      // ══════════════════════════════════════════════════════════
      //  SUPPORT
      // ══════════════════════════════════════════════════════════
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
      GoRoute(
        path: '/support/legal/mentions',
        builder: (context, state) =>
            const LegalScreen(page: LegalPage.mentions),
      ),
      GoRoute(
        path: '/support/legal/privacy',
        builder: (context, state) => const LegalScreen(page: LegalPage.privacy),
      ),
      GoRoute(
        path: '/support/legal/license',
        builder: (context, state) => const LegalScreen(page: LegalPage.license),
      ),
      GoRoute(
        path: '/support/legal/ownership',
        builder: (context, state) =>
            const LegalScreen(page: LegalPage.ownership),
      ),

      // ══════════════════════════════════════════════════════════
      //  SÉCURITÉ
      // ══════════════════════════════════════════════════════════
      GoRoute(
        path: '/security',
        builder: (context, state) => const SecurityScreen(),
      ),
      GoRoute(
        path: '/security/sessions',
        builder: (context, state) => const SessionsScreen(),
      ),

      // ══════════════════════════════════════════════════════════
      //  DRIVE SYNC
      // ══════════════════════════════════════════════════════════
      GoRoute(
        path: '/settings/drive-sync',
        builder: (context, state) => const DriveSyncScreen(),
      ),

      // ══════════════════════════════════════════════════════════
      //  MODÈLES — Boutique & Personnalisation
      // ══════════════════════════════════════════════════════════
      GoRoute(
        path: '/templates',
        builder: (context, state) => const TemplateStoreScreen(),
      ),
      GoRoute(
        path: '/templates/checkout',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is InvoiceTemplate) {
            return TemplateCheckoutScreen(template: extra);
          }
          if (extra is List<InvoiceTemplate> && extra.isNotEmpty) {
            return TemplateCheckoutScreen(cartTemplates: extra);
          }
          if (extra is Map<String, dynamic>) {
            final t = extra['template'];
            final cart = extra['cartTemplates'];
            return TemplateCheckoutScreen(
              template: t is InvoiceTemplate ? t : null,
              cartTemplates: cart is List<InvoiceTemplate> ? cart : null,
            );
          }
          return const TemplateCheckoutScreen();
        },
      ),
      GoRoute(
        path: '/templates/mine',
        builder: (context, state) => const MyTemplatesScreen(),
      ),
      GoRoute(
        path: '/templates/select',
        builder: (context, state) => const TemplatesScreen(),
      ),
      GoRoute(
        path: '/templates/workspace',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is InvoiceTemplate) {
            return TemplateWorkspaceScreen(template: extra);
          }
          if (extra is Map<String, dynamic> &&
              extra['template'] is InvoiceTemplate) {
            return TemplateWorkspaceScreen(
                template: extra['template'] as InvoiceTemplate);
          }
          return const SizedBox.shrink();
        },
      ),
      GoRoute(
        path: '/templates/preview',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is InvoiceTemplate) {
            return TemplatePreviewScreen(template: extra);
          }
          if (extra is Map<String, dynamic> &&
              extra['template'] is InvoiceTemplate) {
            return TemplatePreviewScreen(
              template: extra['template'] as InvoiceTemplate,
            );
          }
          return const SizedBox.shrink();
        },
      ),

      // ══════════════════════════════════════════════════════════
      //  DEV / TEST
      // ══════════════════════════════════════════════════════════
      GoRoute(
        path: '/dev/enkap-test',
        builder: (context, state) => const EnkapTestScreen(),
        redirect: (context, state) {
          final auth = Provider.of<AppAuthProvider>(context, listen: false);
          if (auth.user?.isAdmin != true) {
            return '/dashboard';
          }
          return null;
        },
      ),

      // ══════════════════════════════════════════════════════════
      //  NOTIFICATIONS
      // ══════════════════════════════════════════════════════════
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),

      // ══════════════════════════════════════════════════════════
      //  RELANCES / RAPPELS
      // ══════════════════════════════════════════════════════════
      GoRoute(
        path: '/dashboard/reminders',
        builder: (context, state) => const RemindersScreen(),
      ),
      GoRoute(
        path: '/dashboard/relance',
        builder: (context, state) => const RelanceScreen(),
      ),
      GoRoute(
        path: '/dashboard/relance/:clientId',
        builder: (context, state) => RelanceScreen(
          initialClientId: state.pathParameters['clientId'],
        ),
      ),

      // ══════════════════════════════════════════════════════════
      //  ERREUR RÉSEAU
      // ══════════════════════════════════════════════════════════
      GoRoute(
        path: '/no-internet',
        builder: (context, state) => const NoInternetScreen(
          onRetry: null,
        ),
      ),

      // ══════════════════════════════════════════════════════════
      //  DASHBOARD
      // ══════════════════════════════════════════════════════════
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/dashboard/profile',
        builder: (context, state) => const ProfileUpdateScreen(),
      ),

      // ── Stock & Produits ──
      GoRoute(
        path: '/dashboard/stock',
        builder: (context, state) => const StockScreen(),
      ),
      // ✅ Les routes statiques AVANT les routes dynamiques.
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
      GoRoute(
        path: '/dashboard/stock/products/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ProductDetailScreen(productId: id);
        },
      ),

      // ── Clients ──
      GoRoute(
        path: '/dashboard/clients',
        builder: (context, state) => const ClientsScreen(),
      ),
      // ✅ `/create` DOIT passer AVANT `/:id`, sinon "create" est capturé
      // comme un ID de client → ClientDetailScreen avec id = "create".
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

      // ── Factures ──
      GoRoute(
        path: '/dashboard/invoices',
        builder: (context, state) => const InvoicesScreen(),
      ),
      // ✅ `/create` AVANT `/:id`.
      GoRoute(
        path: '/dashboard/invoices/create',
        builder: (context, state) => const CreateInvoiceScreen(),
      ),
      GoRoute(
        path: '/dashboard/invoices/:id/print',
        builder: (context, state) {
          final args = state.extra;
          if (args is InvoicePrintPreviewArgs) {
            return InvoicePrintPreviewScreen(args: args);
          }
          return InvoiceDetailScreen(
            invoiceId: state.pathParameters['id']!,
          );
        },
      ),
      GoRoute(
        path: '/dashboard/invoices/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return InvoiceDetailScreen(invoiceId: id);
        },
      ),

      // ── Statistiques & Entreprise ──
      GoRoute(
        path: '/dashboard/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/dashboard/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/dashboard/settings/invoice',
        builder: (context, state) => const InvoiceSettingsEditScreen(),
      ),
      GoRoute(
        path: '/dashboard/settings/export',
        builder: (context, state) => const DataExportScreen(),
      ),
      GoRoute(
        path: '/dashboard/company-config',
        builder: (context, state) => const CompanyConfigScreen(),
      ),

      // ── Portefeuille ──
      GoRoute(
        path: '/wallet',
        builder: (context, state) => const WalletScreen(),
      ),

      // ── Fournisseurs ──
      GoRoute(
        path: '/suppliers',
        builder: (context, state) => const SuppliersScreen(),
      ),
      GoRoute(
        path: '/suppliers/create',
        builder: (context, state) => const CreateSupplierScreen(),
      ),

      // ══════════════════════════════════════════════════════════
      //  ADMINISTRATION
      // ══════════════════════════════════════════════════════════
      //
      // ⚠️ Le `redirect` du parent `/admin` s'applique à TOUTES les routes
      // enfants (`/admin/users`, `/admin/logs`, etc.). On laisse passer tant
      // que `auth.user` n'est pas chargé, sinon un admin fraîchement connecté
      // est renvoyé vers `/dashboard` avant que Firestore n'ait répondu.
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminDashboard(),
        redirect: (context, state) {
          final auth = Provider.of<AppAuthProvider>(context, listen: false);
          if (auth.user == null) return null; // ⏳ laisser charger
          if (auth.user!.isAdmin != true) return '/dashboard';
          return null;
        },
        routes: [
          // ── Utilisateurs ──
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
            path: 'users/:userId/add-subscription',
            name: 'admin-add-subscription-user',
            builder: (context, state) {
              final userId = state.pathParameters['userId']!;
              return AdminAddSubscriptionScreen(userId: userId);
            },
          ),

          // ── Logs ──
          GoRoute(
            path: 'logs',
            name: 'admin-logs',
            builder: (context, state) {
              final userId = state.uri.queryParameters['userId'];
              return ActivityLogsScreen(userId: userId);
            },
          ),

          // ── Abonnements ──
          GoRoute(
            path: 'add-subscription',
            name: 'admin-add-subscription',
            builder: (context, state) => const AdminAddSubscriptionScreen(),
          ),
          GoRoute(
            path: 'assign-plan',
            name: 'admin-assign-plan',
            builder: (context, state) => const AdminAssignPlanScreen(),
          ),

          // ── Modèles de factures ──
          // ✅ Les routes STATIQUES (`create`) DOIVENT passer AVANT les
          // routes DYNAMIQUES (`edit/:id`), sinon "create" serait capturé
          // comme un ID.
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
          GoRoute(
            path: 'templates',
            name: 'admin-templates',
            builder: (context, state) => const AdminTemplatesScreen(),
          ),

          // ── Retraits ──
          GoRoute(
            path: 'withdrawals',
            name: 'admin-withdrawals',
            builder: (context, state) => const AdminWithdrawalsScreen(),
          ),

          // ── Plans ──
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
        ],
      ),
    ],
  );
}