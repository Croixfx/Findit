import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/claim_model.dart';
import '../../models/item_model.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../shared/claim_chat_screen.dart';

/// Used for two purposes:
/// - Staff reviewing a claim: pass [claimId]
/// - Staff viewing an item (no claim): pass [itemId] + [viewMode]=true
class ClaimReviewScreen extends StatefulWidget {
  final String? claimId;
  final String? itemId;
  final bool viewMode;

  const ClaimReviewScreen({
    super.key,
    this.claimId,
    this.itemId,
    this.viewMode = false,
  });

  @override
  State<ClaimReviewScreen> createState() => _ClaimReviewScreenState();
}

class _ClaimReviewScreenState extends State<ClaimReviewScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  ClaimModel? _claim;
  ItemModel? _item;
  bool _updating = false;

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
      if (widget.claimId != null) {
        final data = await _api.get('/claims/${widget.claimId}');
        _claim = ClaimModel.fromJson(Map<String, dynamic>.from(data as Map));
        // Also load the full item
        if (_claim!.itemId.isNotEmpty) {
          final iData = await _api.get('/items/${_claim!.itemId}');
          _item = ItemModel.fromJson(Map<String, dynamic>.from(iData as Map));
        }
      } else if (widget.itemId != null) {
        final data = await _api.get('/items/${widget.itemId}');
        _item = ItemModel.fromJson(Map<String, dynamic>.from(data as Map));
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateClaimStatus(String status, {String? reason}) async {
    setState(() => _updating = true);
    try {
      final body = <String, dynamic>{'status': status};
      if (reason != null && reason.isNotEmpty) body['rejectionReason'] = reason;
      await _api.patch('/claims/${_claim!.id}/status', body);
      _showSnack(status == 'approved'
          ? 'Claim approved! User can now chat with you.'
          : status == 'rejected'
              ? 'Claim rejected.'
              : status == 'returned'
                  ? 'Item marked as returned!'
                  : 'Status updated.');
      await _load();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _updateItemStatus(String status) async {
    setState(() => _updating = true);
    try {
      await _api.patch('/items/${_item!.id}', {'status': status});
      _showSnack('Item status updated.');
      await _load();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _promptReject() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Claim'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Provide a reason for rejection (optional):'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Reason...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reject')),
        ],
      ),
    );
    if (confirmed == true) {
      await _updateClaimStatus('rejected', reason: ctrl.text.trim());
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: Text(widget.viewMode ? 'Item Details' : 'Review Claim',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_claim != null && _claim!.canChat)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              tooltip: 'Chat',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClaimChatScreen(
                    claimId: _claim!.id,
                    itemTitle: _claim!.itemTitle ?? 'Item',
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_item != null) ...[
                        _ItemSection(item: _item!, cs: cs),
                        const SizedBox(height: 20),
                      ],
                      if (_claim != null) ...[
                        _ClaimSection(claim: _claim!, cs: cs),
                        const SizedBox(height: 20),
                      ],

                      // Action buttons for staff
                      if (_updating)
                        const Center(child: CircularProgressIndicator())
                      else if (_claim != null && !widget.viewMode)
                        _ClaimActions(
                          claim: _claim!,
                          onApprove: () =>
                              _updateClaimStatus('approved'),
                          onReject: _promptReject,
                          onMarkReturned: () =>
                              _updateClaimStatus('returned'),
                          onMarkUnderReview: () =>
                              _updateClaimStatus('under_review'),
                        )
                      else if (_item != null && widget.viewMode)
                        _ItemActions(
                          item: _item!,
                          onStatusChange: _updateItemStatus,
                        ),
                    ],
                  ),
                ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _ItemSection extends StatelessWidget {
  const _ItemSection({required this.item, required this.cs});
  final ItemModel item;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.hasPhoto)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: CachedNetworkImage(
                imageUrl: item.firstPhoto,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.image_not_supported_rounded, size: 64),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(item.statusLabel,
                          style: TextStyle(
                              color: item.statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DetailRow(Icons.business_rounded, 'Institution', item.institutionName),
                if (item.category.isNotEmpty)
                  _DetailRow(Icons.category_rounded, 'Category', item.category),
                if (item.color.isNotEmpty)
                  _DetailRow(Icons.palette_rounded, 'Color', item.color),
                if (item.brand.isNotEmpty)
                  _DetailRow(Icons.sell_rounded, 'Brand', item.brand),
                if (item.condition.isNotEmpty)
                  _DetailRow(Icons.star_half_rounded, 'Condition', item.condition),
                if (item.locationFound.isNotEmpty)
                  _DetailRow(Icons.location_on_rounded, 'Location', item.locationFound),
                if (item.storageReference != null && item.storageReference!.isNotEmpty)
                  _DetailRow(Icons.archive_rounded, 'Storage', item.storageReference!),
                if (item.dateFound != null)
                  _DetailRow(Icons.calendar_today_rounded, 'Date found',
                      fmtDate(item.dateFound!)),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Description',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(item.description),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimSection extends StatelessWidget {
  const _ClaimSection({required this.claim, required this.cs});
  final ClaimModel claim;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_rounded, color: cs.primary),
                const SizedBox(width: 8),
                Text('Claim Details',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: claim.statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(claim.statusLabel,
                      style: TextStyle(
                          color: claim.statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DetailRow(Icons.person_rounded, 'Claimant', claim.claimantName ?? 'Unknown'),
            if (claim.claimantEmail != null)
              _DetailRow(Icons.email_outlined, 'Email', claim.claimantEmail!),
            if (claim.claimantPhone != null)
              _DetailRow(Icons.phone_rounded, 'Phone', claim.claimantPhone!),
            _DetailRow(Icons.access_time_rounded, 'Submitted', fmtDateTime(claim.createdAt)),
            if (claim.reviewedAt != null)
              _DetailRow(Icons.rate_review_rounded, 'Reviewed', fmtDateTime(claim.reviewedAt!)),
            if (claim.proofDescription.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Text('Proof Description',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(claim.proofDescription),
            ],
            if (claim.rejectionReason != null && claim.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Text('Rejection Reason',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: cs.error)),
              const SizedBox(height: 4),
              Text(claim.rejectionReason!,
                  style: TextStyle(color: cs.error)),
            ],
            if (claim.proofImageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: claim.proofImageUrl!,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClaimActions extends StatelessWidget {
  const _ClaimActions({
    required this.claim,
    required this.onApprove,
    required this.onReject,
    required this.onMarkReturned,
    required this.onMarkUnderReview,
  });
  final ClaimModel claim;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onMarkReturned;
  final VoidCallback onMarkUnderReview;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = claim.status;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s == 'submitted' || s == 'under_review') ...[
          if (s == 'submitted')
            FilledButton.tonal(
              onPressed: onMarkUnderReview,
              style: _btnStyle(),
              child: const Text('Mark Under Review'),
            ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: onApprove,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.teal,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Approve Claim',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onReject,
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.error,
              side: BorderSide(color: cs.error),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Reject Claim'),
          ),
        ],
        if (s == 'approved') ...[
          FilledButton(
            onPressed: onMarkReturned,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Mark as Returned',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
        if (s == 'returned')
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.done_all_rounded, color: Colors.green),
                const SizedBox(width: 8),
                Text('Item returned to owner',
                    style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        if (s == 'rejected')
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.cancel_rounded, color: cs.error),
                const SizedBox(width: 8),
                Text('Claim was rejected',
                    style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }

  ButtonStyle _btnStyle() => FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
}

class _ItemActions extends StatelessWidget {
  const _ItemActions({required this.item, required this.onStatusChange});
  final ItemModel item;
  final void Function(String) onStatusChange;

  @override
  Widget build(BuildContext context) {
    final statuses = ['available', 'returned', 'discarded']
        .where((s) => s != item.status)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Change Status',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...statuses.map((s) {
          final color = s == 'available'
              ? Colors.blue
              : s == 'returned'
                  ? Colors.green
                  : Colors.grey;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              onPressed: () => onStatusChange(s),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Mark as ${s.replaceAll('_', ' ').toUpperCase()}'),
            ),
          );
        }),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('$label: ',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
          Expanded(
            child: Text(value,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
