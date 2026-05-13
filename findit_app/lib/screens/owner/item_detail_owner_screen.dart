import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/item_model.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import 'submit_claim_screen.dart';

class ItemDetailOwnerScreen extends StatefulWidget {
  final String itemId;

  const ItemDetailOwnerScreen({super.key, required this.itemId});

  @override
  State<ItemDetailOwnerScreen> createState() => _ItemDetailOwnerScreenState();
}

class _ItemDetailOwnerScreenState extends State<ItemDetailOwnerScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  ItemModel? _item;
  int _photoIndex = 0;

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
      final data = await _api.get('/items/${widget.itemId}');
      _item = ItemModel.fromJson(Map<String, dynamic>.from(data as Map));
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
              : _item == null
                  ? const Center(child: Text('Item not found'))
                  : _buildDetail(context, _item!, cs),
    );
  }

  Widget _buildDetail(BuildContext context, ItemModel item, ColorScheme cs) {
    return CustomScrollView(
      slivers: [
        // Photo header
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          flexibleSpace: FlexibleSpaceBar(
            background: item.hasPhoto
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      PageView.builder(
                        itemCount: item.photos.length,
                        onPageChanged: (i) =>
                            setState(() => _photoIndex = i),
                        itemBuilder: (_, i) => CachedNetworkImage(
                          imageUrl: item.photos[i],
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator()),
                          errorWidget: (_, __, ___) =>
                              Icon(item.categoryIcon,
                                  size: 80, color: cs.onSurfaceVariant),
                        ),
                      ),
                      if (item.photos.length > 1)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: item.photos.asMap().entries.map((e) {
                              return Container(
                                width: _photoIndex == e.key ? 18 : 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: _photoIndex == e.key
                                      ? cs.primary
                                      : Colors.white54,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  )
                : Container(
                    color: item.statusColor.withOpacity(0.08),
                    child: Icon(item.categoryIcon,
                        size: 80, color: item.statusColor),
                  ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(item.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: item.statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(item.statusLabel,
                          style: TextStyle(
                              color: item.statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Institution
                Row(
                  children: [
                    Icon(Icons.business_rounded,
                        size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(item.institutionName,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text('Found ${fmtRelative(item.createdAt)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),

                // Details grid
                _SectionTitle('Item Details'),
                const SizedBox(height: 12),
                _DetailsGrid(item: item, cs: cs),

                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionTitle('Description'),
                  const SizedBox(height: 8),
                  Text(item.description,
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                                color: cs.onSurface,
                              )),
                ],

                const SizedBox(height: 32),

                // Claim button
                if (item.status == 'available')
                  FilledButton.icon(
                    onPressed: () async {
                      final submitted = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SubmitClaimScreen(
                            itemId: item.id,
                            itemTitle: item.title,
                          ),
                        ),
                      );
                      if (submitted == true && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Claim submitted! Track it in My Claims.')),
                        );
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.assignment_rounded),
                    label: const Text('Claim This Item'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: cs.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This item is no longer available for claiming.',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold));
  }
}

class _DetailsGrid extends StatelessWidget {
  const _DetailsGrid({required this.item, required this.cs});
  final ItemModel item;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final details = <(IconData, String, String)>[];
    if (item.category.isNotEmpty) {
      details.add((Icons.category_rounded, 'Category', item.category));
    }
    if (item.color.isNotEmpty) {
      details.add((Icons.palette_rounded, 'Color', item.color));
    }
    if (item.brand.isNotEmpty) {
      details.add((Icons.sell_rounded, 'Brand', item.brand));
    }
    if (item.condition.isNotEmpty) {
      details.add((Icons.star_half_rounded, 'Condition', item.condition));
    }
    if (item.locationFound.isNotEmpty) {
      details.add(
          (Icons.location_on_rounded, 'Found at', item.locationFound));
    }
    if (item.dateFound != null) {
      details.add((Icons.calendar_today_rounded, 'Date found',
          fmtDate(item.dateFound!)));
    }

    if (details.isEmpty) {
      return Text('No additional details',
          style: TextStyle(color: cs.onSurfaceVariant));
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: details.map((d) {
        final (icon, label, value) = d;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 10)),
                  Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
