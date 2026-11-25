import 'package:JWHelper/features/notice/domain/notice_detail.dart';
import 'package:JWHelper/features/notice/domain/notice_item.dart';

/// 通知抓取失败的原因分类，界面据此给不同的补救入口。
enum NoticeErrorKind {
  /// 还没绑定统一认证账号，无法取到登录态。
  notConfigured,

  /// 有账号但登录失败（密码错、验证码、令牌失效）。
  authFailed,

  /// 网络不可达或超时。
  network,

  /// 拿到响应但不是 200，或跳到了意料之外的地址。
  http,

  /// 页面能打开但解析不出内容（多半是学校改版）。
  parse,
}

class NoticeException implements Exception {
  const NoticeException(this.kind, this.message);

  final NoticeErrorKind kind;
  final String message;

  @override
  String toString() => message;
}

/// 通知数据源。
///
/// 目前只有 [PubinfoNoticeSource] 一个实现。把抓取放在接口后面，是为了将来
/// 若接入服务端推送，只换实现、页面与状态层不动。
abstract class NoticeSource {
  /// 注入统一认证票据。每次抓取前都会调用一次，票据失效由调用方负责重取。
  void updateCredentials({
    required String userToken,
    required String ctTicket,
    required String appCtTicket,
  });

  /// 拉取第一页列表。
  Future<List<NoticeItem>> fetchList();

  /// 拉取单条通知的正文。
  Future<NoticeDetail> fetchDetail(NoticeItem item);
}
