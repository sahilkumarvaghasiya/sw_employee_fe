import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/billing_models.dart';
import '../providers/billing_provider.dart';
import 'billing_screen.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/billing/customer'),
      builder: (_) {
        return ChangeNotifierProvider(
          create: (_) => BillingProvider(),
          child: const CustomerFormScreen(),
        );
      },
    );
  }

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _addressFocusNode = FocusNode();

  bool _showHowBillingWorks = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateRequired(String? value, {required String label}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$label is required';
    return null;
  }

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Phone number is required';

    final digitsOnly = v.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 8) return 'Enter a valid phone number';

    return null;
  }

  void _start() {
    final form = _formKey.currentState;
    if (form == null) return;

    if (!form.validate()) {
      _showSnack('Please fix highlighted fields.');
      return;
    }

    final customer = BillingCustomer(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
    );

    final provider = context.read<BillingProvider>();
    provider.setCustomer(customer);

    Navigator.of(context).pushReplacement(BillingScreen.route(context));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final billingProvider = context.read<BillingProvider>();

    InputDecoration fieldDecoration({
      required String label,
      required IconData icon,
      String? helper,
    }) {
      return InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Start billing')),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 860;

            final header = Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: colorScheme.primary.withOpacity(0.12),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer details',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add customer info to start scanning products.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );

            final formCard = Card(
              elevation: 0,
              color: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Customer',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RawAutocomplete<BillingCustomer>(
                        textEditingController: _nameController,
                        focusNode: _nameFocusNode,
                        displayStringForOption: (c) => c.name,
                        optionsBuilder: (textEditingValue) {
                          final q = textEditingValue.text;
                          if (q.trim().isEmpty) {
                            return const Iterable<BillingCustomer>.empty();
                          }
                          return billingProvider.searchCustomers(q);
                        },
                        onSelected: (customer) {
                          _nameController.text = customer.name;
                          _nameController.selection = TextSelection.collapsed(
                            offset: customer.name.length,
                          );
                          _phoneController.text = customer.phone;
                          _phoneController.selection = TextSelection.collapsed(
                            offset: customer.phone.length,
                          );
                          _addressController.text = customer.address ?? '';
                          _addressController.selection =
                              TextSelection.collapsed(
                                offset: _addressController.text.length,
                              );

                          FocusScope.of(context).requestFocus(_phoneFocusNode);
                        },
                        fieldViewBuilder:
                            (
                              context,
                              textEditingController,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                textInputAction: TextInputAction.next,
                                decoration: fieldDecoration(
                                  label: 'Customer name',
                                  icon: Icons.person_outline,
                                  helper:
                                      'Start typing to search existing customers.',
                                ),
                                validator: (v) => _validateRequired(
                                  v,
                                  label: 'Customer name',
                                ),
                                onFieldSubmitted: (_) {
                                  onFieldSubmitted();
                                  FocusScope.of(
                                    context,
                                  ).requestFocus(_phoneFocusNode);
                                },
                              );
                            },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 6,
                              borderRadius: BorderRadius.circular(16),
                              clipBehavior: Clip.antiAlias,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 560,
                                  maxHeight: 260,
                                ),
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final c = options.elementAt(index);
                                    return ListTile(
                                      leading: const Icon(Icons.person_outline),
                                      title: Text(
                                        c.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        c.phone,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () => onSelected(c),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        focusNode: _phoneFocusNode,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: fieldDecoration(
                          label: 'Phone number',
                          icon: Icons.phone_outlined,
                          helper:
                              'Used for bill history / WhatsApp invoice (later).',
                        ),
                        validator: _validatePhone,
                        onFieldSubmitted: (_) {
                          FocusScope.of(
                            context,
                          ).requestFocus(_addressFocusNode);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        focusNode: _addressFocusNode,
                        keyboardType: TextInputType.streetAddress,
                        textInputAction: TextInputAction.done,
                        decoration: fieldDecoration(
                          label: 'Address (optional)',
                          icon: Icons.location_on_outlined,
                        ),
                        minLines: 1,
                        maxLines: 3,
                        onFieldSubmitted: (_) => _start(),
                      ),
                    ],
                  ),
                ),
              ),
            );

            final sidePanel = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_showHowBillingWorks)
                  Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'How billing works',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: () {
                                  setState(() => _showHowBillingWorks = false);
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: colorScheme.primary.withOpacity(
                                0.12,
                              ),
                              child: Text(
                                '1',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            title: const Text('Enter customer'),
                            subtitle: const Text('Name and phone number'),
                          ),
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: colorScheme.primary.withOpacity(
                                0.12,
                              ),
                              child: Text(
                                '2',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            title: const Text('Scan products'),
                            subtitle: const Text('Add items to the bill'),
                          ),
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: colorScheme.primary.withOpacity(
                                0.12,
                              ),
                              child: Text(
                                '3',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            title: const Text('Take payment'),
                            subtitle: const Text('UPI / Cash / Card'),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.privacy_tip_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Customer details are only used for billing and invoice reference.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );

            final content = Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: isWide
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            header,
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: formCard),
                                const SizedBox(width: 14),
                                Expanded(flex: 2, child: sidePanel),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            header,
                            const SizedBox(height: 14),
                            formCard,
                            const SizedBox(height: 12),
                            sidePanel,
                          ],
                        ),
                ),
              ),
            );

            return SingleChildScrollView(child: content);
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Continue to Scan'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
