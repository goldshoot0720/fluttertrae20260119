import 'package:http/http.dart' as http;

import '../model/phone_compare_models.dart';

class PhoneCompareService {
  static const _landtopSources = [
    _PhoneSource(
      brand: 'samsung',
      url: 'https://www.landtop.com.tw/brands?brand=samsung',
    ),
    _PhoneSource(
      brand: 'apple',
      url: 'https://www.landtop.com.tw/brands?brand=apple',
    ),
  ];

  static const _jyesUrl = 'https://www.jyes.com.tw/product.php';
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36';

  Future<PhoneCompareResult> fetchCatalog({
    String query = '',
    bool refresh = false,
  }) async {
    final warnings = <String>[];
    final landtopProducts = <String, PhoneCompareProduct>{};

    for (final source in _landtopSources) {
      try {
        final html = await _fetchText(source.url, refresh: refresh);
        final products = _parseLandtopProducts(html, source.brand);
        for (final product in products) {
          landtopProducts[product.id] = product;
        }
      } catch (e) {
        warnings.add('${_brandLabel(source.brand)} 讀取失敗：$e');
      }
    }

    final jyesProducts = <PhoneCompareProduct>[];
    try {
      final text = await _fetchText(
        'https://r.jina.ai/http://r.jina.ai/http://$_jyesUrl',
        refresh: refresh,
      );
      jyesProducts.addAll(_parseJyesProducts(text));
    } catch (_) {
      try {
        final text = await _fetchText(
          'https://r.jina.ai/http://$_jyesUrl',
          refresh: refresh,
        );
        jyesProducts.addAll(_parseJyesProducts(text));
      } catch (e) {
        warnings.add('傑昇通信讀取失敗：$e');
      }
    }

    final merged =
        _mergeProducts(
            landtopProducts.values.toList(),
            jyesProducts,
          ).where((product) => _matchesQuery(product, query)).toList()
          ..sort((a, b) {
            final aPrice =
                a.bestPrice ?? a.landtopPrice ?? a.suggestedPrice ?? 1 << 30;
            final bPrice =
                b.bestPrice ?? b.landtopPrice ?? b.suggestedPrice ?? 1 << 30;
            return aPrice.compareTo(bPrice);
          });

    return PhoneCompareResult(
      query: query,
      fetchedAt: DateTime.now(),
      sourceUrls: [..._landtopSources.map((source) => source.url), _jyesUrl],
      warnings: warnings,
      products: merged,
    );
  }

  Future<String> _fetchText(String url, {required bool refresh}) async {
    final response = await http.get(
      Uri.parse(url),
      headers: const {
        'User-Agent': _userAgent,
        'Accept': 'text/html,text/plain,*/*',
        'Accept-Language': 'zh-TW,zh;q=0.9,en;q=0.8',
      },
    );
    if (response.statusCode >= 400) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return response.body;
  }

  List<PhoneCompareProduct> _parseLandtopProducts(String html, String brand) {
    final products = <String, PhoneCompareProduct>{};
    final markdownPattern = RegExp(
      r'##\s+\[([^\]]+)\]\((https:\/\/www\.landtop\.com\.tw\/products\/[^)]+)\)([\s\S]{0,700})',
      caseSensitive: false,
    );

    for (final match in markdownPattern.allMatches(html)) {
      final name = _normalizeName(match.group(1) ?? '');
      if (!_isPhoneName(name, brand)) continue;
      final chunk = match.group(3) ?? '';
      final prices = _extractPrices(chunk);
      final product = _buildLandtopProduct(
        brand: brand,
        name: name,
        sourceUrl: match.group(2) ?? '',
        suggestedPrice: prices.isNotEmpty ? prices.first : null,
        landtopPrice: prices.length > 1 ? prices[1] : null,
      );
      products[product.id] = product;
    }

    final cardPattern = RegExp(
      r'<a[^>]+href="(\/products\/[^"]+)"[\s\S]{0,2200}?(?:<h3[^>]*>|<div[^>]*product-name[^>]*>|<img[^>]+alt=")([\s\S]*?)(?:<\/h3>|<\/div>|")',
      caseSensitive: false,
    );

    for (final match in cardPattern.allMatches(html)) {
      final name = _normalizeName(_stripTags(match.group(2) ?? ''));
      if (!_isPhoneName(name, brand)) continue;
      final start = match.start;
      final end = (start + 2600).clamp(0, html.length);
      final prices = _extractPrices(html.substring(start, end));
      final product = _buildLandtopProduct(
        brand: brand,
        name: name,
        sourceUrl: Uri.parse(
          'https://www.landtop.com.tw',
        ).resolve(match.group(1) ?? '').toString(),
        suggestedPrice: prices.isNotEmpty ? prices.first : null,
        landtopPrice: prices.length > 1 ? prices[1] : null,
      );
      products[product.id] = product;
    }

    return products.values.toList();
  }

