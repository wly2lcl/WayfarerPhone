import 'package:go_router/go_router.dart';

import '../features/archive/archive_page.dart';
import '../features/draw/draw_page.dart';
import '../features/library/runs_library_page.dart';
import '../features/play/play_page.dart';
import '../features/settings/settings_page.dart';
import '../features/worlds/world_detail_page.dart';
import '../features/worlds/worlds_page.dart';

/// 全局路由：
/// /                世界库（书架）
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
      path: '/world/:id',
      builder: (context, state) =>
          WorldDetailPage(worldId: state.pathParameters['id']!),
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
