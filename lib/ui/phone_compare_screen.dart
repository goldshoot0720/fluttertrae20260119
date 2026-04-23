import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/model/phone_compare_models.dart';
import '../data/service/phone_compare_service.dart';

class PhoneCompareScreen extends StatefulWidget {
  const PhoneCompareScreen({super.key});

  @override
  State<PhoneCompareScreen> createState() => _PhoneCompareScreenState();
}

class _PhoneCompareScreenState extends State<PhoneCompareScreen> {
  final PhoneCompareService _service = PhoneCompareService();
  final TextEditingController _queryController = TextEditingController(
    text: 'Samsung 26',
  );
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'zh_TW',
    symbol: 'NT\$ ',
    decimalDigits: 0,
  );

  PhoneCompareResult? _result;
  bool _isLoading = false;
  String _status = '輸入型號後開始比價';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      _status = refresh ? '正在重新整理來源...' : '正在查詢手機價格...';
    });

    try {
      final result = await _service.fetchCatalog(
        query: _queryController.text.trim(),
        refresh: refresh,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
        _status = result.products.isEmpty
            ? '沒有找到符合條件的手機'
            : '完成，共 ${result.products.length} 筆';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _status = '查詢失敗：$e';
      });
    }
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatPrice(int? price) {
    if (price == null) return '--';
    return _currencyFormat.format(price);
  }

  @override
  Widget build(BuildContext context) {
    final products = _result?.products ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text(
          '手機比價',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _isLoading ? null : () => _load(refresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildHeroCard(),
            const SizedBox(height: 16),
            _buildSearchCard(),
            const SizedBox(height: 16),
            if (_result?.warnings.isNotEmpty == true) ...[
              _buildWarningCard(_result!.warnings),
              const SizedBox(height: 16),
            ],
            _buildChartCard(products),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (products.isEmpty)
              _buildEmptyCard()
            else
              ...products.take(30).map(_buildProductCard),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF083344), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.smartphone_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Landtop x JYES 手機比價',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '搜尋 iPhone、Samsung 或容量型號，快速看地標網通與傑昇通信的低價。',
                  style: TextStyle(color: Color(0xFFD8FFFA), height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    final fetchedAt = _result?.fetchedAt;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _queryController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _isLoading ? null : _load(),
            decoration: InputDecoration(
              hintText: '例如 iPhone 17、Samsung 26、A17、512GB',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: '清空',
                onPressed: () => _queryController.clear(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _isLoading ? null : () => _load(),
                icon: const Icon(Icons.search_rounded),
                label: const Text('開始比價'),
              ),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _load(refresh: true),
                icon: const Icon(Icons.sync_rounded),
                label: const Text('重新抓取'),
              ),
              ActionChip(
                avatar: const Icon(Icons.phone_iphone_rounded, size: 18),
                label: const Text('iPhone'),
                onPressed: () {
                  _queryController.text = 'iPhone';
                  _load();
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.android_rounded, size: 18),
                label: const Text('Samsung'),
                onPressed: () {
                  _queryController.text = 'Samsung';
                  _load();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            fetchedAt == null
                ? _status
                : '$_status，更新時間：${DateFormat('yyyy/MM/dd HH:mm').format(fetchedAt)}',
            style: const TextStyle(color: Color(0xFF576B66)),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard(List<String> warnings) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF5C38A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: warnings
            .map(
              (warning) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFFC66A1E),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warning,
                        style: const TextStyle(color: Color(0xFF9A531D)),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildChartCard(List<PhoneCompareProduct> products) {
    final chartProducts = products
        .where((product) => product.bestPrice != null)
        .take(8)
        .toList();
    final maxPrice = chartProducts
        .map((product) => product.bestPrice ?? 0)
        .fold<int>(1, (max, price) => price > max ? price : max);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '最低價排行',
            style: TextStyle(
              color: Color(0xFF173832),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (chartProducts.isEmpty)
            const Text(
              '查詢完成後會顯示前 8 筆最低價格。',
              style: TextStyle(color: Color(0xFF576B66)),
            )
          else
            Column(
              children: chartProducts.map((product) {
                final best = product.bestPrice ?? 0;
                final widthFactor = (best / maxPrice).clamp(0.05, 1.0);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF173832),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatPrice(best),
                            style: const TextStyle(
                              color: Color(0xFF0F766E),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FractionallySizedBox(
                        widthFactor: widthFactor,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: const Text(
        '目前沒有結果。可以試試 Samsung、iPhone、A17、512GB 這類關鍵字。',
        style: TextStyle(color: Color(0xFF576B66)),
      ),
    );
  }

  Widget _buildProductCard(PhoneCompareProduct product) {
    final savings = product.savings;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openUrl(product.jyesUrl ?? product.sourceUrl),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            color: Color(0xFF173832),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${product.brand.toUpperCase()}'
                          '${product.bestSourceLabel == null ? '' : ' · 最低：${product.bestSourceLabel}'}',
                          style: const TextStyle(
                            color: Color(0xFF6A7D78),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '開啟來源',
                    onPressed: () =>
                        _openUrl(product.jyesUrl ?? product.sourceUrl),
                    icon: const Icon(Icons.open_in_new_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth >= 620
                      ? (constraints.maxWidth - 24) / 4
                      : (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildPriceTile(
                        '建議售價',
                        _formatPrice(product.suggestedPrice),
                        itemWidth,
                      ),
                      _buildPriceTile(
                        '地標網通',
                        product.landtopPriceLabel,
                        itemWidth,
                      ),
                      _buildPriceTile(
                        '傑昇通信',
                        product.jyesPriceLabel ??
                            _formatPrice(product.jyesPrice),
                        itemWidth,
                      ),
                      _buildPriceTile(
                        '最低價',
                        _formatPrice(product.bestPrice),
                        itemWidth,
                      ),
                    ],
                  );
                },
              ),
              if (savings != null) ...[
                const SizedBox(height: 12),
                Text(
                  savings >= 0
                      ? '比建議售價省 ${_formatPrice(savings)}'
                      : '高於建議售價 ${_formatPrice(savings.abs())}',
                  style: TextStyle(
                    color: savings >= 0
                        ? const Color(0xFF0F766E)
                        : const Color(0xFFB45309),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceTile(String label, String value, double width) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F6F4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCE8E4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6A7D78),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF173832),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFDCE8E4)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0B3B32).withOpacity(0.06),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}
