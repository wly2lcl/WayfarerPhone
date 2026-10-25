import 'package:engine/engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class DraftsNotifier extends AsyncNotifier<List<DraftView>> {
  @override
  Future<List<DraftView>> build() => ref.watch(engineProvider).drafts.list();
}

final draftsProvider =
    AsyncNotifierProvider<DraftsNotifier, List<DraftView>>(DraftsNotifier.new);

String draftStatusLabel(DraftStatus s) => switch (s) {
      DraftStatus.draft => '访谈中',
      DraftStatus.generating => '生成中',
      DraftStatus.review => '待审阅',
      DraftStatus.trial => '试玩中',
      DraftStatus.frozen => '已冻结',
    };

String sourceLabel(DraftSource s) => switch (s) {
      DraftSource.manual => '手动',
      DraftSource.dialogue => '对话共创',
      DraftSource.import => 'TXT 导入',
    };
