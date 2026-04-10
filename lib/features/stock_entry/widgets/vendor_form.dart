import 'package:flutter/material.dart';

class VendorFormValues {
  VendorFormValues({required this.name, required this.address});

  final String name;
  final String address;
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
  final TextEditingController _addressController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    widget.onStartStockEntry(
      VendorFormValues(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
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
            controller: _addressController,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.streetAddress,
            maxLines: 2,
            decoration: decoration(
              label: 'Address',
              icon: Icons.location_on_outlined,
              hint: 'Street / area / city',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Address is required';
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
