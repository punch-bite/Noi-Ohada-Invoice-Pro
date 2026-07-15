// lib/router/app_router.dart
import 'package:go_router/go_router.dart';
import 'package:noi_ohada_invoice_pro/screens/dashboard/stock/product_detail_screen.dart';
import 'package:noi_ohada_invoice_pro/screens/dashboard/stock/products_screen.dart';
import 'package:provider/provider.dart';
import '../models/delivery.dart';
import '../providers/auth_provider.dart';
import '../screens/dashboard/profile_update_screen.dart';
import '../screens/dashboard/stock/create_delivery_screen.dart';
import '../screens/dashboard/stock/stock_screen.dart';
import '../screens/landing/landing_screen_carousel.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/dashboard/clients_screen.dart';
import '../screens/dashboard/invoices_screen.dart';
import '../screens/dashboard/analytics_screen.dart';
import '../screens/dashboard/settings_screen.dart';
import '../screens/dashboard/create_invoice_screen.dart';
import '../screens/dashboard/create_client_screen.dart';
import '../screens/dashboard/invoice_detail_screen.dart';
import '../screens/dashboard/client_detail_screen.dart';
import '../screens/subscription/subscription_screen.dart';
import '../screens/subscription/payment_screen.dart';
import '../screens/notifications/notification_screen.dart';
import '../screens/support/support_screen.dart';
import '../screens/support/faq_screen.dart';
import '../screens/support/contact_support_screen.dart';
import '../screens/customization/invoice_customization_screen.dart';
import '../screens/customization/templates_screen.dart';
import '../screens/security/security_screen.dart';
import '../screens/security/sessions_screen.dart';
import '../screens/dashboard/company_config_screen.dart';
import '../models/plan.dart';
import '../screens/status/no_internet_screen.dart';
import '../screens/dashboard/reminders_screen.dart';
import '../screens/dashboard/suppliers/suppliers_screen.dart';
import '../screens/dashboard/suppliers/create_supplier_screen.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/admin/users_list_screen.dart';
import '../screens/admin/user_detail_screen.dart';
import '../screens/admin/user_subscription_screen.dart';
import '../screens/admin/activity_logs_screen.dart';
import '../screens/admin/admin_add_subscription_screen.dart';
import '../screens/admin/admin_template_form_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // ✅ Utilisation correcte de Provider sans écoute
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final isAuthenticated = authProvider.isAuthenticated;
      final location = state.uri.path;

      if (isAuthenticated &&
          (location == '/' || location.startsWith('/auth'))) {
        return '/dashboard';
      }

      if (!isAuthenticated && location.startsWith('/dashboard')) {
        return '/';
      }

      if (!isAuthenticated && location == '/subscription') {
        return '/auth/login';
      }

      return null;
    },
    routes: [
      // Landing
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingScreen(),
      ),

      // Auth
      GoRoute(
        path: '/auth',
        redirect: (context, state) => '/auth/login',
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Subscription
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

      // Security
      GoRoute(
        path: '/security',
        builder: (context, state) => const SecurityScreen(),
      ),
      GoRoute(
        path: '/security/sessions',
        builder: (context, state) => const SessionsScreen(),
      ),

      // Customization
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

      // Reminders
      GoRoute(
        path: '/dashboard/reminders',
        builder: (context, state) => const RemindersScreen(),
      ),

      // No Internet
      GoRoute(
        path: '/no-internet',
        builder: (context, state) => const NoInternetScreen(),
      ),

      // ========== DASHBOARD ROUTE ==========
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/dashboard/profile',
        builder: (context, state) => const ProfileUpdateScreen(),
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
      GoRoute(
        path: '/dashboard/stock/products',
        builder: (context, state) => const ProductsScreen(),
      ),
      GoRoute(
        path: '/dashboard/stock/products/:id',
        builder: (context, state) =>
            const ProductDetailScreen(productId: ':id'),
      ),

      // ========== PAGES INDÉPENDANTES ==========
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
      GoRoute(
        path: '/dashboard/stock',
        builder: (context, state) => const StockScreen(),
      ),

      // Suppliers
      GoRoute(
        path: '/suppliers',
        builder: (context, state) => const SuppliersScreen(),
      ),
      GoRoute(
        path: '/suppliers/create',
        builder: (context, state) => const CreateSupplierScreen(),
      ),

      // ========== ADMIN ==========
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
          // 🔥 Routes pour les modèles personnalisés (admin)
          GoRoute(
            path: 'templates/create',
            name: 'admin-template-create',
            builder: (context, state) => const AdminTemplateFormScreen(
              templateId: "id",
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
        ],
      ),
    ],
  );
}
