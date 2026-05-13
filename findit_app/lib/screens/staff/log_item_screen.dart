import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/upload_service.dart';

class LogItemScreen extends StatefulWidget {
  const LogItemScreen({super.key});

  @override
  State<LogItemScreen> createState() => _LogItemScreenState();
}

class _LogItemScreenState extends State<LogItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final _picker = ImagePicker();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _storageCtrl = TextEditingController();

  String? _category;
  String? _condition;
  DateTime? _dateFound;
  final List<String> _photoUrls = [];
  final List<String> _localPaths = [];
  bool _uploading = false;
  bool _saving = false;

  static const _categories = [
    'Electronics', 'Clothing', 'Accessories', 'Documents',
    'Keys', 'Bags', 'Jewelry', 'Money', 'Other',
  ];

  static const _conditions = ['Good', 'Fair', 'Damaged'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _colorCtrl.dispose();
    _brandCtrl.dispose();
    _locationCtrl.dispose();
    _storageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final url = await UploadService.uploadItemPhoto(file.path);
      if (mounted) {
        setState(() {
          _localPaths.add(file.path);
          _photoUrls.add(url);
        });
      }
    } catch (e) {
      if (mounted) _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await _api.post('/items', {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _category ?? '',
        'color': _colorCtrl.text.trim(),
        'brand': _brandCtrl.text.trim(),
        'condition': _condition ?? '',
        'locationFound': _locationCtrl.text.trim(),
        'storageReference': _storageCtrl.text.trim(),
        if (_dateFound != null) 'dateFound': _dateFound!.toIso8601String(),
        'photos': _photoUrls,
      });
      if (!mounted) return;
      _showSnack('Item logged successfully!');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
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
        title: const Text('Log Found Item', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Photos ───────────────────────────────────────────────────
            _Label('Photos'),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._localPaths.asMap().entries.map((e) => _PhotoThumb(
                        path: e.value,
                        onRemove: () => setState(() {
                          _localPaths.removeAt(e.key);
                          _photoUrls.removeAt(e.key);
                        }),
                      )),
                  if (_uploading)
                    _Placeholder(cs: cs, child: const CircularProgressIndicator())
                  else if (_localPaths.length < 5)
                    GestureDetector(
                      onTap: _pickImage,
                      child: _Placeholder(
                        cs: cs,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: cs.primary, size: 28),
                            const SizedBox(height: 4),
                            Text('Add Photo',
                                style: TextStyle(
                                    color: cs.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                        bordered: true,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Item details ──────────────────────────────────────────────
            _Label('Item Details'),
            const SizedBox(height: 10),
            _Field(
              controller: _titleCtrl,
              label: 'Item title *',
              icon: Icons.label_rounded,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: _deco('Category', Icons.category_rounded),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: _deco('Description', Icons.notes_rounded),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _Field(controller: _colorCtrl, label: 'Color', icon: Icons.palette_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _Field(controller: _brandCtrl, label: 'Brand', icon: Icons.sell_rounded)),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _condition,
              decoration: _deco('Condition', Icons.star_half_rounded),
              items: _conditions
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _condition = v),
            ),
            const SizedBox(height: 24),

            // ── Location & Storage ────────────────────────────────────────
            _Label('Location & Storage'),
            const SizedBox(height: 10),
            _Field(
              controller: _locationCtrl,
              label: 'Location found',
              icon: Icons.location_on_rounded,
            ),
            const SizedBox(height: 14),
            _Field(
              controller: _storageCtrl,
              label: 'Storage reference (e.g. Box A-3)',
              icon: Icons.archive_rounded,
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateFound ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _dateFound = picked);
              },
              child: InputDecorator(
                decoration: _deco('Date found', Icons.calendar_today_rounded),
                child: Text(
                  _dateFound == null
                      ? 'Select date'
                      : '${_dateFound!.day}/${_dateFound!.month}/${_dateFound!.year}',
                  style: TextStyle(
                    color: _dateFound == null
                        ? Theme.of(context).hintColor
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22, width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Log Item',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.bold));
}

class _Field extends StatelessWidget {
  const _Field(
      {required this.controller,
      required this.label,
      required this.icon,
      this.validator});
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
      controller: controller, validator: validator, decoration: _deco(label, icon));
}

InputDecoration _deco(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDADADA)),
      ),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.cs, required this.child, this.bordered = false});
  final ColorScheme cs;
  final Widget child;
  final bool bordered;

  @override
  Widget build(BuildContext context) => Container(
        width: 100,
        height: 100,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: bordered
              ? Border.all(color: cs.primary.withOpacity(0.4))
              : null,
        ),
        child: Center(child: child),
      );
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.path, required this.onRemove});
  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(path),
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_rounded),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
