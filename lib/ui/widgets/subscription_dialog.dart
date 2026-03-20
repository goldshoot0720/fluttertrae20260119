import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/model/subscription_item.dart';

class SubscriptionDialog extends StatefulWidget {
  final SubscriptionItem? item;
  final Function(SubscriptionItem) onSave;

  const SubscriptionDialog({
    super.key,
    this.item,
    required this.onSave,
  });

  @override
  State<SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<SubscriptionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _siteController;
  late final TextEditingController _priceController;
  late final TextEditingController _noteController;
  late final TextEditingController _accountController;
  late DateTime _nextDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _siteController = TextEditingController(text: widget.item?.site ?? '');
    _priceController =
        TextEditingController(text: widget.item?.price.toString() ?? '');
    _noteController = TextEditingController(text: widget.item?.note ?? '');
    _accountController =
        TextEditingController(text: widget.item?.account ?? '');
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

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _nextDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF0F766E),
                  surface: const Color(0xFFF9F5EC),
                ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() => _nextDate = date);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    widget.onSave(
      SubscriptionItem(
        id: widget.item?.id ?? '',
        name: _nameController.text.trim(),
        site: _siteController.text.trim(),
        price: int.tryParse(_priceController.text.trim()) ?? 0,
        nextDate: _nextDate,
        note: _noteController.text.trim(),
        account: _accountController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1EFEB),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    isEditing ? Icons.tune_rounded : Icons.add_rounded,
                    size: 30,
                    color: const Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  isEditing ? '編輯訂閱項目' : '新增訂閱項目',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E1B18),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '把帳號、扣款日與備註整理在同一處，之後提醒會更準。',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                _FieldLabel('服務名稱'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: '例如 Netflix、Spotify、iCloud+',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '請輸入服務名稱';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                _FieldLabel('網站連結'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _siteController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'https://example.com',
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel('價格'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: '0',
                              prefixText: '\$ ',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '請輸入價格';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel('帳號'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _accountController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: '例如 main@email.com',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _FieldLabel('備註'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  textInputAction: TextInputAction.newline,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '例如家庭方案、年繳改月繳、共用成員資訊',
                  ),
                ),
                const SizedBox(height: 18),
                _FieldLabel('下次扣款日'),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(20),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFCF6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD8CDBE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_outlined,
                          color: Color(0xFF0F766E),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            DateFormat('yyyy.MM.dd').format(_nextDate),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: Text(isEditing ? '儲存變更' : '建立項目'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFF62584F),
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
