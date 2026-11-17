import 'dart:convert';

import 'package:http/http.dart' as http;

/// `GET /api/app/status` 응답 (OPS-05). 웹이 뜨지 못했을 때 앱이 직접 점검 여부를 확인한다.
class AppStatus {
  const AppStatus({required this.maintenance, this.readOnly = false, this.message, this.until});

  final bool maintenance;
  final bool readOnly;

  /// 운영자가 남긴 안내. 비어 있으면 기본 문구
  final String? message;

  /// 다시 여는 시각 (모르면 null)
  final DateTime? until;

  /// 서버가 503 만 주고 상태를 알려 주지 못할 때: 점검으로 본다 (배포 중이거나 서버를 잠시 내린 경우)
  static const unavailable = AppStatus(maintenance: true);

  static AppStatus fromJson(Map<String, dynamic> j) {
    final message = (j['message'] as String?)?.trim();
    return AppStatus(
      maintenance: j['maintenance'] == true,
      readOnly: j['readOnly'] == true,
      message: (message == null || message.isEmpty) ? null : message,
      until: DateTime.tryParse(j['until'] as String? ?? '')?.toLocal(),
    );
  }

  /// 웹을 불러오지 못했을 때 점검 화면을 보여 줄지.
  /// [status] 상태 API 결과 (실패하면 null), [httpCode] 문서 요청의 HTTP 코드 (모르면 null).
  static AppStatus? maintenanceFor(AppStatus? status, int? httpCode) {
    if (status != null) return status.maintenance ? status : null;
    return httpCode == 503 ? unavailable : null;
  }
}

class AppStatusClient {
  AppStatusClient(this.apiBaseUrl, {http.Client? client}) : _client = client ?? http.Client();

  final Uri apiBaseUrl;
  final http.Client _client;

  /// 실패하면 null (서버가 아예 내려갔거나 네트워크 오류)
  Future<AppStatus?> fetch() async {
    try {
      final res = await _client
          .get(apiBaseUrl.resolve('/api/app/status'), headers: const {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;
      return AppStatus.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
