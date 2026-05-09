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
import 'screens/owner/owner_home_screen.dart';

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
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A90D9)),
          useMaterial3: true,
        ),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/staff-home': (_) => const StaffHomeScreen(),
          '/owner-home': (_) => const OwnerHomeScreen(),
          '/admin-dashboard': (_) => const AdminDashboardScreen(),
          '/pending-approval': (_) => const PendingApprovalScreen(),
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
          return const _Loading();
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

            if (auth.initializing) return const _Loading();

            final role = (auth.currentUser?.role ?? '').toLowerCase();

            if (role == 'admin') return const AdminDashboardScreen();
            if (role == 'owner') return const OwnerHomeScreen();

            if (role == 'staff') {
              final status = (auth.institution?.status ?? '').toLowerCase();
              final isApproved = status == 'active';
              if (auth.currentUser?.institutionId == null) {
                return const InstitutionSetupScreen();
              }
              if (isApproved) {
                return const StaffHomeScreen();
              }
              return const PendingApprovalScreen();
            }

            // No backend record — let them register
            return const RegisterScreen();
          },
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
