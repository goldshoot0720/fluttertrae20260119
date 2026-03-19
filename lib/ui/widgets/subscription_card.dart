import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/model/subscription_item.dart';

class SubscriptionCard extends StatefulWidget {
  final SubscriptionItem item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final int index;

  const SubscriptionCard({
    Key? key,
    required this.item,
    this.onEdit,
    this.onDelete,
    this.index = 0,
  }) : super(key: key);

  @override
  State<SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<SubscriptionCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _entranceController;
  late Animation<double> _entranceAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(_entranceAnimation);

    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

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
    if (days <= 3) return const Color(0xFFFFD740);
    if (days <= 7) return const Color(0xFF69F0AE);
    return const Color(0xFF448AFF);
  }

  Color get _cardGradientStart {
    final days = _daysUntilExpiry;
    if (days <= 0) return const Color(0xFF2A1215);
    if (days <= 1) return const Color(0xFF2A1E10);
    if (days <= 3) return const Color(0xFF2A2510);
    return const Color(0xFF151528);
  }

  String get _daysLabel {
    final days = _daysUntilExpiry;
    if (days < 0) return '已過期';
    if (days == 0) return '今天';
    if (days == 1) return '明天';
    return '$days 天';
  }

  IconData get _urgencyIcon {
    final days = _daysUntilExpiry;
    if (days <= 0) return Icons.error_rounded;
    if (days <= 1) return Icons.warning_amber_rounded;
    if (days <= 3) return Icons.access_alarm_rounded;
    if (days <= 7) return Icons.schedule_rounded;
    return Icons.check_circle_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    final currencyFormat =
        NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _entranceAnimation,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
            transform: _isHovered
                ? (Matrix4.identity()..translate(0.0, -3.0))
                : Matrix4.identity(),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _isHovered
                      ? _cardGradientStart.withOpacity(0.95)
                      : _cardGradientStart,
                  _isHovered
                      ? const Color(0xFF1C1C3A)
                      : const Color(0xFF161630),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isHovered
                    ? _urgencyColor.withOpacity(0.5)
                    : const Color(0xFF2A2A4E).withOpacity(0.6),
                width: _isHovered ? 1.5 : 1,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: _urgencyColor.withOpacity(0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Left urgency strip with gradient
                    Container(
                      width: 5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _urgencyColor,
                            _urgencyColor.withOpacity(0.4),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
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
                                // Urgency icon
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _urgencyColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(_urgencyIcon,
                                      color: _urgencyColor, size: 16),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    widget.item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Urgency badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _urgencyColor.withOpacity(0.2),
                                        _urgencyColor.withOpacity(0.08),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: _urgencyColor.withOpacity(0.35)),
                                  ),
                                  child: Text(
                                    _daysLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _urgencyColor,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Price
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF00E5FF)
                                            .withOpacity(0.15),
                                        const Color(0xFF448AFF)
                                            .withOpacity(0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFF00E5FF)
                                          .withOpacity(0.2),
                                    ),
                                  ),
                                  child: Text(
                                    currencyFormat.format(widget.item.price),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Color(0xFF00E5FF),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Row 2: Date, account, actions
                            Row(
                              children: [
                                Icon(Icons.calendar_today_rounded,
                                    size: 13,
                                    color: _urgencyColor.withOpacity(0.6)),
                                const SizedBox(width: 5),
                                Text(
                                  dateFormat.format(widget.item.nextDate),
                                  style: TextStyle(
                                    color: const Color(0xFF8899AA),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (widget.item.account.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF7C4DFF)
                                              .withOpacity(0.15),
                                          const Color(0xFF7C4DFF)
                                              .withOpacity(0.05),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFF7C4DFF)
                                            .withOpacity(0.2),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                            Icons.person_outline_rounded,
                                            size: 11,
                                            color: Color(0xFF9E8CFF)),
                                        const SizedBox(width: 3),
                                        Text(
                                          widget.item.account,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF9E8CFF),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                // Action buttons
                                if (widget.item.site.isNotEmpty)
                                  _buildActionButton(
                                    icon: Icons.open_in_new_rounded,
                                    color: const Color(0xFF448AFF),
                                    onTap: () async {
                                      final uri = Uri.parse(widget.item.site);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri);
                                      }
                                    },
                                  ),
                                const SizedBox(width: 4),
                                _buildActionButton(
                                  icon: Icons.edit_rounded,
                                  color: const Color(0xFF7C4DFF),
                                  onTap: widget.onEdit,
                                ),
                                const SizedBox(width: 4),
                                _buildActionButton(
                                  icon: Icons.delete_outline_rounded,
                                  color: const Color(0xFFFF5252),
                                  onTap: widget.onDelete,
                                ),
                              ],
                            ),
                            // Row 3: Note
                            if (widget.item.note.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF16213E).withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF2A2A4E)
                                        .withOpacity(0.4),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.notes_rounded,
                                      size: 13,
                                      color: Color(0xFF556677),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        widget.item.note,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF8899AA),
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
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
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(_isHovered ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withOpacity(_isHovered ? 0.3 : 0.1),
            ),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}
