import 'dart:convert';

import 'package:http/http.dart' as http;

enum UpdateKind { none, recommended, required }

class VersionCheckResult {
  const VersionCheckResult(this.kind, {this.storeUrl, this.latest});
  final UpdateKind kind;
  final String? storeUrl;
  final String? latest;

  static const none = VersionCheckResult(UpdateKind.none);
}

/// 시작 시 `GET /api/app/version?platform=` (APP-09). 서버가 아직 없거나 실패하면 업데이트 안내 없이 진행한다.
/// 기대 응답: `{ "minimum": "1.0.0", "latest": "1.2.0", "storeUrl": "..." }`
class VersionChecker {
  VersionChecker(this.apiBaseUrl, {http.Client? client}) : _client = client ?? http.Client();

  final Uri apiBaseUrl;
  final http.Client _client;

  Future<VersionCheckResult> check(String platform, String current) async {
    try {
      final res = await _client
          .get(apiBaseUrl.resolve('/api/app/version?platform=$platform'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return VersionCheckResult.none;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return decide(current, json['minimum'] as String?, json['latest'] as String?, json['storeUrl'] as String?);
    } catch (_) {
      return VersionCheckResult.none;
    }
  }

  static VersionCheckResult decide(String current, String? minimum, String? latest, String? storeUrl) {
    if (minimum != null && compare(current, minimum) < 0) {
      return VersionCheckResult(UpdateKind.required, storeUrl: storeUrl, latest: latest);
    }
    if (latest != null && compare(current, latest) < 0) {
      return VersionCheckResult(UpdateKind.recommended, storeUrl: storeUrl, latest: latest);
    }
    return VersionCheckResult.none;
  }

  /// "1.2.10" 같은 점 구분 숫자 비교. 숫자가 아닌 꼬리(-beta, +3)는 무시.
  static int compare(String a, String b) {
    List<int> parts(String v) =>
        v.split(RegExp(r'[-+]')).first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final x = parts(a), y = parts(b);
    for (var i = 0; i < 3; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d.sign;
    }
    return 0;
  }
}
