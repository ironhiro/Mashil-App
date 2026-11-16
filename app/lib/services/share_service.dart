import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart' as kakao;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 공유할 화장실 한 곳.
class ShareRequest {
  const ShareRequest({required this.title, required this.url, this.description, this.address, this.buttonTitle});

  final String title;
  final Uri url;
  final String? description;

  /// 있으면 카카오톡 카드에 "위치 보기" 버튼이 붙는다 (카카오맵에서 이 주소를 연다).
  final String? address;

  /// 카카오톡 카드의 웹 열기 버튼 문구 (없으면 카카오 기본값 "자세히 보기").
  final String? buttonTitle;
}

/// 공유가 어떻게 끝났는지.
enum ShareOutcome {
  /// 카카오톡 앱으로 넘겼다
  kakaoTalk,

  /// 카카오톡이 없어 카카오 웹 공유 화면을 열었다
  kakaoWeb,

  /// 시스템 공유 창에서 대상을 골랐다
  shared,

  /// 시스템 공유 창을 닫았다
  dismissed,
}

/// 카카오톡 공유 (위치 템플릿)와 시스템 공유 창.
class ShareService {
  /// 카카오톡이 있으면 카카오톡으로, 없으면 카카오 웹 공유 화면(브라우저)으로.
  /// 링크 도메인은 카카오 콘솔의 웹 플랫폼 도메인에 등록돼 있어야 카드의 링크가 열린다.
  Future<ShareOutcome> kakaoTalk(ShareRequest r) async {
    final link = kakao.Link(webUrl: r.url, mobileWebUrl: r.url);
    final content = kakao.Content(title: r.title, description: r.description, link: link);
    final kakao.DefaultTemplate template = r.address != null && r.address!.isNotEmpty
        ? kakao.LocationTemplate(address: r.address!, addressTitle: r.title, content: content, buttonTitle: r.buttonTitle)
        : kakao.FeedTemplate(
            content: content,
            buttons: r.buttonTitle == null ? null : [kakao.Button(title: r.buttonTitle!, link: link)],
          );
    if (await kakao.ShareClient.instance.isKakaoTalkSharingAvailable()) {
      await kakao.ShareClient.instance.shareDefault(template: template);
      return ShareOutcome.kakaoTalk;
    }
    final web = await kakao.WebSharerClient.instance.makeDefaultUrl(template: template);
    // 카카오 로그인 뒤 친구·채팅방을 고르는 화면이라 앱 밖 브라우저로 연다
    if (!await launchUrl(web, mode: LaunchMode.externalApplication)) throw StateError('cannot open Kakao web sharer');
    return ShareOutcome.kakaoWeb;
  }

  /// 시스템 공유 창 (카카오톡, 메시지, 메일 …). 받는 앱이 링크를 알아보도록 글 끝에 주소를 붙인다.
  Future<ShareOutcome> system(ShareRequest r) async {
    final text = [r.title, if (r.description != null && r.description!.isNotEmpty) r.description, r.url.toString()].join('\n');
    final result = await SharePlus.instance.share(ShareParams(text: text, subject: r.title));
    return result.status == ShareResultStatus.dismissed ? ShareOutcome.dismissed : ShareOutcome.shared;
  }
}
