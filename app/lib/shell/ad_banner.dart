import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:material_ui/material_ui.dart';

import '../services/ad_service.dart';
import '../theme.dart';

/// 웹뷰 아래에 붙는 고정 적응형 배너 (MON-01). 웹이 원하는 화면에서 광고가 실제로 뜬 동안에만 자리를 차지한다.
///
/// - 웹이 끄면([AdService.wanted] false) 광고를 버린다: 안 보이는 광고가 뒤에서 갱신·노출되지 않도록
/// - [hidden] 이면 잠깐 숨긴다 (키보드가 올라왔을 때, 오류·점검 화면). 이때는 광고를 버리지 않는다
/// - 웹 화면과 붙지 않게 위에 [gap] 만큼 띄우고 선을 긋는다 (실수로 누르는 배치는 AdMob 정책 위반)
/// - 시스템 제스처 막대 위에 놓는다 (배너가 보이는 동안 웹뷰는 막대에 닿지 않는다)
/// - 못 불러오면 [retryAfter] 뒤에 다시
class AdBanner extends StatefulWidget {
  const AdBanner({super.key, required this.ads, required this.onShownChanged, this.hidden = false});

  final AdService ads;

  /// 배너가 화면에 보이는지 바뀔 때. 웹에 하단 여백을 알리는 데 쓴다
  final ValueChanged<bool> onShownChanged;
  final bool hidden;

  static const gap = 8.0;
  static const retryAfter = Duration(seconds: 60);

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  /// 화면에 떠 있는 (불러오기를 마친) 광고
  BannerAd? _ad;

  /// 불러오는 중인 광고. 다 불러오면 [_ad] 와 바꾼다
  BannerAd? _pending;
  int? _width;
  Timer? _retry;
  bool _reportedShown = false;

  bool get _active => widget.ads.ready.value && widget.ads.wanted.value;

  @override
  void initState() {
    super.initState();
    widget.ads.ready.addListener(_sync);
    widget.ads.wanted.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면 폭이 바뀌면(회전 등) 그 폭에 맞는 크기로 다시 불러온다
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width != _width) {
      _width = width;
      if (_active) _load();
    }
  }

  @override
  void didUpdateWidget(AdBanner old) {
    super.didUpdateWidget(old);
    if (old.hidden != widget.hidden) _report();
  }

  /// 웹이 켜고 끈 것에 맞춘다
  void _sync() {
    if (!mounted) return;
    if (_active) {
      if (_ad == null && _pending == null) _load();
    } else {
      _drop();
    }
  }

  void _drop() {
    _retry?.cancel();
    _pending?.dispose();
    _pending = null;
    final old = _ad;
    if (old != null) {
      setState(() => _ad = null);
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    _report();
  }

  Future<void> _load() async {
    final width = _width;
    if (!_active || width == null || !mounted) return;
    _retry?.cancel();
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted || width != _width || !_active) return;
    _pending?.dispose();
    final next = _pending = BannerAd(
      adUnitId: widget.ads.bannerUnitId,
      size: size,
      request: AdService.request,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted || ad != _pending || !_active) {
            ad.dispose();
            if (ad == _pending) _pending = null;
            return;
          }
          final old = _ad;
          _pending = null;
          setState(() => _ad = ad as BannerAd);
          _report();
          // 새 광고가 그려진 뒤에 옛 광고를 버린다
          WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted || ad != _pending) return;
          debugPrint('ads: banner failed (${error.code} ${error.message})');
          _pending = null;
          // 떠 있던 광고가 있으면 그대로 두고, 없으면 자리를 비운 채 나중에 다시
          if (_ad == null) _retry = Timer(AdBanner.retryAfter, _sync);
        },
      ),
    );
    await next.load();
  }

  void _report() {
    final shown = _ad != null && !widget.hidden;
    if (shown == _reportedShown) return;
    _reportedShown = shown;
    widget.onShownChanged(shown);
  }

  @override
  void dispose() {
    widget.ads.ready.removeListener(_sync);
    widget.ads.wanted.removeListener(_sync);
    _retry?.cancel();
    _pending?.dispose();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    final c = MashilColors.of(context);
    return Visibility(
      visible: !widget.hidden,
      maintainState: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.bg,
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(top: AdBanner.gap),
            child: SizedBox(
              width: ad.size.width.toDouble(),
              height: ad.size.height.toDouble(),
              child: AdWidget(ad: ad),
            ),
          ),
        ),
      ),
    );
  }
}
