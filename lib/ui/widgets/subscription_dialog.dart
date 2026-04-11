import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/model/subscription_item.dart';

class SubscriptionDialog extends StatefulWidget {
  final SubscriptionItem? item;
  final Function(SubscriptionItem) onSave;
  final bool isEditing;

  const SubscriptionDialog({
    super.key,
    this.item,
    required this.onSave,
    bool? isEditingOverride,
  }) : isEditing = isEditingOverride ?? item != null;
  });

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
    _priceController = TextEditingController(
      text: widget.item == null ? '' : widget.item!.price.toString(),
    );
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
    final isEditing = widget.isEditing;

    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEditing ? Icons.edit_rounded : Icons.add_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isEditing ? '編輯訂閱' : '新增訂閱',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('名稱', Icons.label_rounded),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: '例如 Netflix、Spotify',
                      hintStyle: TextStyle(color: Color(0xFF556677)),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? '此欄位必填' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('網站 URL', Icons.link_rounded),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _siteController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'https://example.com',
                      hintStyle: TextStyle(color: Color(0xFF556677)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('金額', Icons.payments_rounded),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _priceController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(color: Color(0xFF556677)),
                                prefixText: '\$ ',
                                prefixStyle: TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty) ? '此欄位必填' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('帳號', Icons.person_outline_rounded),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _accountController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: '可填登入帳號或方案名稱',
                                hintStyle: TextStyle(color: Color(0xFF556677)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('備註', Icons.note_rounded),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _noteController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: '例如家庭方案、年繳折扣、提醒事項',
                      hintStyle: TextStyle(color: Color(0xFF556677)),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('下次扣款日', Icons.calendar_today_rounded),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _nextDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Color(0xFF7C4DFF),
                                onPrimary: Colors.white,
                                surface: Color(0xFF1A1A2E),
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setState(() => _nextDate = date);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16213E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A2A4E)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_rounded, size: 18, color: Color(0xFF7C4DFF)),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('yyyy / MM / dd').format(_nextDate),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF8899AA)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFF2A2A4E)),
                            ),
                          ),
                          child: const Text(
                            '取消',
                            style: TextStyle(
                              color: Color(0xFF8899AA),
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C4DFF).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                final newItem = SubscriptionItem(
                                  id: widget.item?.id ?? '',
                                  name: _nameController.text.trim(),
                                  site: _siteController.text.trim(),
                                  price: int.tryParse(_priceController.text.trim()) ?? 0,
                                  nextDate: _nextDate,
                                  note: _noteController.text.trim(),
                                  account: _accountController.text.trim(),
                                );
                                widget.onSave(newItem);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isEditing ? '儲存變更' : '新增訂閱',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF7C4DFF)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8899AA),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
