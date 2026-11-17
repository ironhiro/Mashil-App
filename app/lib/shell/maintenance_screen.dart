import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../services/app_status.dart';
import '../theme.dart';
import 'splash_gate.dart' show DoorPainter;

/// 웹이 뜨지 못했는데 서버가 점검 중일 때의 네이티브 점검 화면 (OPS-05, 07-ui-design "점검").
/// 웹의 MaintenanceScreen 과 같은 구성: 닫힌 문, "문이 잠시 닫혔어요", 다시 여는 시각 판, 다시 확인, 카카오맵 대안.
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({
    super.key,
    required this.status,
    required this.onRetry,
    required this.onOpenKakaoMap,
    this.retrying = false,
  });

  final AppStatus status;
  final VoidCallback onRetry;
  final VoidCallback onOpenKakaoMap;
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final c = MashilColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final until = status.until;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 시작 연출과 같은 문, 닫힌 상태
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox.square(
                      dimension: 88,
                      child: FittedBox(
                        child: CustomPaint(
                          size: const Size.square(DoorPainter.canvasDp),
                          painter: DoorPainter(open: 0, floor: 0, dark: dark),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(l.maintenanceTitle, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(status.message ?? l.maintenanceBody, style: t.bodyLarge?.copyWith(color: c.textMuted)),
                  if (until != null) ...[
                    const SizedBox(height: 16),
                    // 판: 잉크 테두리 안에 단위와 숫자
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(border: Border.all(color: c.text, width: 2)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.maintenanceUntil, style: t.labelMedium?.copyWith(color: c.textMuted)),
                          const SizedBox(height: 2),
                          Text(_formatUntil(context, until), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: retrying ? null : onRetry,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: Text(l.maintenanceRetry),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: onOpenKakaoMap,
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: Text(l.openKakaoMap),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 오늘이면 시각만, 아니면 날짜와 시각 (기기 언어로)
  static String _formatUntil(BuildContext context, DateTime until) {
    final m = MaterialLocalizations.of(context);
    final time = m.formatTimeOfDay(TimeOfDay.fromDateTime(until), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));
    final now = DateTime.now();
    final sameDay = now.year == until.year && now.month == until.month && now.day == until.day;
    return sameDay ? time : '${m.formatMediumDate(until)} $time';
  }
}
