import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

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
  const VendorForm({
    super.key,
    required this.onStartStockEntry,
    this.isSubmitting = false,
  });

  final ValueChanged<VendorFormValues> onStartStockEntry;
  final bool isSubmitting;

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

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: AppColors.emerald,
                  size: 22,
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Required fields marked below',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Vendor name *',
              prefixIcon: Icon(Icons.storefront_outlined),
              hintText: 'e.g. Shree Traders',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Vendor name is required';
              }
              if (v.trim().length < 2) return 'Enter a valid vendor name';
              return null;
            },
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _phoneController,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number *',
              prefixIcon: Icon(Icons.phone_outlined),
              hintText: '10-digit mobile number',
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Phone number is required';
              final digits = value.replaceAll(RegExp(r'\D'), '');
              if (digits.length < 10) return 'Enter a valid phone number';
              return null;
            },
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _emailController,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email (optional)',
              prefixIcon: Icon(Icons.email_outlined),
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
          const SizedBox(height: 14),

          TextFormField(
            controller: _addressController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.streetAddress,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Address (optional)',
              prefixIcon: Icon(Icons.location_on_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _gstController,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'GST (optional)',
              prefixIcon: Icon(Icons.receipt_long_outlined),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return null;
              if (value.length < 5) return 'Enter a valid GST number';
              return null;
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: widget.isSubmitting ? null : _submit,
              icon: widget.isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(
                widget.isSubmitting ? 'Checking vendor…' : 'Continue to add items',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
