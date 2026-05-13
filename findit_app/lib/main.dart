import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/staff/staff_home_screen.dart';
import 'screens/staff/institution_setup_screen.dart';
import 'screens/staff/pending_approval_screen.dart';
import 'screens/staff/log_item_screen.dart';
import 'screens/staff/claim_review_screen.dart';
import 'screens/owner/owner_home_screen.dart';
import 'screens/owner/institution_items_screen.dart';
import 'screens/owner/item_detail_owner_screen.dart';
import 'screens/owner/submit_claim_screen.dart';
import 'screens/owner/claim_status_screen.dart';
import 'screens/shared/claim_chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const FindItApp());
}

class FindItApp extends StatelessWidget {
  const FindItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FindItAuthProvider(),
      child: MaterialApp(
        title: 'FindIt',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4A90D9),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          navigationBarTheme: const NavigationBarThemeData(
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          ),
        ),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/staff-home': (_) => const StaffHomeScreen(),
          '/owner-home': (_) => const OwnerHomeScreen(),
          '/admin-dashboard': (_) => const AdminDashboardScreen(),
          '/pending-approval': (_) => const PendingApprovalScreen(),
          '/log-item': (_) => const LogItemScreen(),
        },
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _loadTriggered = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        if (!snapshot.hasData) {
          _loadTriggered = false;
          return const LoginScreen();
        }

        return Consumer<FindItAuthProvider>(
          builder: (_, auth, __) {
            if (!_loadTriggered) {
              _loadTriggered = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) context.read<FindItAuthProvider>().tryLoadUser();
              });
            }

            if (auth.initializing) return const _LoadingScreen();

            final role = (auth.currentUser?.role ?? '').toLowerCase();

            if (role == 'admin') return const AdminDashboardScreen();
            if (role == 'owner') return const OwnerHomeScreen();

            if (role == 'staff') {
              if (auth.currentUser?.institutionId == null) {
                return const InstitutionSetupScreen();
              }
              final status = (auth.institution?.status ?? '').toLowerCase();
              if (status == 'active') return const StaffHomeScreen();
              return const PendingApprovalScreen();
            }

            return const RegisterScreen();
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.search_rounded, size: 40, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text('FindIt',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                    letterSpacing: 1.2)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
