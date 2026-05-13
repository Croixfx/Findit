import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/claim_model.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: const Text('Claim Status', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
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
          // Item info
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
                              errorWidget: (_, __, ___) => _PlaceholderBox(cs),
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
                                    size: 13, color: cs.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(claim.itemInstitutionName!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: cs.onSurfaceVariant)),
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

          // Status timeline
          Text('Claim Progress',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          _StatusTimeline(claim: claim, cs: cs),

          const SizedBox(height: 20),

          // Proof
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

          // Rejection reason
          if (claim.status == 'rejected' &&
              claim.rejectionReason != null) ...[
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
                  Row(
                    children: [
                      Icon(Icons.cancel_rounded, color: cs.error, size: 20),
                      const SizedBox(width: 8),
                      Text('Claim Rejected',
                          style: TextStyle(
                              color: cs.error, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(claim.rejectionReason!,
                      style: TextStyle(color: cs.onErrorContainer)),
                ],
              ),
            ),
          ],

          // Approved success
          if (claim.status == 'approved') ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.teal, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your claim is approved! You can now contact the institution via chat to arrange pickup.',
                      style: TextStyle(
                          color: Colors.teal.shade800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Returned success
          if (claim.status == 'returned') ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.done_all_rounded,
                      color: Colors.green, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Item successfully returned to you. Thank you for using FindIt!',
                      style: TextStyle(color: Colors.green.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Chat button
          if (claim.canChat) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClaimChatScreen(
                    claimId: claim.id,
                    itemTitle: claim.itemTitle ?? 'Item',
                  ),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Chat with Institution'),
              style: FilledButton.styleFrom(
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
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.claim, required this.cs});
  final ClaimModel claim;
  final ColorScheme cs;

  static const _steps = [
    ('submitted', 'Submitted', 'Your claim has been received'),
    ('under_review', 'Under Review', 'The institution is reviewing your claim'),
    ('approved', 'Approved', 'Your claim was verified'),
    ('returned', 'Item Returned', 'You have received your item'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _stepIndex(claim.status);
    final isRejected = claim.status == 'rejected';

    return Column(
      children: [
        ..._steps.asMap().entries.map((e) {
          final idx = e.key;
          final (_, label, description) = e.value;
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
            isLast: idx == _steps.length - 1,
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

  int _stepIndex(String status) {
    switch (status) {
      case 'submitted':
        return 0;
      case 'under_review':
        return 1;
      case 'approved':
        return 2;
      case 'returned':
        return 3;
      default:
        return 0;
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
                        : nodeColor.withOpacity(0.12),
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
              padding: EdgeInsets.only(
                  bottom: isLast ? 0 : 20, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.w500,
                        color: isFuture ? cs.onSurfaceVariant : cs.onSurface,
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