  List<PhoneCompareProduct> _parseJyesProducts(String text) {
    final products = <String, PhoneCompareProduct>{};
    final rows = text.split(RegExp(r'\r?\n'));

    for (final row in rows) {
      final columns = row
          .split('\t')
          .map(_normalizeName)
          .where((v) => v.isNotEmpty)
          .toList();
      if (columns.length < 3) continue;

      final rawName = columns.first;
      final brand = _inferBrand(rawName);
      if (brand == 'other') continue;

      final prices = columns.skip(1).map(_parsePrice).whereType<int>().toList();
      if (prices.isEmpty) continue;

      final name = _normalizeName(
        rawName
            .replaceFirst(RegExp(r'^三星', caseSensitive: false), 'Samsung')
            .replaceFirst(RegExp(r'^蘋果', caseSensitive: false), 'Apple'),
      );
      final price = prices.last;
      final id = 'jyes-${_slug(name)}';
      products[id] = PhoneCompareProduct(
        id: id,
        brand: brand,
        name: name,
        suggestedPrice: prices.first,
        landtopPrice: null,
        landtopPriceLabel: '未提供',
        sourceUrl: _buildJyesUrl(name),
        jyesPrice: price,
        jyesPriceLabel: _formatCurrency(price),
        jyesUrl: _buildJyesUrl(name),
      );
    }

    return products.values.toList();
  }

  List<PhoneCompareProduct> _mergeProducts(
    List<PhoneCompareProduct> landtopProducts,
    List<PhoneCompareProduct> jyesProducts,
  ) {
    final jyesByName = {
      for (final product in jyesProducts) _compareKey(product.name): product,
    };

    final merged = <PhoneCompareProduct>[];
    final usedJyesKeys = <String>{};

    for (final product in landtopProducts) {
      final key = _compareKey(product.name);
      final jyes = jyesByName[key];
      if (jyes != null) usedJyesKeys.add(key);
      merged.add(
        product.copyWith(
          jyesPrice: jyes?.jyesPrice,
          jyesPriceLabel: jyes?.jyesPriceLabel,
          jyesUrl: jyes?.jyesUrl,
        ),
      );
    }

    for (final product in jyesProducts) {
      if (!usedJyesKeys.contains(_compareKey(product.name))) {
        merged.add(product);
      }
    }

    return merged;
  }

  PhoneCompareProduct _buildLandtopProduct({
    required String brand,
    required String name,
    required String sourceUrl,
    required int? suggestedPrice,
    required int? landtopPrice,
  }) {
    return PhoneCompareProduct(
      id: '$brand-${_slug(name)}',
      brand: brand,
      name: name,
      suggestedPrice: suggestedPrice,
      landtopPrice: landtopPrice,
      landtopPriceLabel: landtopPrice == null
          ? '未提供'
          : _formatCurrency(landtopPrice),
      sourceUrl: sourceUrl,
    );
  }

  bool _matchesQuery(PhoneCompareProduct product, String query) {
    final tokens = _normalizeName(
      query,
    ).toLowerCase().split(' ').where((v) => v.isNotEmpty);
    if (tokens.isEmpty) {
      return true;
    }
    final haystack = '${product.brand} ${product.name}'.toLowerCase();
    return tokens.every(haystack.contains);
  }

  bool _isPhoneName(String name, String brand) {
    if (name.isEmpty || name.length > 140) {
      return false;
    }
    if (brand == 'samsung') {
      return RegExp(r'^Samsung\s+', caseSensitive: false).hasMatch(name);
    }
    return RegExp(
      r'^(iPhone|Apple\s+iPhone)',
      caseSensitive: false,
    ).hasMatch(name);
  }

  String _inferBrand(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('iphone') ||
        lower.contains('apple') ||
        value.contains('蘋果')) {
      return 'apple';
    }
    if (lower.contains('samsung') || value.contains('三星')) {
      return 'samsung';
    }
    return 'other';
  }

  List<int> _extractPrices(String value) {
    final matches =
        RegExp(r'(?:NT\$|\$|售價|價格|price)?\s*([\d,]{4,})', caseSensitive: false)
            .allMatches(_stripTags(value))
            .map((match) => _parsePrice(match.group(1) ?? ''))
            .whereType<int>()
            .where((price) => price >= 1000)
            .toList();
    return matches.toSet().toList();
  }

  int? _parsePrice(String value) {
    final raw = value.replaceAll(RegExp(r'[^\d]'), '');
    return raw.isEmpty ? null : int.tryParse(raw);
  }

  String _stripTags(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeName(String value) {
    return _stripTags(value)
        .replaceAll(RegExp(r'\b(\d{3,4})G\b', caseSensitive: false), r'$1GB')
        .replaceAll('/', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _compareKey(String value) {
    return _normalizeName(value)
        .toLowerCase()
        .replaceAll(RegExp(r'\[[^\]]+\]'), '')
        .replaceAll(RegExp(r'[()（）]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _slug(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _buildJyesUrl(String name) {
    final slug = name
        .replaceAll(RegExp(r'\b(\d{3,4})GB\b', caseSensitive: false), r'$1G')
        .replaceFirst(RegExp(r'^Samsung\s+', caseSensitive: false), 'SAMSUNG-')
        .replaceFirst(RegExp(r'^Apple\s+', caseSensitive: false), 'APPLE-')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^A-Za-z0-9-]'), '')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return 'https://www.jyes.com.tw/product/$slug';
  }

  String _brandLabel(String brand) => brand == 'apple' ? 'Apple' : 'Samsung';

  String _formatCurrency(int price) =>
      'NT\$ ${price.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';
}

class _PhoneSource {
  final String brand;
  final String url;

  const _PhoneSource({required this.brand, required this.url});
}
