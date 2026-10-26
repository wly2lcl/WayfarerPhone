import 'dart:convert';

import 'package:contracts/contracts.dart';
import 'package:fast_gbk/fast_gbk.dart';

/// 导入档位（世界创造与导入 §4.6）：决定合成圣经时素材摘要的覆盖策略
enum ImportFidelity {
  /// 快速：截断取前 N（长篇后半部剧情不参与合成）
  fast,

  /// 标准：跨全书均匀采样（首尾必含，结局参与合成）
  standard,

  /// 忠实：全书分块摘要先压缩为卷级脉络再合成（多一次小模型调用）
  faithful;

  static ImportFidelity fromIndex(int? i) =>
      values[(i ?? 0).clamp(0, values.length - 1)];
}

/// 等距采样：n ≥ 长度原样返回；否则取 n 个均匀分布的下标（首尾必含）
List<T> sampleEvenly<T>(List<T> items, int n) {
  if (n >= items.length) return List.of(items);
  if (n <= 0) return const [];
  if (n == 1) return [items.first];
  final out = <T>[];
  for (var k = 0; k < n; k++) {
    out.add(items[((k * (items.length - 1)) / (n - 1)).round()]);
  }
  return out;
}

/// 导入实体（世界创造与导入 §4.3）
class ImportEntity {
  final String key;
  final String type; // character | place | faction | item | event
  final Set<String> aliases;
  int firstChapter;
  int firstOffset;
  int frequency;
  final Map<String, String> attributes;

  ImportEntity({
    required this.key,
    required this.type,
    Set<String>? aliases,
    this.firstChapter = 0,
    this.firstOffset = 0,
    this.frequency = 0,
    Map<String, String>? attributes,
  })  : aliases = aliases ?? {},
        attributes = attributes ?? {};

  Map<String, Object?> toJson() => {
        'key': key,
        'type': type,
        'aliases': aliases.toList(),
        'firstSeen': {'chapter': firstChapter, 'offset': firstOffset},
        'frequency': frequency,
        'attributes': attributes,
      };

  static ImportEntity fromJson(Object? j) {
    final m = rawMap(j);
    final seen = rawMap(m['firstSeen']);
    return ImportEntity(
      key: asSOr(m['key'], ''),
      type: asSOr(m['type'], 'character'),
      aliases: asList<String>(m['aliases'], (e) => asSOr(e, ''))
          .where((a) => a.isNotEmpty)
          .toSet(),
      firstChapter: asIOr(seen['chapter'], 0),
      firstOffset: asIOr(seen['offset'], 0),
      frequency: asIOr(m['frequency'], 0),
      attributes: {
        for (final e in rawMap(m['attributes']).entries)
          e.key: e.value?.toString() ?? '',
      },
    );
  }
}

/// 关系边：谁与谁、何种关系，从何时起
class ImportRelation {
  final String from;
  final String to;
  final String kind;
  final int chapter;

  ImportRelation({
    required this.from,
    required this.to,
    required this.kind,
    this.chapter = 0,
  });

  Map<String, Object?> toJson() =>
      {'from': from, 'to': to, 'kind': kind, 'chapter': chapter};

  static ImportRelation fromJson(Object? j) {
    final m = rawMap(j);
    return ImportRelation(
      from: asSOr(m['from'], ''),
      to: asSOr(m['to'], ''),
      kind: asSOr(m['kind'], '相关'),
      chapter: asIOr(m['chapter'], 0),
    );
  }
}

/// 时间线：大事件的先后
class ImportTimelinePoint {
  final int chapter;
  final String title;
  final String summary;

  ImportTimelinePoint({
    required this.chapter,
    required this.title,
    this.summary = '',
  });

  Map<String, Object?> toJson() =>
      {'chapter': chapter, 'title': title, 'summary': summary};

  static ImportTimelinePoint fromJson(Object? j) {
    final m = rawMap(j);
    return ImportTimelinePoint(
      chapter: asIOr(m['chapter'], 0),
      title: asSOr(m['title'], ''),
      summary: asSOr(m['summary'], ''),
    );
  }
}

/// 单块抽取产物
class ChunkExtraction {
  final List<ImportEntity> entities;
  final List<ImportRelation> relations;
  final List<ImportTimelinePoint> timeline;
  final String summary;

  const ChunkExtraction({
    required this.entities,
    required this.relations,
    required this.timeline,
    required this.summary,
  });

