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
    super.key,
    required this.item,
    this.onEdit,
    this.onDelete,
    this.index = 0,
  });

  @override
  State<SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<SubscriptionCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_fadeAnimation);

    Future<void>.delayed(Duration(milliseconds: widget.index * 55), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _daysUntilRenewal {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      widget.item.nextDate.year,
      widget.item.nextDate.month,
      widget.item.nextDate.day,
    );
    return target.difference(today).inDays;
  }

  _RenewalTone get _tone {
    final days = _daysUntilRenewal;
    if (days < 0) return _RenewalTone.overdue;
    if (days <= 1) return _RenewalTone.urgent;
    if (days <= 3) return _RenewalTone.warning;
    if (days <= 7) return _RenewalTone.watch;
    return _RenewalTone.calm;
  }

  String get _renewalLabel {
    final days = _daysUntilRenewal;
    if (days < 0) return '已逾期';
    if (days == 0) return '今天扣款';
    if (days == 1) return '明天扣款';
    return '$days 天後扣款';
  }

  Future<void> _openSite() async {
    if (widget.item.site.isEmpty) return;

    final uri = Uri.tryParse(widget.item.site);
    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 0,
    );
    final date = DateFormat('yyyy.MM.dd').format(widget.item.nextDate);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()..translate(0.0, _isHovered ? -4.0 : 0.0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _tone.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _tone.border),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x16000000),
                    blurRadius: _isHovered ? 28 : 18,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _tone.badgeBackground,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(_tone.icon, color: _tone.accent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.item.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _MetaPill(
                                  label: _renewalLabel,
                                  foreground: _tone.accent,
                                  background: _tone.badgeBackground,
                                ),
                                _MetaPill(
                                  label: date,
                                  foreground: const Color(0xFF5E554E),
                                  background: const Color(0xFFF2EBDD),
                                ),
                                if (widget.item.account.isNotEmpty)
                                  _MetaPill(
                                    label: widget.item.account,
                                    foreground: const Color(0xFF725A17),
                                    background: const Color(0xFFF4E7BF),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            money.format(widget.item.price),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '每期支出',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF736960),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (widget.item.note.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBF4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE6DAC7)),
                      ),
                      child: Text(
                        widget.item.note,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5B544D),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (widget.item.site.isNotEmpty)
                        _ActionChip(
                          icon: Icons.language_rounded,
                          label: '前往網站',
                          onTap: _openSite,
                        ),
                      if (widget.item.site.isNotEmpty) const SizedBox(width: 8),
                      _ActionChip(
                        icon: Icons.edit_outlined,
                        label: '編輯',
                        onTap: widget.onEdit,
                      ),
                      const SizedBox(width: 8),
                      _ActionChip(
                        icon: Icons.delete_outline_rounded,
                        label: '刪除',
                        destructive: true,
                        onTap: widget.onDelete,
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
}

class _MetaPill extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;

  const _MetaPill({
    required this.label,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    this.destructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground =
        destructive ? const Color(0xFFB42318) : const Color(0xFF2E5B54);
    final background =
        destructive ? const Color(0xFFFCE9E6) : const Color(0xFFE7F2EF);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RenewalTone {
  final Color surface;
  final Color border;
  final Color accent;
  final Color badgeBackground;
  final IconData icon;

  const _RenewalTone({
    required this.surface,
    required this.border,
    required this.accent,
    required this.badgeBackground,
    required this.icon,
  });

  static const overdue = _RenewalTone(
    surface: Color(0xFFFBEEEA),
    border: Color(0xFFF1C8BD),
    accent: Color(0xFFB42318),
    badgeBackground: Color(0xFFF8DDD6),
    icon: Icons.priority_high_rounded,
  );

  static const urgent = _RenewalTone(
    surface: Color(0xFFFFF3E3),
    border: Color(0xFFF3D2A2),
    accent: Color(0xFFB45309),
    badgeBackground: Color(0xFFFBE2B8),
    icon: Icons.notifications_active_outlined,
  );

  static const warning = _RenewalTone(
    surface: Color(0xFFFFF8E7),
    border: Color(0xFFEEDB9A),
    accent: Color(0xFF9A6700),
    badgeBackground: Color(0xFFF5E8BF),
    icon: Icons.schedule_rounded,
  );

  static const watch = _RenewalTone(
    surface: Color(0xFFF3F6EA),
    border: Color(0xFFD4DFC1),
    accent: Color(0xFF4F6B21),
    badgeBackground: Color(0xFFE2EBCF),
    icon: Icons.timelapse_rounded,
  );

  static const calm = _RenewalTone(
    surface: Color(0xFFF5F2EA),
    border: Color(0xFFD9CFBF),
    accent: Color(0xFF0F766E),
    badgeBackground: Color(0xFFDAECE9),
    icon: Icons.check_circle_outline_rounded,
  );
}
