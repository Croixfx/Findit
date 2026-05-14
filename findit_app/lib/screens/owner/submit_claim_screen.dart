import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/upload_service.dart';

class SubmitClaimScreen extends StatefulWidget {
  final String itemId;
  final String itemTitle;

  const SubmitClaimScreen({
    super.key,
    required this.itemId,
    required this.itemTitle,
  });

  @override
  State<SubmitClaimScreen> createState() => _SubmitClaimScreenState();
}

class _SubmitClaimScreenState extends State<SubmitClaimScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final _picker = ImagePicker();
  final _descCtrl = TextEditingController();

  String? _proofImagePath;
  String? _proofImageUrl;
  bool _uploading = false;
  bool _submitting = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<ImageSource?> _askSource() => showModalBottomSheet<ImageSource>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ]),
        ),
      );

  Future<void> _pickProofImage() async {
    final source = await _askSource();
    if (source == null) return;
    final file = await _picker.pickImage(source: source, imageQuality: 75);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final url = await UploadService.uploadClaimProof(file.path);
      if (mounted) {
        setState(() {
          _proofImagePath = file.path;
          _proofImageUrl = url;
        });
      }
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await _api.post('/claims', {
        'itemId': widget.itemId,
        'ownershipDescription': _descCtrl.text.trim(),
        if (_proofImageUrl != null) 'proofImageUrl': _proofImageUrl,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: const Text('Submit Claim', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Item banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_rounded, color: cs.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Claiming item:',
                            style: TextStyle(fontSize: 12)),
                        Text(widget.itemTitle,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: cs.primary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Proof description
            Text('Proof of Ownership *',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'Describe how you can prove this item is yours — unique markings, saved data, serial numbers, etc.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              minLines: 5,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: 'e.g. My phone has a cracked screen on the bottom-left corner and my name is saved under "Me" in contacts.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFDADADA)),
                ),
                filled: true,
              ),
              validator: (v) {
                if (v == null || v.trim().length < 20) {
                  return 'Provide at least 20 characters describing your proof';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Proof image
            Text('Supporting Image (optional)',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'Attach a photo that helps verify ownership (receipt, old photo with the item, etc.)',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (_proofImagePath != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_proofImagePath!),
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _proofImagePath = null;
                        _proofImageUrl = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
            else if (_uploading)
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: CircularProgressIndicator()),
              )
            else
              OutlinedButton.icon(
                onPressed: _pickProofImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add Supporting Photo'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            const SizedBox(height: 32),

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.gavel_rounded, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'By submitting this claim, you confirm the item belongs to you. False claims may result in account suspension.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 22, width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Text('Submit Claim',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
