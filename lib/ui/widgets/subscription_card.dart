import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/model/subscription_item.dart';

class SubscriptionCard extends StatefulWidget {
  final SubscriptionItem item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const SubscriptionCard({
    Key? key,
    required this.item,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  State<SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<SubscriptionCard> {
  bool _isHovered = false;

  int get _daysUntilExpiry {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(
      widget.item.nextDate.year,
      widget.item.nextDate.month,
      widget.item.nextDate.day,
    );
    return itemDate.difference(today).inDays;
  }

  Color get _urgencyColor {
    final days = _daysUntilExpiry;
    if (days <= 0) return const Color(0xFFFF5252);
    if (days <= 1) return const Color(0xFFFF9800);
    if (days <= 3) return const Color(0xFFFFEB3B);
    if (days <= 7) return const Color(0xFF4CAF50);
    return const Color(0xFF448AFF);
  }

  String get _daysLabel {
    final days = _daysUntilExpiry;
    if (days < 0) return '已過期';
    if (days == 0) return '今天';
    if (days == 1) return '明天';
    return '$days 天';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        transform: _isHovered
            ? (Matrix4.identity()..translate(0.0, -2.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFF1E1E3E) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? _urgencyColor.withOpacity(0.4) : const Color(0xFF2A2A4E),
            width: 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: _urgencyColor.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left urgency strip
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: _urgencyColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              // Card content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Name, price, urgency badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Urgency badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _urgencyColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _urgencyColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              _daysLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _urgencyColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Price
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF00E5FF).withOpacity(0.15),
                                  const Color(0xFF448AFF).withOpacity(0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              currencyFormat.format(widget.item.price),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF00E5FF),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Row 2: Date, account, link
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 14, color: _urgencyColor.withOpacity(0.7)),
                          const SizedBox(width: 5),
                          Text(
                            dateFormat.format(widget.item.nextDate),
                            style: const TextStyle(
                              color: Color(0xFF8899AA),
                              fontSize: 12,
                            ),
                          ),
                          if (widget.item.account.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C4DFF).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_outline_rounded, size: 12, color: Color(0xFF7C4DFF)),
                                  const SizedBox(width: 3),
                                  Text(
                                    widget.item.account,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9E8CFF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (widget.item.site.isNotEmpty)
                            InkWell(
                              onTap: () async {
                                final uri = Uri.parse(widget.item.site);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF448AFF).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF448AFF)),
                              ),
                            ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: widget.onEdit,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C4DFF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF7C4DFF)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: widget.onDelete,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5252).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFFF5252)),
                            ),
                          ),
                        ],
                      ),
                      // Row 3: Note (if exists)
                      if (widget.item.note.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16213E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.item.note,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8899AA),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
