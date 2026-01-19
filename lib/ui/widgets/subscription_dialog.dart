import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/model/subscription_item.dart';

class SubscriptionDialog extends StatefulWidget {
  final SubscriptionItem? item;
  final Function(SubscriptionItem) onSave;

  const SubscriptionDialog({Key? key, this.item, required this.onSave}) : super(key: key);

  @override
  State<SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<SubscriptionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _siteController;
  late TextEditingController _priceController;
  late TextEditingController _noteController;
  late TextEditingController _accountController;
  DateTime _nextDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _siteController = TextEditingController(text: widget.item?.site ?? '');
    _priceController = TextEditingController(text: widget.item?.price.toString() ?? '');
    _noteController = TextEditingController(text: widget.item?.note ?? '');
    _accountController = TextEditingController(text: widget.item?.account ?? '');
    _nextDate = widget.item?.nextDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _siteController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add Subscription' : 'Edit Subscription'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _siteController,
                decoration: const InputDecoration(labelText: 'Site URL'),
              ),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _accountController,
                decoration: const InputDecoration(labelText: 'Account'),
              ),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Note'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Next Date: '),
                  TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _nextDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() => _nextDate = date);
                      }
                    },
                    child: Text(DateFormat('yyyy-MM-dd').format(_nextDate)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final newItem = SubscriptionItem(
                id: widget.item?.id ?? '', // ID handled by service if empty
                name: _nameController.text,
                site: _siteController.text,
                price: int.tryParse(_priceController.text) ?? 0,
                nextDate: _nextDate,
                note: _noteController.text,
                account: _accountController.text,
              );
              widget.onSave(newItem);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
