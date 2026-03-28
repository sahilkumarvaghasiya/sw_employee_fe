import 'package:flutter/material.dart';

import '../models/vendor.dart';

class VendorFormValues {
  VendorFormValues({
    required this.name,
    required this.address,
    required this.gender,
  });

  final String name;
  final String address;
  final VendorGender gender;
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

  VendorGender _gender = VendorGender.other;

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
        gender: _gender,
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
          Text(
            'Vendor details',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Vendor Name',
              prefixIcon: Icon(Icons.storefront_outlined),
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
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Address',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Address is required';
              return null;
            },
          ),
          const SizedBox(height: 16),

          Text(
            'Gender',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),

          SegmentedButton<VendorGender>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: VendorGender.male,
                label: Text('Male'),
                icon: Icon(Icons.male),
              ),
              ButtonSegment(
                value: VendorGender.female,
                label: Text('Female'),
                icon: Icon(Icons.female),
              ),
              ButtonSegment(
                value: VendorGender.other,
                label: Text('Other'),
                icon: Icon(Icons.person_outline),
              ),
            ],
            selected: {_gender},
            onSelectionChanged: (value) {
              if (value.isEmpty) return;
              setState(() => _gender = value.first);
            },
          ),
          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Start Stock Entry'),
            ),
          ),
        ],
      ),
    );
  }
}