  Map<String, Object?> toJson() => {
        'entities': entities.map((e) => e.toJson()).toList(),
        'relations': relations.map((e) => e.toJson()).toList(),
        'timeline': timeline.map((e) => e.toJson()).toList(),
        'summary': summary,
      };

  static ChunkExtraction fromJson(Object? j) {
    final m = rawMap(j);
    return ChunkExtraction(
      entities: asListOfMaps<ImportEntity>(m['entities'], ImportEntity.fromJson),
      relations:
          asListOfMaps<ImportRelation>(m['relations'], ImportRelation.fromJson),
      timeline: asListOfMaps<ImportTimelinePoint>(
          m['timeline'], ImportTimelinePoint.fromJson),
      summary: asSOr(m['summary'], ''),
    );
  }
}

/// 任务统计（ImportJob.stats）
class ImportStats {
  final int chapters;
  final int chunks;
  final int entities;
  final int relations;

  const ImportStats({
    required this.chapters,
    required this.chunks,
    required this.entities,
    required this.relations,
  });

  Map<String, Object?> toJson() => {
        'chapters': chapters,
        'chunks': chunks,
        'entities': entities,
        'relations': relations,
      };

  static ImportStats fromJson(Object? j) {
    final m = rawMap(j);
    return ImportStats(
      chapters: asIOr(m['chapters'], 0),
      chunks: asIOr(m['chunks'], 0),
      entities: asIOr(m['entities'], 0),
      relations: asIOr(m['relations'], 0),
    );
  }

  String encode() => jsonEncode(toJson());

  static ImportStats? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return ImportStats.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}

/// 发给客户端的任务视图（导入向导轮询用）
class ImportJobView {
  final String id;
  final String? draftId;
  final String stage; // queued | parsing | extracting | merging | compressing | review | failed
  final int done;
  final int total;
  final ImportStats? stats;
  final String? error;
  final String sourcePath;
  final int updatedAt;

  /// 合成档位（快速/标准/忠实）
  final ImportFidelity fidelity;

  /// 归并出的实体总数（审阅前基准，采纳率 = 现存 / 此值）
  final int entitiesTotal;

  ImportJobView({
    required this.id,
    this.draftId,
    required this.stage,
    required this.done,
    required this.total,
    this.stats,
    this.error,
    required this.sourcePath,
    required this.updatedAt,
    this.fidelity = ImportFidelity.fast,
    this.entitiesTotal = 0,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        if (draftId != null) 'draftId': draftId,
        'stage': stage,
        'done': done,
        'total': total,
        if (stats != null) 'stats': stats!.toJson(),
        if (error != null) 'error': error,
        'sourcePath': sourcePath,
        'updatedAt': updatedAt,
        'fidelity': fidelity.name,
        'entitiesTotal': entitiesTotal,
      };
}

/// 分块结果（纯函数，可进 Isolate）
class NovelChunk {
  final int idx;
  final int chapter;
  final String text;
  const NovelChunk({required this.idx, required this.chapter, required this.text});
}

/// UTF-8 / GBK 自动探测；两种都无法解码抛 FormatException
String decodeNovelBytes(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    // fall through to GBK
  }
  return gbk.decode(bytes);
}

/// 解码 + 检测章节数 + 分块（3000 字 / 重叠 400）
({List<NovelChunk> chunks, int chapters}) decodeAndChunk(List<int> bytes) {
  final text = decodeNovelBytes(bytes);
  // 章节头必须位于行首（允许全角/半角空格缩进）；正文行中提及「第N章」不计入
  final chapterRe = RegExp(r'^[ \t\u3000]*第[0-9〇零一二三四五六七八九十百千万]+[章节卷回]',
      multiLine: true);
  final headers = chapterRe
      .allMatches(text)
      .map((m) => m.start)
      .toList()
    ..sort();
  final step = 3000 - 400;
  final chunks = <NovelChunk>[];
  var i = 0;
  var idx = 0;
  while (i < text.length) {
    final end = (i + 3000).clamp(0, text.length);
    final body = text.substring(i, end);
    // 本块覆盖范围内出现的章节头计数 → 块所属章节
    var chapter = 0;
    for (final pos in headers) {
      if (pos <= i) chapter++;
      if (pos > i) break;
    }
    if (body.trim().isNotEmpty) {
      chunks.add(NovelChunk(idx: idx, chapter: chapter, text: body));
      idx++;
    }
    if (end >= text.length) break;
    i += step;
  }
  return (chunks: chunks, chapters: headers.isEmpty ? 1 : headers.length);
}

