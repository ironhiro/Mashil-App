import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

/// 네트워크 끊김 / 웹 로드 실패 시 네이티브 화면 (APP-06).
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key, required this.offline, required this.onRetry, this.detail});

  final bool offline;
  final VoidCallback onRetry;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded, size: 56, color: MashilColors.accent),
                const SizedBox(height: 16),
                Text(offline ? l.offlineTitle : l.loadFailedTitle, style: t.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  offline ? l.offlineBody : l.loadFailedBody,
                  style: t.bodyMedium?.copyWith(color: t.bodySmall?.color),
                  textAlign: TextAlign.center,
                ),
                // 기술 상세(예: connect (-6))는 개발 빌드에서만 — 사용자에게는 의미 없는 코드
                if (kDebugMode && detail != null) ...[
                  const SizedBox(height: 8),
                  Text(detail!, style: t.bodySmall, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 24),
                FilledButton(onPressed: onRetry, child: Text(l.retry)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
