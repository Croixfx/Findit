import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/item_model.dart';
import '../../models/claim_model.dart';
import '../../utils/constants.dart';
import '../../widgets/offline_banner.dart';
import 'log_item_screen.dart';
import 'claim_review_screen.dart';
import '../shared/claim_chat_screen.dart';

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  int _tab = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const _ItemsTab(),
      const _ClaimsTab(),
      const _ProfileTab(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Items',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Claims',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Items Tab
// ──────────────────────────────────────────────────────────────────────────────

class _ItemsTab extends StatefulWidget {
  const _ItemsTab();

  @override
  State<_ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<_ItemsTab> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<ItemModel> _items = [];
  String _filter = 'all';
  bool _fromCache = false;
  String? _cacheMsg;

  static const _filters = [
    ('all', 'All'),
    ('available', 'Available'),
    ('claimed', 'Claimed'),
    ('ready_for_pickup', 'Ready'),
    ('returned', 'Returned'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _fromCache = false; _cacheMsg = null; });
    try {
      final data = await _api.get('/items/mine');
      final list = (data as List)
          .map((e) => ItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (mounted) setState(() => _items = list);
    } on NetworkException catch (netErr) {
      if (netErr.hasCache) {
        final list = (netErr.cachedData as List)
            .map((d) => ItemModel.fromJson(Map<String, dynamic>.from(d as Map)))
            .toList();
        if (mounted) setState(() { _items = list; _fromCache = true; _cacheMsg = netErr.message; });
      } else {
        if (mounted) setState(() => _error = netErr.message);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ItemModel> get _filtered {
    if (_filter == 'all') return _items;
    return _items.where((i) => i.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: const Text('My Items', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: _filters.map((f) {
                final (value, label) = f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: _filter == value,
                    onSelected: (_) => setState(() => _filter = value),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_fromCache && _cacheMsg != null)
                  OfflineBanner(message: _cacheMsg!, onRetry: _load),
                Expanded(
                  child: _error != null
                      ? _ErrorRetry(message: _error!, onRetry: _load)
                      : _filtered.isEmpty
                          ? _EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: 'No items yet',
                              subtitle: _filter == 'all'
                                  ? 'Tap + to log your first found item'
                                  : 'No items with status "$_filter"',
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _filtered.length,
                                itemBuilder: (_, i) => _ItemCard(
                                  item: _filtered[i],
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ClaimReviewScreen(
                                          itemId: _filtered[i].id,
                                          viewMode: true,
                                        ),
                                      ),
                                    );
                                    _load();
                                  },
                                ),
                              ),
                            ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LogItemScreen()),
          );
          _load();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log Item'),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Claims Tab
// ──────────────────────────────────────────────────────────────────────────────

class _ClaimsTab extends StatefulWidget {
  const _ClaimsTab();

  @override
  State<_ClaimsTab> createState() => _ClaimsTabState();
}

class _ClaimsTabState extends State<_ClaimsTab> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<ClaimModel> _claims = [];
  String _filter = 'all';
  bool _fromCache = false;
  String? _cacheMsg;

  static const _filters = [
    ('all', 'All'),
    ('submitted', 'Submitted'),
    ('under_review', 'Reviewing'),
    ('approved', 'Approved'),
    ('rejected', 'Rejected'),
    ('returned', 'Returned'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _fromCache = false; _cacheMsg = null; });
    try {
      final data = await _api.get('/claims/institution');
      final list = (data as List)
          .map((e) => ClaimModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (mounted) setState(() => _claims = list);
    } on NetworkException catch (netErr) {
      if (netErr.hasCache) {
        final list = (netErr.cachedData as List)
            .map((d) => ClaimModel.fromJson(Map<String, dynamic>.from(d as Map)))
            .toList();
        if (mounted) setState(() { _claims = list; _fromCache = true; _cacheMsg = netErr.message; });
      } else {
        if (mounted) setState(() => _error = netErr.message);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteClaim(ClaimModel claim) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Claim'),
        content: const Text('Remove this closed claim from the list?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.delete('/claims/${claim.id}');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  List<ClaimModel> get _filtered {
    if (_filter == 'all') return _claims;
    return _claims.where((c) => c.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: Row(
          children: [
            const Text('Claims', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (_claims.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_claims.where((c) => c.status == 'submitted').length}',
                  style: TextStyle(color: cs.onPrimary, fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: _filters.map((f) {
                final (value, label) = f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: _filter == value,
                    onSelected: (_) => setState(() => _filter = value),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_fromCache && _cacheMsg != null)
                  OfflineBanner(message: _cacheMsg!, onRetry: _load),
                Expanded(
                  child: _error != null
                      ? _ErrorRetry(message: _error!, onRetry: _load)
                      : _filtered.isEmpty
                          ? _EmptyState(
                              icon: Icons.assignment_outlined,
                              title: 'No claims',
                              subtitle: _filter == 'all'
                                  ? 'Claims submitted by users will appear here'
                                  : 'No claims with status "$_filter"',
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _filtered.length,
                                itemBuilder: (_, i) {
                                  final claim = _filtered[i];
                                  return _ClaimCard(
                                    claim: claim,
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ClaimReviewScreen(claimId: claim.id),
                                        ),
                                      );
                                      _load();
                                    },
                                    onChat: claim.canChat
                                        ? () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ClaimChatScreen(
                                                  claimId: claim.id,
                                                  itemTitle: claim.itemTitle ?? 'Item',
                                                  claimStatus: claim.status,
                                                  ownerConfirmed: claim.ownerConfirmed,
                                                ),
                                              ),
                                            )
                                        : null,
                                    onDelete: claim.isDeletableByStaff
                                        ? () => _deleteClaim(claim)
                                        : null,
                                  );
                                },
                              ),
                            ),
                        ),
                      ],
                    ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Profile Tab
// ──────────────────────────────────────────────────────────────────────────────

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();
  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _api = ApiService();
  bool _updating = false;

  static const _types = [
    ('university', 'University'),
    ('hospital', 'Hospital'),
    ('hotel', 'Hotel'),
    ('office', 'Office'),
    ('other', 'Other'),
  ];

  Future<void> _editInstitution() async {
    final auth = context.read<FindItAuthProvider>();
    final inst = auth.institution;
    if (inst == null) return;

    final nameCtrl = TextEditingController(text: inst.name);
    final emailCtrl = TextEditingController(text: inst.contactEmail ?? '');
    final addressCtrl = TextEditingController(text: inst.address ?? '');
    final phoneCtrl = TextEditingController(text: inst.phone ?? '');
    String? selectedType = inst.type;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Edit Institution'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Type *'),
                items: _types
                    .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                    .toList(),
                onChanged: (v) => setSt(() => selectedType = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Contact email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || selectedType == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Name and type are required')));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    setState(() => _updating = true);
    try {
      await _api.patch('/institutions/my', {
        'name': nameCtrl.text.trim(),
        'type': selectedType!,
        if (addressCtrl.text.trim().isNotEmpty) 'address': addressCtrl.text.trim(),
        if (emailCtrl.text.trim().isNotEmpty) 'contactEmail': emailCtrl.text.trim(),
        if (phoneCtrl.text.trim().isNotEmpty) 'phone': phoneCtrl.text.trim(),
      });
      await context.read<FindItAuthProvider>().refreshInstitutionStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Institution updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _deleteInstitution() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Institution'),
        content: const Text(
            'This will permanently delete your institution and reset your account. '
            'All items and claims will be unlinked. Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _updating = true);
    try {
      await _api.delete('/institutions/my');
      await context.read<FindItAuthProvider>().refreshUser();
      // auth.institution is now null → _AuthGate redirects to institution setup
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
        setState(() => _updating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<FindItAuthProvider>();
    final user = auth.currentUser;
    final inst = auth.institution;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _updating
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Avatar + name
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: cs.primaryContainer,
                        child: Icon(Icons.person_rounded, size: 44, color: cs.primary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.fullName ?? 'Staff',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      _Chip('STAFF', cs.primaryContainer, cs.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Institution card
                if (inst != null) ...[
                  _SectionHeader('Institution'),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.business_rounded, color: cs.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  inst.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              _Chip(
                                inst.status.toUpperCase(),
                                inst.status == 'active'
                                    ? Colors.green.shade100
                                    : Colors.orange.shade100,
                                inst.status == 'active'
                                    ? Colors.green.shade800
                                    : Colors.orange.shade800,
                              ),
                            ],
                          ),
                          if (inst.type.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(children: [
                              Icon(Icons.category_outlined, size: 14, color: cs.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text(inst.type,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: cs.onSurfaceVariant)),
                            ]),
                          ],
                          if (inst.contactEmail != null && inst.contactEmail!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(children: [
                              Icon(Icons.email_outlined, size: 14, color: cs.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text(inst.contactEmail!,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: cs.onSurfaceVariant)),
                            ]),
                          ],
                          if (inst.address != null && inst.address!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(children: [
                              Icon(Icons.location_on_outlined, size: 14, color: cs.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Expanded(child: Text(inst.address!,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: cs.onSurfaceVariant))),
                            ]),
                          ],
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _editInstitution,
                                icon: const Icon(Icons.edit_rounded, size: 16),
                                label: const Text('Edit'),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _deleteInstitution,
                                icon: const Icon(Icons.delete_rounded, size: 16),
                                label: const Text('Delete'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: cs.error,
                                  side: BorderSide(color: cs.error),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Logout
                OutlinedButton.icon(
                  onPressed: () => context.read<FindItAuthProvider>().logout(),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: cs.error,
                    side: BorderSide(color: cs.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Reusable widgets
// ──────────────────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onTap});
  final ItemModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: item.statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: item.hasPhoto
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(item.firstPhoto, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Icon(item.categoryIcon, color: item.statusColor)),
                      )
                    : Icon(item.categoryIcon, color: item.statusColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                      item.category.isNotEmpty ? item.category : 'Uncategorized',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Found ${fmtRelative(item.createdAt)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Chip(
                item.statusLabel,
                item.statusColor.withOpacity(0.12),
                item.statusColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.claim, required this.onTap, this.onChat, this.onDelete});
  final ClaimModel claim;
  final VoidCallback onTap;
  final VoidCallback? onChat;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_rounded, color: cs.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          claim.claimantName ?? 'Unknown user',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          claim.claimantEmail ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  _Chip(
                    claim.statusLabel,
                    claim.statusColor.withOpacity(0.12),
                    claim.statusColor,
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onDelete,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            size: 18, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_rounded, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        claim.itemTitle ?? 'Item',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    fmtRelative(claim.createdAt),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                  ),
                  if (onChat != null)
                    TextButton.icon(
                      onPressed: onChat,
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: const Text('Chat'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: cs.onSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
