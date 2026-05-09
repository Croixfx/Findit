import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _staff = [];
  List<Map<String, dynamic>> _institutions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.get('/admin/stats'),
        _api.get('/admin/users'),
        _api.get('/admin/staff'),
        _api.get('/admin/institutions'),
      ]);
      setState(() {
        _stats = Map<String, dynamic>.from(results[0] as Map);
        _users = _toMapList(results[1]);
        _staff = _toMapList(results[2]);
        _institutions = _toMapList(results[3]);
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _toMapList(dynamic data) {
    if (data is! List) return [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  String _instStatus(Map<String, dynamic> user) {
    final inst = user['institution'];
    if (inst is Map) return (inst['status'] as String? ?? 'pending').toLowerCase();
    return '';
  }

  String _instName(Map<String, dynamic> user) {
    final inst = user['institution'];
    if (inst is Map) return inst['name'] as String? ?? 'Unknown';
    return 'No institution';
  }

  Future<void> _run(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _approveStaff(Map<String, dynamic> user, bool approve) async {
    final id = user['_id'] as String? ?? '';
    if (id.isEmpty) return;
    await _run(() async {
      await _api.post('/admin/staff/$id/approval', {
        'action': approve ? 'approve' : 'reject',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Institution approved' : 'Institution rejected')),
      );
      await _load();
    });
  }

  Future<void> _toggleSuspend(Map<String, dynamic> user) async {
    final id = user['_id'] as String? ?? '';
    if (id.isEmpty) return;
    final current = user['suspended'] == true;
    await _run(() async {
      await _api.patch('/admin/users/$id', {'suspended': !current});
      await _load();
    });
  }

  Future<void> _promoteToStaff(Map<String, dynamic> user) async {
    final id = user['_id'] as String? ?? '';
    if (id.isEmpty) return;
    await _run(() async {
      await _api.post('/admin/staff/promote', {'userId': id});
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('User promoted to staff')));
      await _load();
    });
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final id = user['_id'] as String? ?? '';
    if (id.isEmpty) return;
    final confirmed = await _confirm('Delete user "${user['fullName']}"?');
    if (!confirmed) return;
    await _run(() async {
      await _api.delete('/admin/users/$id');
      await _load();
    });
  }

  Future<void> _setInstStatus(String id, String status) async {
    await _run(() async {
      await _api.patch('/admin/institutions/$id', {'status': status});
      await _load();
    });
  }

  Future<void> _deleteInstitution(String id, String name) async {
    final confirmed =
        await _confirm('Delete institution "$name"?\nLinked staff will be unlinked.');
    if (!confirmed) return;
    await _run(() async {
      await _api.delete('/admin/institutions/$id');
      await _load();
    });
  }

  Future<void> _demoteStaff(Map<String, dynamic> user) async {
    final id = user['_id'] as String? ?? '';
    if (id.isEmpty) return;
    final confirmed = await _confirm('Demote "${user['fullName']}" to owner?');
    if (!confirmed) return;
    await _run(() async {
      await _api.delete('/admin/staff/$id');
      await _load();
    });
  }

  Future<bool> _confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          backgroundColor: cs.surface,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Sign out',
              onPressed: () => context.read<FindItAuthProvider>().logout(),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Approvals'),
              Tab(text: 'Staff'),
              Tab(text: 'Users'),
              Tab(text: 'Institutions'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(error: _error!, onRetry: _load)
                : TabBarView(
                    children: [
                      _OverviewTab(stats: _stats),
                      _ApprovalsTab(
                        staff: _staff,
                        instStatus: _instStatus,
                        instName: _instName,
                        onApprove: (u) => _approveStaff(u, true),
                        onReject: (u) => _approveStaff(u, false),
                      ),
                      _StaffTab(
                        staff: _staff,
                        instName: _instName,
                        instStatus: _instStatus,
                        onDemote: _demoteStaff,
                        onToggleSuspend: _toggleSuspend,
                      ),
                      _UsersTab(
                        users: _users,
                        instName: _instName,
                        onPromote: _promoteToStaff,
                        onToggleSuspend: _toggleSuspend,
                        onDelete: _deleteUser,
                      ),
                      _InstitutionsTab(
                        institutions: _institutions,
                        onSetStatus: _setInstStatus,
                        onDelete: _deleteInstitution,
                      ),
                    ],
                  ),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

Widget _statusChip(BuildContext context, String status) {
  Color bg;
  Color fg;
  switch (status) {
    case 'active':
      bg = Colors.green.shade100;
      fg = Colors.green.shade800;
      break;
    case 'suspended':
      bg = Colors.red.shade100;
      fg = Colors.red.shade800;
      break;
    default:
      bg = Colors.orange.shade100;
      fg = Colors.orange.shade800;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(
      status,
      style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

// ─── Overview ─────────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = [
      ('Users', Icons.people_rounded, stats['users'] ?? 0),
      ('Staff', Icons.badge_rounded, stats['staff'] ?? 0),
      ('Institutions', Icons.business_rounded, stats['institutions'] ?? 0),
      ('Pending', Icons.hourglass_top_rounded, stats['pendingInstitutions'] ?? 0),
      ('Items', Icons.inventory_2_rounded, stats['items'] ?? 0),
      ('Claims', Icons.assignment_rounded, stats['claims'] ?? 0),
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: entries.length,
      itemBuilder: (ctx, i) {
        final (label, icon, value) = entries[i];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cs.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: cs.primary, size: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$value',
                      style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      label,
                      style: Theme.of(ctx)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Approvals ────────────────────────────────────────────────────────────────

class _ApprovalsTab extends StatelessWidget {
  const _ApprovalsTab({
    required this.staff,
    required this.instStatus,
    required this.instName,
    required this.onApprove,
    required this.onReject,
  });

  final List<Map<String, dynamic>> staff;
  final String Function(Map<String, dynamic>) instStatus;
  final String Function(Map<String, dynamic>) instName;
  final Future<void> Function(Map<String, dynamic>) onApprove;
  final Future<void> Function(Map<String, dynamic>) onReject;

  @override
  Widget build(BuildContext context) {
    final pending = staff
        .where((u) => u['institution'] is Map && instStatus(u) == 'pending')
        .toList();

    if (pending.isEmpty) {
      return const Center(child: Text('No pending approvals.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: pending.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final user = pending[i];
        return _ActionCard(
          title: user['fullName'] as String? ?? 'Unnamed',
          subtitle: user['email'] as String? ?? '',
          tag: instName(user),
          chip: _statusChip(ctx, instStatus(user)),
          actions: [
            FilledButton(
              onPressed: () => onApprove(user),
              child: const Text('Approve'),
            ),
            OutlinedButton(
              onPressed: () => onReject(user),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }
}

// ─── Staff ────────────────────────────────────────────────────────────────────

class _StaffTab extends StatelessWidget {
  const _StaffTab({
    required this.staff,
    required this.instName,
    required this.instStatus,
    required this.onDemote,
    required this.onToggleSuspend,
  });

  final List<Map<String, dynamic>> staff;
  final String Function(Map<String, dynamic>) instName;
  final String Function(Map<String, dynamic>) instStatus;
  final Future<void> Function(Map<String, dynamic>) onDemote;
  final Future<void> Function(Map<String, dynamic>) onToggleSuspend;

  @override
  Widget build(BuildContext context) {
    if (staff.isEmpty) return const Center(child: Text('No staff members.'));

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: staff.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final user = staff[i];
        final suspended = user['suspended'] == true;
        final status = instStatus(user);
        return _ActionCard(
          title: user['fullName'] as String? ?? 'Unnamed',
          subtitle: user['email'] as String? ?? '',
          tag: instName(user),
          chip: status.isNotEmpty ? _statusChip(ctx, status) : null,
          badge: suspended ? _statusChip(ctx, 'suspended') : null,
          actions: [
            OutlinedButton(
              onPressed: () => onToggleSuspend(user),
              child: Text(suspended ? 'Unsuspend' : 'Suspend'),
            ),
            TextButton(
              onPressed: () => onDemote(user),
              child: const Text('Demote'),
            ),
          ],
        );
      },
    );
  }
}

// ─── Users ────────────────────────────────────────────────────────────────────

class _UsersTab extends StatelessWidget {
  const _UsersTab({
    required this.users,
    required this.instName,
    required this.onPromote,
    required this.onToggleSuspend,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> users;
  final String Function(Map<String, dynamic>) instName;
  final Future<void> Function(Map<String, dynamic>) onPromote;
  final Future<void> Function(Map<String, dynamic>) onToggleSuspend;
  final Future<void> Function(Map<String, dynamic>) onDelete;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const Center(child: Text('No users.'));

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final user = users[i];
        final role = (user['role'] as String? ?? 'owner').toLowerCase();
        final suspended = user['suspended'] == true;
        return _ActionCard(
          title: user['fullName'] as String? ?? 'Unnamed',
          subtitle: user['email'] as String? ?? '',
          tag: '${role.toUpperCase()} · ${instName(user)}',
          badge: suspended ? _statusChip(ctx, 'suspended') : null,
          actions: [
            if (role != 'staff' && role != 'admin')
              OutlinedButton(
                onPressed: () => onPromote(user),
                child: const Text('Make Staff'),
              ),
            OutlinedButton(
              onPressed: () => onToggleSuspend(user),
              child: Text(suspended ? 'Unsuspend' : 'Suspend'),
            ),
            TextButton(
              onPressed: () => onDelete(user),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

// ─── Institutions ─────────────────────────────────────────────────────────────

class _InstitutionsTab extends StatelessWidget {
  const _InstitutionsTab({
    required this.institutions,
    required this.onSetStatus,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> institutions;
  final Future<void> Function(String id, String status) onSetStatus;
  final Future<void> Function(String id, String name) onDelete;

  @override
  Widget build(BuildContext context) {
    if (institutions.isEmpty) {
      return const Center(child: Text('No institutions.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: institutions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final inst = institutions[i];
        final id = inst['_id'] as String? ?? '';
        final name = inst['name'] as String? ?? 'Unnamed';
        final type = (inst['type'] as String? ?? '').toUpperCase();
        final status = (inst['status'] as String? ?? 'pending').toLowerCase();
        return _ActionCard(
          title: name,
          subtitle: type,
          chip: _statusChip(ctx, status),
          actions: [
            if (status != 'active')
              FilledButton(
                onPressed: id.isEmpty ? null : () => onSetStatus(id, 'active'),
                child: const Text('Approve'),
              ),
            if (status != 'pending')
              OutlinedButton(
                onPressed: id.isEmpty ? null : () => onSetStatus(id, 'pending'),
                child: const Text('Set Pending'),
              ),
            if (status != 'suspended')
              OutlinedButton(
                onPressed: id.isEmpty ? null : () => onSetStatus(id, 'suspended'),
                child: const Text('Suspend'),
              ),
            TextButton(
              onPressed: id.isEmpty ? null : () => onDelete(id, name),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

// ─── Reusable card ────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    this.tag,
    this.chip,
    this.badge,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final String? tag;
  final Widget? chip;
  final Widget? badge;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (badge != null) ...[const SizedBox(width: 8), badge!],
                if (chip != null) ...[const SizedBox(width: 8), chip!],
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            if (tag != null && tag!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                tag!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 0,
              children: actions.map(_compactify).toList(),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _compactify(Widget btn) {
    // Shrink minimum button size so they wrap cleanly on narrow screens
    if (btn is FilledButton) {
      return FilledButton(
        onPressed: btn.onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: btn.child!,
      );
    }
    if (btn is OutlinedButton) {
      return OutlinedButton(
        onPressed: btn.onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: btn.child!,
      );
    }
    if (btn is TextButton) {
      return TextButton(
        onPressed: btn.onPressed,
        style: (btn.style ?? const ButtonStyle()).copyWith(
          minimumSize: WidgetStateProperty.all(const Size(0, 32)),
          padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 8)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: btn.child!,
      );
    }
    return btn;
  }
}
