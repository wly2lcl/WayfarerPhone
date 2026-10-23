import 'package:engine/engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class WorldsNotifier extends AsyncNotifier<List<WorldSummary>> {
  @override
  Future<List<WorldSummary>> build() => ref.watch(engineProvider).listWorlds();
}

final worldsProvider =
    AsyncNotifierProvider<WorldsNotifier, List<WorldSummary>>(WorldsNotifier.new);

WorldSummary? worldById(List<WorldSummary> worlds, String id) {
  for (final w in worlds) {
    if (w.id == id) return w;
  }
  return null;
}

String genreLabel(String genre) => switch (genre) {
      'xianxia' => '修真',
      'wuxia' => '武侠',
      'scifi' => '科幻',
      'fantasy' => '奇幻',
      _ => genre,
    };
