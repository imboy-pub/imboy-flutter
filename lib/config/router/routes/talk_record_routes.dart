/// 面聊记录（talk_record）路由（T10）。
///
/// 契约源：CONTRACT-FREEZE-T02 §3.5 —— goRouterProvider 分域 spread
/// 模式；本文件独立交付，**不注册进 app_router.dart**（主控制器归并时
/// 以 `...talkRecordRoutes(),` 挂载，见
/// modules/talk_record/presentation/talk_record_entry_tiles.dart 头部
/// 嵌入点说明）。页面直接导入（对齐 cs_workspace_routes.dart 先例，
/// 不经 pages_barrel）。
///
/// 路径清单：
/// - /talk_record                         → 列表（query: scope/
///   organization_id/organization_name/workspace_id/workspace_name）
/// - /talk_record/prepare                 → 新建准备（query 同上）
/// - /talk_record/save_location           → 保存位置
/// - /talk_record/detail/:id              → 详情（T16）
/// - /talk_record/detail/:id/segment/:segmentId → 片段校对（T16）
/// - /talk_record/detail/:id/speakers     → 发言人校对（T16）
/// - /talk_record/detail/:id/share        → 分享管理（T18）
/// - /talk_record/detail/:id/share/grant_edit → 编辑权限（T18；
///   query: grant_id 为空=新建授权，非空=编辑现有授权）
/// - /talk_record/detail/:id/export       → 导出文字（T21）
/// - /talk_record/detail/:id/transfer     → 责任移交（T21，企业 owner）
/// - /talk_record/detail/:id/cleanup      → 删除状态（T21；确认删除 →
///   已逻辑删除 + 清理状态独立展示）
/// - /talk_record/invalid                 → 通用失效页（T18；无权限/不
///   存在统一「暂时无法查看」，不泄露记录信息，供 403/404 复用）
library;

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_credentials.dart';
import 'package:imboy/modules/talk_record/presentation/ai/talk_record_ai_services_page.dart';
import 'package:imboy/modules/talk_record/presentation/ai/talk_record_ai_provider_page.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_list_page.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_prepare_page.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_save_location_page.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_detail_page.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_segment_edit_page.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_speakers_page.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_delete_page.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_export_page.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_transfer_page.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_grant_edit_page.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_invalid_view.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_manage_page.dart';

/// 面聊记录列表页路径。
const String kTalkRecordListPath = '/talk_record';

/// 新建准备页路径。
const String kTalkRecordPreparePath = '/talk_record/prepare';

const String kTalkRecordAiServicesPath = '/talk_record/ai_services';

/// 保存位置页路径。
const String kTalkRecordSaveLocationPath = '/talk_record/save_location';

/// 详情页路径前缀（详情/片段校对/发言人/分享共用前缀，T16/T18）。
const String kTalkRecordDetailPath = '/talk_record/detail';

/// 通用失效页路径（T18：无权限/不存在统一视图）。
const String kTalkRecordInvalidPath = '/talk_record/invalid';

/// 编辑权限子路由段（T18：`share/grant_edit`）。
const String kTalkRecordGrantEditSegment = 'grant_edit';

/// 结果域子路由段（T21：export / transfer / cleanup）。
const String kTalkRecordExportSegment = 'export';
const String kTalkRecordTransferSegment = 'transfer';
const String kTalkRecordCleanupSegment = 'cleanup';

/// 路由名。
const String kTalkRecordListRouteName = 'talk_record_list';
const String kTalkRecordPrepareRouteName = 'talk_record_prepare';
const String kTalkRecordSaveLocationRouteName = 'talk_record_save_location';
const String kTalkRecordDetailRouteName = 'talk_record_detail';
const String kTalkRecordSegmentEditRouteName = 'talk_record_segment_edit';
const String kTalkRecordSpeakersRouteName = 'talk_record_speakers';
const String kTalkRecordShareRouteName = 'talk_record_share';
const String kTalkRecordGrantEditRouteName = 'talk_record_grant_edit';
const String kTalkRecordInvalidRouteName = 'talk_record_invalid';
const String kTalkRecordExportRouteName = 'talk_record_export';
const String kTalkRecordTransferRouteName = 'talk_record_transfer';
const String kTalkRecordCleanupRouteName = 'talk_record_cleanup';

