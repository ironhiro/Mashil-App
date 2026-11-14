import 'package:geolocator/geolocator.dart';

enum PermissionState { granted, denied, deniedForever, serviceDisabled }

class LatLng {
  const LatLng(this.lat, this.lng, {this.accuracy});
  final double lat;
  final double lng;
  final double? accuracy;
}

/// 위치 권한과 현재 위치 (APP-02, APP-03). 백그라운드 위치는 쓰지 않는다 (STO-06).
class LocationService {
  Future<PermissionState> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return PermissionState.serviceDisabled;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return switch (p) {
      LocationPermission.always || LocationPermission.whileInUse => PermissionState.granted,
      LocationPermission.deniedForever => PermissionState.deniedForever,
      _ => PermissionState.denied,
    };
  }

  /// 시간 안에 못 잡으면 마지막으로 알려진 위치, 그것도 없으면 null.
  Future<LatLng?> currentPosition({Duration timeout = const Duration(seconds: 12)}) async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: timeout),
      );
      return LatLng(p.latitude, p.longitude, accuracy: p.accuracy);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      return last == null ? null : LatLng(last.latitude, last.longitude, accuracy: last.accuracy);
    }
  }

  /// "다시 묻지 않음" 상태에서 설정 앱으로 보낸다.
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
