import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool _checking = false;

  Future<void> _checkStatus() async {
    setState(() => _checking = true);
    try {
      await context.read<FindItAuthProvider>().refreshInstitutionStatus();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FindItAuthProvider>();
    final institution = auth.institution;
    final cs = Theme.of(context).colorScheme;

    final status = (institution?.status ?? '').toLowerCase();
    final isSuspended = status == 'suspended';
    final title = isSuspended ? 'Account Suspended' : 'Awaiting Approval';
    final message = isSuspended
        ? 'Your institution access has been suspended. Please contact support for assistance.'
        : 'Your registration is being reviewed. We will notify you once your institution is approved — usually within 24 hours.';
    final icon =
        isSuspended ? Icons.block_rounded : Icons.hourglass_top_rounded;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('FindIt'),
        backgroundColor: cs.surface,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () async {
              await context.read<FindItAuthProvider>().logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: cs.primary),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (!isSuspended) ...[
                const SizedBox(height: 32),
                _checking
                    ? const CircularProgressIndicator()
                    : FilledButton.icon(
                        onPressed: _checkStatus,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Check Approval Status'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
              ],
              if (institution?.name != null ||
                  institution?.contactEmail != null) ...[
                const SizedBox(height: 32),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.outline.withOpacity(0.4)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (institution?.name != null) ...[
                          _InfoRow(
                            icon: Icons.business_outlined,
                            label: 'Institution',
                            value: institution!.name,
                          ),
                        ],
                        if (institution?.name != null &&
                            institution?.contactEmail != null)
                          const SizedBox(height: 14),
                        if (institution?.contactEmail != null) ...[
                          _InfoRow(
                            icon: Icons.email_outlined,
                            label: 'Contact',
                            value: institution!.contactEmail!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
