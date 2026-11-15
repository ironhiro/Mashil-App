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

  /// 기기가 기억하는 마지막 위치. [maxAge] 보다 오래됐거나 없으면 null. 새로 재지 않으므로 바로 끝난다.
  Future<LatLng?> lastKnown({required Duration maxAge}) async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      if (p == null || DateTime.now().difference(p.timestamp) > maxAge) return null;
      return LatLng(p.latitude, p.longitude, accuracy: p.accuracy);
    } catch (_) {
      return null;
    }
  }

  /// 새로 잰다. [highAccuracy] 가 false 면 GPS 를 기다리지 않고 네트워크·융합 위치로 빨리 잡는다.
  /// 시간 안에 못 잡으면 마지막으로 알려진 위치, 그것도 없으면 null.
  Future<LatLng?> currentPosition({
    Duration timeout = const Duration(seconds: 12),
    bool highAccuracy = true,
  }) async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: highAccuracy ? LocationAccuracy.high : LocationAccuracy.medium,
          timeLimit: timeout,
        ),
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
