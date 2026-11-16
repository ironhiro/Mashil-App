import 'package:flutter_test/flutter_test.dart';
import 'package:mashil/services/app_status.dart';

void main() {
  test('상태 응답을 읽는다 (빈 안내는 null, 시각은 기기 시간대로)', () {
    final s = AppStatus.fromJson({
      'maintenance': true,
      'readOnly': false,
      'message': '  ',
      'until': '2026-11-17T05:00:00+09:00',
    });
    expect(s.maintenance, isTrue);
    expect(s.message, isNull);
    expect(s.until, DateTime.parse('2026-11-16T20:00:00Z').toLocal());
  });

  test('점검 화면은 서버가 점검이라고 하거나, 상태를 모르는데 503 일 때만', () {
    const on = AppStatus(maintenance: true, message: '배포 중');
    const off = AppStatus(maintenance: false, readOnly: true);
    expect(AppStatus.maintenanceFor(on, 502), same(on));
    expect(AppStatus.maintenanceFor(off, 503), isNull); // 서버가 아니라고 하면 일반 오류 화면
    expect(AppStatus.maintenanceFor(null, 503), same(AppStatus.unavailable));
    expect(AppStatus.maintenanceFor(null, 500), isNull);
    expect(AppStatus.maintenanceFor(null, null), isNull); // 연결 자체 실패
  });
}
