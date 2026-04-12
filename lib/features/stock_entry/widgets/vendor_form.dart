import 'package:flutter/material.dart';

class VendorFormValues {
  VendorFormValues({
    required this.name,
    required this.phone,
    required this.gst,
    this.email,
    this.address,
  });

  final String name;
  final String phone;
  final String gst;
  final String? email;
  final String? address;
}

class VendorForm extends StatefulWidget {
  const VendorForm({super.key, required this.onStartStockEntry});

  final ValueChanged<VendorFormValues> onStartStockEntry;

  @override
  State<VendorForm> createState() => _VendorFormState();
}

class _VendorFormState extends State<VendorForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _gstController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    widget.onStartStockEntry(
      VendorFormValues(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        gst: _gstController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    InputDecoration decoration({
      required String label,
      required IconData icon,
      String? hint,
    }) {
      return InputDecoration(
        isDense: true,
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.badge_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vendor details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Enter details to start stock entry.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: decoration(
              label: 'Vendor name',
              icon: Icons.storefront_outlined,
              hint: 'Example: Shree Traders',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty)
                return 'Vendor name is required';
              if (v.trim().length < 2) return 'Enter a valid vendor name';
              return null;
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _phoneController,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.phone,
            decoration: decoration(
              label: 'Phone number',
              icon: Icons.phone_outlined,
              hint: 'Example: 9876543210',
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Phone number is required';
              final digits = value.replaceAll(RegExp(r'\D'), '');
              if (digits.length < 10) return 'Enter a valid phone number';
              return null;
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _emailController,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.emailAddress,
            decoration: decoration(
              label: 'Email address (optional)',
              icon: Icons.email_outlined,
              hint: 'Example: vendor@email.com',
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return null;
              if (!value.contains('@') || !value.contains('.')) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _addressController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.streetAddress,
            maxLines: 2,
            decoration: decoration(
              label: 'Address (optional)',
              icon: Icons.location_on_outlined,
              hint: 'Street / area / city',
            ),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _gstController,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.characters,
            decoration: decoration(
              label: 'GST',
              icon: Icons.receipt_long_outlined,
              hint: 'Example: 22AAAAA0000A1Z5',
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'GST is required';
              if (value.length < 5) return 'Enter a valid GST';
              return null;
            },
          ),
          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Stock Entry'),
          ),
        ],
      ),
    );
  }
}