/// 面聊记录路由（未挂载进主 router；归并时 spread）。
List<RouteBase> talkRecordRoutes() => [
  GoRoute(
    path: kTalkRecordAiServicesPath,
    name: 'talk_record_ai_services',
    pageBuilder: (context, state) => CupertinoPage(
      key: state.pageKey,
      child: const TalkRecordAiServicesPage(),
    ),
    routes: [
      for (final provider in TalkRecordAiProvider.values)
        GoRoute(
          path: provider.name,
          name: 'talk_record_ai_${provider.name}',
          pageBuilder: (context, state) => CupertinoPage(
            key: state.pageKey,
            child: TalkRecordAiProviderPage(provider: provider),
          ),
        ),
    ],
  ),
  GoRoute(
    path: '/talk-records/:id',
    name: 'talk_record_card_locator',
    redirect: (_, state) {
      final id = state.pathParameters['id'] ?? '';
      return RegExp(r'^[0-9]+$').hasMatch(id)
          ? '$kTalkRecordDetailPath/$id'
          : kTalkRecordInvalidPath;
    },
  ),
  GoRoute(
    path: kTalkRecordListPath,
    name: kTalkRecordListRouteName,
    pageBuilder: (context, state) => CupertinoPage(
      key: state.pageKey,
      child: TalkRecordListPage(
        entryContext: TalkRecordEntryContext.fromQuery(
          state.uri.queryParameters,
        ),
      ),
    ),
  ),
  GoRoute(
    path: kTalkRecordPreparePath,
    name: kTalkRecordPrepareRouteName,
    pageBuilder: (context, state) => CupertinoPage(
      key: state.pageKey,
      child: TalkRecordPreparePage(
        entryContext: TalkRecordEntryContext.fromQuery(
          state.uri.queryParameters,
        ),
      ),
    ),
  ),
  GoRoute(
    path: kTalkRecordSaveLocationPath,
    name: kTalkRecordSaveLocationRouteName,
    pageBuilder: (context, state) => CupertinoPage(
      key: state.pageKey,
      child: TalkRecordSaveLocationPage(
        entryContext: TalkRecordEntryContext.fromQuery(
          state.uri.queryParameters,
        ),
      ),
    ),
  ),
  GoRoute(
    path: kTalkRecordInvalidPath,
    name: kTalkRecordInvalidRouteName,
    pageBuilder: (context, state) =>
        CupertinoPage(key: state.pageKey, child: const TalkRecordInvalidPage()),
  ),
  GoRoute(
    path: '$kTalkRecordDetailPath/:id',
    name: kTalkRecordDetailRouteName,
    pageBuilder: (context, state) => CupertinoPage(
      key: state.pageKey,
      child: TalkRecordDetailPage(recordId: state.pathParameters['id'] ?? ''),
    ),
    routes: [
      GoRoute(
        path: 'segment/:segmentId',
        name: kTalkRecordSegmentEditRouteName,
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: TalkRecordSegmentEditPage(
            recordId: state.pathParameters['id'] ?? '',
            segmentId: state.pathParameters['segmentId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: 'speakers',
        name: kTalkRecordSpeakersRouteName,
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: TalkRecordSpeakersPage(
            recordId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: 'share',
        name: kTalkRecordShareRouteName,
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: TalkRecordShareManagePage(
            recordId: state.pathParameters['id'] ?? '',
          ),
        ),
        routes: [
          GoRoute(
            path: kTalkRecordGrantEditSegment,
            name: kTalkRecordGrantEditRouteName,
            pageBuilder: (context, state) => CupertinoPage(
              key: state.pageKey,
              child: TalkRecordGrantEditPage(
                recordId: state.pathParameters['id'] ?? '',
                grantId: state.uri.queryParameters['grant_id'] ?? '',
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: kTalkRecordExportSegment,
        name: kTalkRecordExportRouteName,
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: TalkRecordExportPage(
            recordId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: kTalkRecordTransferSegment,
        name: kTalkRecordTransferRouteName,
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: TalkRecordTransferPage(
            recordId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: kTalkRecordCleanupSegment,
        name: kTalkRecordCleanupRouteName,
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: TalkRecordDeletePage(
            recordId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
    ],
  ),
];
