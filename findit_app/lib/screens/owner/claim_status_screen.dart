import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/claim_model.dart';
import '../../services/api_service.dart';
import '../shared/claim_chat_screen.dart';

class ClaimStatusScreen extends StatefulWidget {
  final String claimId;

  const ClaimStatusScreen({super.key, required this.claimId});

  @override
  State<ClaimStatusScreen> createState() => _ClaimStatusScreenState();
}

class _ClaimStatusScreenState extends State<ClaimStatusScreen> {
  final _api = ApiService();
  bool _loading = true;
  bool _confirming = false;
  bool _deleting = false;
  String? _error;
  ClaimModel? _claim;

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
      final data = await _api.get('/claims/${widget.claimId}');
      _claim = ClaimModel.fromJson(Map<String, dynamic>.from(data as Map));
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteClaim() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Claim'),
        content: Text(
          _claim!.status == 'submitted' || _claim!.status == 'under_review'
              ? 'This will withdraw your claim and the item will be marked available again. Continue?'
              : 'Remove this claim from your history?',
        ),
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
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await _api.delete('/claims/${widget.claimId}');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
        setState(() => _deleting = false);
      }
    }
  }

  Future<void> _confirmReceipt() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Receipt'),
        content: const Text(
          'By confirming, you acknowledge that you have physically received your item. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, I received it'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _confirming = true);
    try {
      await _api.patch('/claims/${widget.claimId}/confirm', {});
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: const Text('Claim Status',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_claim != null && _claim!.isDeletableByOwner)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: cs.error),
              tooltip: 'Remove claim',
              onPressed: _deleting ? null : _deleteClaim,
            ),
          IconButton(
              icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading || _deleting
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _claim == null
                  ? const Center(child: Text('Claim not found'))
                  : _buildContent(context, _claim!, cs),
    );
  }

  Widget _buildContent(
      BuildContext context, ClaimModel claim, ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Item card ────────────────────────────────────────────────────
          if (claim.itemTitle != null)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: claim.itemPhotos.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: claim.itemPhotos.first,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _PlaceholderBox(cs),
                            )
                          : _PlaceholderBox(cs),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(claim.itemTitle!,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          if (claim.itemInstitutionName != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.business_rounded,
                                    size: 13,
                                    color: cs.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(claim.itemInstitutionName!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: cs.onSurfaceVariant),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // ── Status timeline ───────────────────────────────────────────────
          Text('Claim Progress',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          _StatusTimeline(claim: claim, cs: cs),

          const SizedBox(height: 20),

          // ── Proof ─────────────────────────────────────────────────────────
          if (claim.proofDescription.isNotEmpty) ...[
            Text('Your Proof Description',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(claim.proofDescription,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.5)),
            ),
          ],

          if (claim.proofImageUrl != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: claim.proofImageUrl!,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
          ],

          // ── Status-specific banners ───────────────────────────────────────

          // Rejected
          if (claim.status == 'rejected') ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.cancel_rounded, color: cs.error, size: 20),
                    const SizedBox(width: 8),
                    Text('Claim Rejected',
                        style: TextStyle(
                            color: cs.error, fontWeight: FontWeight.bold)),
                  ]),
                  if (claim.rejectionReason != null) ...[
                    const SizedBox(height: 8),
                    Text(claim.rejectionReason!,
                        style: TextStyle(color: cs.onErrorContainer)),
                  ],
                ],
              ),
            ),
          ],

          // Approved — arrange pickup
          if (claim.status == 'approved') ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.teal, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Claim approved! Chat with the institution to arrange pickup of your item.',
                    style:
                        TextStyle(color: Colors.teal.shade800, fontSize: 13),
                  ),
                ),
              ]),
            ),
          ],

          // Returned — awaiting owner confirmation
          if (claim.status == 'returned' && !claim.ownerConfirmed) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.amber.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.inventory_rounded,
                        color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text('Item Handed Over',
                        style: TextStyle(
                            color: Colors.amber.shade800,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    'The institution marked your item as returned. Please confirm below once you physically receive it.',
                    style: TextStyle(
                        color: Colors.amber.shade800, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _confirming ? null : _confirmReceipt,
                      icon: _confirming
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.verified_rounded, size: 18),
                      label: Text(_confirming
                          ? 'Confirming…'
                          : 'Confirm Receipt'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Returned + confirmed
          if (claim.status == 'returned' && claim.ownerConfirmed) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.verified_user_rounded,
                        color: Colors.green, size: 22),
                    const SizedBox(width: 10),
                    Text('Receipt Confirmed',
                        style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    'You confirmed receiving your item. Thank you for using FindIt!',
                    style: TextStyle(
                        color: Colors.green.shade700, fontSize: 13),
                  ),
                  if (claim.confirmedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Confirmed on ${_fmt(claim.confirmedAt!)}',
                      style: TextStyle(
                          color: Colors.green.shade600, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ── Chat / history button ─────────────────────────────────────────
          if (claim.canChat) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClaimChatScreen(
                    claimId: claim.id,
                    itemTitle: claim.itemTitle ?? 'Item',
                    claimStatus: claim.status,
                    ownerConfirmed: claim.ownerConfirmed,
                  ),
                ),
              ),
              icon: Icon(claim.canSendMessage
                  ? Icons.chat_bubble_outline_rounded
                  : Icons.history_rounded),
              label: Text(claim.canSendMessage
                  ? 'Chat with Institution'
                  : 'View Chat History'),
              style: FilledButton.styleFrom(
                backgroundColor: claim.canSendMessage ? null : Colors.grey.shade600,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline
// ─────────────────────────────────────────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.claim, required this.cs});
  final ClaimModel claim;
  final ColorScheme cs;

  // 5 steps — last one is owner confirmation
  static const _steps = [
    ('submitted',   'Submitted',         'Your claim has been received'),
    ('under_review','Under Review',      'The institution is reviewing your claim'),
    ('approved',    'Approved',          'Your ownership was verified'),
    ('returned',    'Item Handed Over',  'The institution marked item as returned'),
    ('confirmed',   'Receipt Confirmed', 'You confirmed receiving your item'),
  ];

  @override
  Widget build(BuildContext context) {
    final isRejected = claim.status == 'rejected';
    final currentIndex = _stepIndex(claim.status, claim.ownerConfirmed);

    return Column(
      children: [
        ..._steps.asMap().entries.map((e) {
          final idx = e.key;
          final (_, label, description) = e.value;

          // Only show confirmed step when status is 'returned' or 'confirmed'
          final isReturnedOrBeyond =
              claim.status == 'returned' || claim.ownerConfirmed;
          if (idx == 4 && !isReturnedOrBeyond) return const SizedBox.shrink();

          final isPast = idx < currentIndex;
          final isCurrent = idx == currentIndex && !isRejected;
          final isFuture = idx > currentIndex;

          Color nodeColor;
          IconData nodeIcon;
          if (isPast) {
            nodeColor = Colors.green;
            nodeIcon = Icons.check_rounded;
          } else if (isCurrent) {
            nodeColor = cs.primary;
            nodeIcon = Icons.radio_button_checked_rounded;
          } else {
            nodeColor = cs.outlineVariant;
            nodeIcon = Icons.radio_button_unchecked_rounded;
          }

          return _TimelineStep(
            nodeColor: nodeColor,
            nodeIcon: nodeIcon,
            label: label,
            description: description,
            isLast: idx == _steps.length - 1 ||
                (idx == 3 && !isReturnedOrBeyond),
            isCurrent: isCurrent,
            isFuture: isFuture,
            cs: cs,
          );
        }),
        if (isRejected)
          _TimelineStep(
            nodeColor: cs.error,
            nodeIcon: Icons.cancel_rounded,
            label: 'Rejected',
            description: 'Your claim was not approved',
            isLast: true,
            isCurrent: true,
            isFuture: false,
            cs: cs,
          ),
      ],
    );
  }

  int _stepIndex(String status, bool ownerConfirmed) {
    if (ownerConfirmed) return 4;
    switch (status) {
      case 'submitted':   return 0;
      case 'under_review':return 1;
      case 'approved':    return 2;
      case 'returned':    return 3;
      default:            return 0;
    }
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.nodeColor,
    required this.nodeIcon,
    required this.label,
    required this.description,
    required this.isLast,
    required this.isCurrent,
    required this.isFuture,
    required this.cs,
  });

  final Color nodeColor;
  final IconData nodeIcon;
  final String label;
  final String description;
  final bool isLast;
  final bool isCurrent;
  final bool isFuture;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isFuture
                        ? cs.surfaceContainerHighest
                        : nodeColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: nodeColor, width: isCurrent ? 2.5 : 1.5),
                  ),
                  child: Icon(nodeIcon, size: 16, color: nodeColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isFuture ? cs.outlineVariant : Colors.green,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isFuture
                            ? cs.onSurfaceVariant
                            : cs.onSurface,
                      )),
                  const SizedBox(height: 2),
                  Text(description,
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderBox extends StatelessWidget {
  const _PlaceholderBox(this.cs);
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.inventory_2_rounded,
          color: cs.onSurfaceVariant, size: 28),
    );
  }
}