/// 归并：名称归一（key/别名互认）+ 频次累加 + 关系端点归一去重
({List<ImportEntity> entities, List<ImportRelation> relations,
        List<ImportTimelinePoint> timeline})
    mergeExtractions(List<ChunkExtraction> parts) {
  final byKey = <String, ImportEntity>{};
  final aliasToKey = <String, String>{};
  void register(ImportEntity e) {
    byKey[e.key] = e;
    aliasToKey[e.key] = e.key;
    for (final a in e.aliases) {
      aliasToKey[a] = e.key;
    }
  }

  ImportEntity? resolve(String name) {
    final k = aliasToKey[name.trim()];
    return k == null ? null : byKey[k];
  }

  // 第一遍：全量注册实体（关系端点解析必须在全部实体注册之后，
  // 否则关系先于实体出现在后续块里会被误丢）
  for (final part in parts) {
    for (final raw in part.entities) {
      final name = raw.key.trim();
      if (name.isEmpty) continue;
      // 本体名或任一别名命中已存在实体 → 归并进先出现者；否则新注册
      var existing = resolve(name);
      if (existing == null) {
        for (final a in raw.aliases) {
          final e = resolve(a);
          if (e != null) {
            existing = e;
            break;
          }
        }
      }
      if (existing == null) {
        register(ImportEntity(
          key: name,
          type: raw.type,
          aliases: {...raw.aliases},
          firstChapter: raw.firstChapter,
          firstOffset: raw.firstOffset,
          frequency: raw.frequency <= 0 ? 1 : raw.frequency,
          attributes: Map.of(raw.attributes),
        ));
      } else {
        existing.frequency += raw.frequency <= 0 ? 1 : raw.frequency;
        existing.aliases.addAll(raw.aliases);
        if (raw.firstChapter > 0 &&
            (existing.firstChapter == 0 ||
                raw.firstChapter < existing.firstChapter ||
                (raw.firstChapter == existing.firstChapter &&
                    raw.firstOffset < existing.firstOffset))) {
          existing.firstChapter = raw.firstChapter;
          existing.firstOffset = raw.firstOffset;
        }
        for (final e in raw.attributes.entries) {
          existing.attributes.putIfAbsent(e.key, () => e.value);
        }
        // 本块用别名指称该实体 → 收进别名表
        if (name != existing.key) existing.aliases.add(name);
      }
    }
  }

  final relSeen = <String, ImportRelation>{};
  for (final part in parts) {
    for (final r in part.relations) {
      final from = resolve(r.from)?.key ?? r.from.trim();
      final to = resolve(r.to)?.key ?? r.to.trim();
      if (from.isEmpty || to.isEmpty || from == to) continue;
      if (!byKey.containsKey(from) || !byKey.containsKey(to)) continue;
      final key = '$from|$to|${r.kind}';
      relSeen.putIfAbsent(
        key,
        () => ImportRelation(
            from: from, to: to, kind: r.kind, chapter: r.chapter),
      );
    }
  }

  final timelineSeen = <String, ImportTimelinePoint>{};
  for (final part in parts) {
    for (final t in part.timeline) {
      if (t.title.trim().isEmpty) continue;
      timelineSeen.putIfAbsent(
        '${t.chapter}|${t.title.trim()}',
        () => ImportTimelinePoint(
            chapter: t.chapter, title: t.title.trim(), summary: t.summary),
      );
    }
  }

  final entities = byKey.values.toList()
    ..sort((a, b) => b.frequency.compareTo(a.frequency));
  return (
    entities: entities,
    relations: relSeen.values.toList(),
    timeline: timelineSeen.values.toList()
      ..sort((a, b) => a.chapter.compareTo(b.chapter)),
  );
}

/// 质量门槛 §4.4：主要人物覆盖率——出现频次前 20 的角色名（含别名）出现在圣经里的比例
double characterCoverage(
    List<ImportEntity> entities, Object? bible) {
  final chars = entities.where((e) => e.type == 'character').toList();
  if (chars.isEmpty) return 1;
  final top = chars.take(20).toList();
  final bibleJson = jsonEncode(bible is Map ? bible : (bible as dynamic).toJson());
  var hit = 0;
  for (final c in top) {
    if (bibleJson.contains(c.key) ||
        c.aliases.any((a) => a.isNotEmpty && bibleJson.contains(a))) {
      hit++;
    }
  }
  return hit / top.length;
}
