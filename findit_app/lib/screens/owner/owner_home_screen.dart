import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  final _api = ApiService();
  bool _loadingInstitutions = true;
  List<Map<String, dynamic>> _institutions = [];

  @override
  void initState() {
    super.initState();
    _loadInstitutions();
  }

  Future<void> _loadInstitutions() async {
    try {
      final json = await _api.get('/institutions');
      final list = (json as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((inst) => (inst['status'] as String? ?? '').toLowerCase() == 'active')
          .toList();
      if (!mounted) return;
      setState(() => _institutions = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _institutions = []);
    } finally {
      if (mounted) setState(() => _loadingInstitutions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<FindItAuthProvider>().currentUser;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FindIt'),
        backgroundColor: cs.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh institutions',
            onPressed: _loadingInstitutions ? null : _loadInstitutions,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () => context.read<FindItAuthProvider>().logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Icon(Icons.search_rounded, size: 64, color: cs.primary),
          const SizedBox(height: 16),
          Text(
            'Welcome${user?.fullName != null ? ', ${user!.fullName}' : ''}!',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Find your lost item',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              // TODO: navigate to search screen (Slice 3)
            },
            icon: const Icon(Icons.search_rounded),
            label: const Text('Search'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(220, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Available Institutions',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_loadingInstitutions)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ))
          else if (_institutions.isEmpty)
            Text(
              'No active institutions available right now.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            )
          else
            ..._institutions.map((inst) {
              final name = inst['name'] as String? ?? 'Unnamed institution';
              final type = (inst['type'] as String? ?? 'other').toUpperCase();
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: ListTile(
                  leading: Icon(Icons.business_rounded, color: cs.primary),
                  title: Text(name),
                  subtitle: Text(type),
                ),
              );
            }),
        ],
      ),
    );
  }
}
