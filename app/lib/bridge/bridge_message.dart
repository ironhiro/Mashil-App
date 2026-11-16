import 'dart:convert';

/// 웹 → 앱 메시지: `MashilBridge.postMessage(JSON.stringify({requestId, method, params}))`.
class BridgeMessage {
  const BridgeMessage({required this.requestId, required this.method, required this.params});

  final String requestId;
  final String method;
  final Map<String, dynamic> params;

  /// 형식이 틀리면 null (응답할 requestId 가 없으므로 무시한다).
  static BridgeMessage? tryParse(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final id = json['requestId'];
      final method = json['method'];
      if (id is! String || id.isEmpty || method is! String || method.isEmpty) return null;
      final params = json['params'];
      return BridgeMessage(
        requestId: id,
        method: method,
        params: params is Map<String, dynamic> ? params : const {},
      );
    } on FormatException {
      return null;
    }
  }
}

/// 앱 → 웹 응답 스크립트: `window.__mashilBridgeReply(requestId, result)`.
/// JSON 은 JS 리터럴로 그대로 쓸 수 있지만 U+2028/2029 는 옛 엔진에서 줄바꿈으로 읽히므로 이스케이프한다.
String bridgeReplyScript(String requestId, Map<String, Object?> result) =>
    'window.__mashilBridgeReply && window.__mashilBridgeReply(${_jsLiteral(requestId)}, ${_jsLiteral(result)});';

/// \uc571 \u2192 \uc6f9 \uc774\ubca4\ud2b8 \uc2a4\ud06c\ub9bd\ud2b8 (\uc694\uccad \uc5c6\uc774 \uc571\uc774 \uba3c\uc800 \ubcf4\ub0b4\ub294 \uac83, \uc608: watchLocation \uc758 \uc704\uce58):
/// `window.__mashilBridgeEvent(name, data)`.
String bridgeEventScript(String name, Map<String, Object?> data) =>
    'window.__mashilBridgeEvent && window.__mashilBridgeEvent(${_jsLiteral(name)}, ${_jsLiteral(data)});';

String _jsLiteral(Object? v) => jsonEncode(v)
    .replaceAll(String.fromCharCode(0x2028), r'\u2028')
    .replaceAll(String.fromCharCode(0x2029), r'\u2029');
