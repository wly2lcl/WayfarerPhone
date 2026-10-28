import 'package:go_router/go_router.dart';

import '../features/archive/archive_page.dart';
import '../features/draw/draw_page.dart';
import '../features/library/runs_library_page.dart';
import '../features/play/play_page.dart';
import '../features/settings/settings_page.dart';
import '../features/worlds/manage_page.dart';
import '../features/worlds/world_detail_page.dart';
import '../features/worlds/worlds_page.dart';
import '../features/workshop/create_page.dart';
import '../features/workshop/editor_page.dart';
import '../features/workshop/import_page.dart';
import '../features/workshop/workshop_page.dart';

/// 全局路由：
/// /                  世界库（书架）
/// /workshop          世界工坊（草稿列表）
/// /workshop/create/:draftId  创作对话（访谈）
/// /workshop/edit/:draftId    编辑器（质量检查/试玩/冻结）
/// /world/:id       世界详情 + 进入
/// /draw/:worldId   身份抽取
/// /play/:runId     游玩页
/// /archive/:runId  人生档案
/// /settings        设置
/// /library         我的局
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const WorldsPage(),
    ),
    GoRoute(
      path: '/workshop',
      builder: (context, state) => const WorkshopPage(),
    ),
    GoRoute(
      path: '/workshop/create/:draftId',
      builder: (context, state) =>
          CreatePage(draftId: state.pathParameters['draftId']!),
    ),
    GoRoute(
      path: '/workshop/import',
      builder: (context, state) => const ImportWizardPage(),
    ),
    GoRoute(
      path: '/workshop/edit/:draftId',
      builder: (context, state) =>
          EditorPage(draftId: state.pathParameters['draftId']!),
    ),
    GoRoute(
      path: '/world/:id',
      builder: (context, state) =>
          WorldDetailPage(worldId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/manage',
      builder: (context, state) => const ManagePage(),
    ),
    GoRoute(
      path: '/draw/:worldId',
      builder: (context, state) =>
          DrawPage(worldId: state.pathParameters['worldId']!),
    ),
    GoRoute(
      path: '/play/:runId',
      builder: (context, state) =>
          PlayPage(runId: state.pathParameters['runId']!),
    ),
    GoRoute(
      path: '/archive/:runId',
      builder: (context, state) =>
          ArchivePage(runId: state.pathParameters['runId']!),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/library',
      builder: (context, state) => const RunsLibraryPage(),
    ),
  ],
);
