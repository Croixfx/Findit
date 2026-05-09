import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class InstitutionSetupScreen extends StatefulWidget {
  const InstitutionSetupScreen({super.key});

  @override
  State<InstitutionSetupScreen> createState() => _InstitutionSetupScreenState();
}

class _InstitutionSetupScreenState extends State<InstitutionSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _apiService = ApiService();

  String? _selectedType;
  String? _duplicateError;

  static const _types = [
    ('university', 'University'),
    ('hospital', 'Hospital'),
    ('hotel', 'Hotel'),
    ('office', 'Office'),
    ('other', 'Other'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _duplicateError = null);
    FocusScope.of(context).unfocus();

    // Check for duplicate institution name
    try {
      final data = await _apiService.get('/institutions');
      final institutions = data as List<dynamic>;
      final name = _nameController.text.trim().toLowerCase();
      final exists = institutions.any(
        (inst) => (inst['name'] as String? ?? '').toLowerCase() == name,
      );
      if (exists) {
        setState(() => _duplicateError =
            'An institution with this name already exists. '
            'Ask your administrator to link your account.');
        return;
      }
    } catch (_) {
      // Network error during check — proceed and let the backend decide.
    }

    try {
      await context.read<FindItAuthProvider>().setupInstitution(
            name: _nameController.text.trim(),
            type: _selectedType!,
            contactEmail: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
          );
      if (!mounted) return;
      final auth = context.read<FindItAuthProvider>();
      final status = (auth.institution?.status ?? '').toLowerCase();
      final target = status == 'active'
          ? '/staff-home'
          : '/pending-approval';
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Institution submitted successfully.'),
          duration: Duration(milliseconds: 1200),
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(target, (_) => false);
    } catch (_) {
      // Error shown via provider.error banner.
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<FindItAuthProvider>();
    final role = (auth.currentUser?.role ?? '').toLowerCase();
    final hasInstitution =
        role == 'staff' && auth.currentUser?.institutionId != null;

    // If institution was already linked before, skip setup automatically.
    if (hasInstitution) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final status = (auth.institution?.status ?? '').toLowerCase();
        final target = status == 'active'
            ? '/staff-home'
            : '/pending-approval';
        Navigator.of(context).pushNamedAndRemoveUntil(target, (_) => false);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
            onPressed: () => context.read<FindItAuthProvider>().logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Icon(Icons.business_rounded, size: 56, color: cs.primary),
                const SizedBox(height: 20),
                Text(
                  'No institution linked yet',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Add your institution details to continue. Once submitted, we'll review and activate your access.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 36),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) =>
                      setState(() => _duplicateError = null),
                  decoration: _decoration(
                      'Institution name', Icons.business_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Institution name is required';
                    }
                    if (v.trim().length < 2) {
                      return 'Enter the full institution name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: _decoration(
                      'Institution type', Icons.category_outlined),
                  items: _types
                      .map((t) =>
                          DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedType = v),
                  validator: (v) =>
                      v == null ? 'Please select an institution type' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: _decoration(
                      'Contact email (optional)', Icons.email_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                        .hasMatch(v.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'Used to contact your institution about the review.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 28),
                if (_duplicateError != null) ...[
                  _Banner(
                    message: _duplicateError!,
                    color: cs.errorContainer,
                    textColor: cs.onErrorContainer,
                    icon: Icons.info_outline_rounded,
                    iconColor: cs.error,
                  ),
                  const SizedBox(height: 12),
                ],
                if (auth.error != null) ...[
                  _Banner(
                    message: auth.error!,
                    color: cs.errorContainer,
                    textColor: cs.onErrorContainer,
                    icon: Icons.error_outline_rounded,
                    iconColor: cs.error,
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: auth.isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text(
                          'Submit for Review',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.color,
    required this.textColor,
    required this.icon,
    required this.iconColor,
  });

  final String message;
  final Color color;
  final Color textColor;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _decoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDADADA)),
    ),
    filled: true,
  );
}
