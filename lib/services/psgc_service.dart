import 'dart:convert';
import 'package:http/http.dart' as http;

class PsgcPlace {
  final String code;
  final String name;
  const PsgcPlace(this.code, this.name);
}

/// Fetches cities/municipalities and barangays from the public PSGC API.
/// Results are cached in memory so each list is downloaded only once.
class PsgcService {
  static const String _base = 'https://psgc.gitlab.io/api';
  static final Map<String, List<PsgcPlace>> _cache = {};

  static Future<List<PsgcPlace>> getCitiesMunicipalities(
    String provinceCode,
  ) =>
      _fetch('$_base/provinces/$provinceCode/cities-municipalities.json');

  static Future<List<PsgcPlace>> getBarangays(String cityCode) =>
      _fetch('$_base/cities-municipalities/$cityCode/barangays.json');

  static Future<List<PsgcPlace>> _fetch(String url) async {
    final cached = _cache[url];
    if (cached != null) return cached;

    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('PSGC request failed (${response.statusCode})');
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    final list = data
        .map(
          (e) => PsgcPlace(
            e['code'] as String,
            (e['name'] as String).trim(),
          ),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    _cache[url] = list;
    return list;
  }
}
