import 'package:contracts/contracts.dart';

class RejectedOp {
  final Op op;
  final String reason;
  RejectedOp(this.op, this.reason);
}

class ApplyResult {
  final List<RejectedOp> rejected;
  final List<String> applied;
  ApplyResult(this.rejected, this.applied);
}

final _flagKeyRe = RegExp(r'^[a-z][a-zA-Z0-9_]{0,31}$');
final _gameTimeRe = RegExp(r'^\d+-\d{1,2}-\d{1,2}$');

int _gameTimeValue(String s) {
  final m = _gameTimeRe.firstMatch(s);
  if (m == null) return -1;
  final parts = s.split('-');
  final y = int.parse(parts[0]);
  final mo = int.parse(parts[1]);
  final d = int.parse(parts[2]);
  return y * 10000 + mo * 100 + d;
}

String advanceGameTime(String current, double days) {
  final parts = current.split('-');
  final y = int.parse(parts[0]);
  final mo = int.parse(parts[1]);
  final d = int.parse(parts[2]);
  var total = d + days.floor();
  var month = mo, year = y;
  while (total > 30) {
    total -= 30;
    month++;
    if (month > 12) {
      month = 1;
      year++;
    }
  }
  final day = total < 1 ? 1 : total;
  return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

void _clampStats(Stats s) {
  s.vitality = s.vitality.clamp(0, 100);
  s.spirit = s.spirit.clamp(0, 100);
  s.body = s.body.clamp(0, 100);
}

/// 应用 StateDelta.ops 到状态快照，逐条容错（数据契约 §5）
ApplyResult applyOps(
  RunState state,
  List<Op> ops, {
  required WorldBible bible,
  required bool runEnded,
}) {
  final rejected = <RejectedOp>[];
  final applied = <String>[];

  void reject(Op op, String reason) => rejected.add(RejectedOp(op, reason));

  bool inRelation(String path, String leaf) {
    final parts = path.split('.');
    return parts.length == 3 && parts[0] == 'relations' && parts[2] == leaf;
  }

  bool inPills(String path) {
    final parts = path.split('.');
    return parts.length == 4 &&
        parts[0] == 'character' &&
        parts[1] == 'resources' &&
        parts[2] == 'pills';
  }

  bool inFlags(String path) {
    final parts = path.split('.');
    return parts.length == 2 && parts[0] == 'flags';
  }

  bool inReputation(String path) {
    final parts = path.split('.');
    return parts.length == 2 && parts[0] == 'reputation';
  }

  for (final op in ops) {
    final path = op.path;
    final kind = op.op;

    if (runEnded) {
      reject(op, 'run ended');
      continue;
    }

    // 引擎独占路径：一律丢弃（§5.2）
    const forbidden = {
      'schemaVersion',
      'meta.chapter',
      'meta.turnNo',
      'meta.lifespan',
      'character.identityId',
      'character.name',
      'flags.luck',
      'flags.heartDemon',
      'flags.pendingRepair',
    };
    if (forbidden.contains(path)) {
      reject(op, 'engine-owned path');
      continue;
    }

    switch (path) {
      case 'meta.gameTime':
        final v = asS(op.value);
        if (kind != 'set' || v == null || _gameTimeRe.firstMatch(v) == null) {
          reject(op, 'gameTime requires string set YYYY-MM-DD');
          break;
        }
        if (_gameTimeValue(v) <= _gameTimeValue(state.meta.gameTime)) {
          reject(op, 'gameTime must increase');
          break;
        }
        state.meta.gameTime = v;
        applied.add(path);
        break;
      case 'meta.age':
        final int cur = state.meta.age;
        final nv = kind == 'inc' ? cur + (op.by ?? 0) : asIOr(op.value, cur);
        state.meta.age = nv.clamp(0, state.meta.lifespan);
        applied.add(path);
        break;
      case 'character.realm.stage':
      case 'character.realm.stageName':
      case 'character.realm.layer':
      case 'character.realm.progress':
        _applyRealm(state, bible, op, kind, reject, applied);
        break;
      case 'character.stats.vitality':
      case 'character.stats.spirit':
      case 'character.stats.body':
        final leaf = path.split('.').last;
        final cur = switch (leaf) {
          'vitality' => state.character.stats.vitality,
          'spirit' => state.character.stats.spirit,
          _ => state.character.stats.body,
        };
        final nv = kind == 'inc' ? cur + (op.by ?? 0) : asIOr(op.value, cur);
        switch (leaf) {
          case 'vitality':
            state.character.stats.vitality = nv.clamp(0, 100);
          case 'spirit':
            state.character.stats.spirit = nv.clamp(0, 100);
          default:
            state.character.stats.body = nv.clamp(0, 100);
        }
        _clampStats(state.character.stats);
        applied.add(path);
        break;
      case 'character.resources.spiritStones':
        final cur = state.character.resources.spiritStones;
        final nv = kind == 'inc' ? cur + (op.by ?? 0) : asIOr(op.value, cur);
        state.character.resources.spiritStones = nv.clamp(0, 999999999);
        applied.add(path);
        break;
      case 'character.conditions':
        _applyConditions(state, op, kind, reject, applied);
        break;
      case 'location.regionId':
        final v = asS(op.value);
        if (kind != 'set' || v == null || bible.regionById(v) == null) {
          reject(op, 'unknown regionId');
          break;
        }
        state.location.regionId = v;
        state.location.placeId = bible.regionById(v)!.places.first.id;
        applied.add(path);
        break;
      case 'location.placeId':
        final v = asS(op.value);
        final region = bible.regionById(state.location.regionId);
        final belongs = region?.places.any((p) => p.id == v) ?? false;
        if (kind != 'set' || v == null || !belongs) {
          reject(op, 'placeId not in current region');
          break;
        }
        state.location.placeId = v;
        applied.add(path);
        break;
      case 'inventory':
        _applyInventory(state, op, kind, reject, applied);
        break;
      case 'knowledge':
        if (kind == 'push') {
          final v = asS(op.value);
          if (v == null || v.isEmpty) {
            reject(op, 'knowledge push needs string');
            break;
          }
          final trimmed = v.length > 80 ? v.substring(0, 80) : v;
          if (!state.knowledge.contains(trimmed)) {
            state.knowledge.add(trimmed);
            if (state.knowledge.length > 300) state.knowledge.removeAt(0);
          }
          applied.add(path);
        } else if (kind == 'remove') {
          state.knowledge.remove(asS(op.value) ?? '');
          applied.add(path);
        } else {
          reject(op, 'knowledge supports push/remove only');
        }
        break;
      case 'threads':
        _applyThreads(state, op, kind, reject, applied);
        break;
      default:
        if (inPills(path)) {
          final pillId = path.split('.').last;
          final cur = state.character.resources.pills[pillId] ?? 0;
          final nv = kind == 'inc' ? cur + (op.by ?? 0) : asIOr(op.value, cur);
          state.character.resources.pills[pillId] = nv.clamp(0, 999999);
          applied.add(path);
        } else if (inRelation(path, 'affinity')) {
          final npcId = path.split('.')[1];
          final rel = _ensureRelation(state, npcId);
          final nv = kind == 'inc'
              ? rel.affinity + (op.by ?? 0)
              : asIOr(op.value, rel.affinity);
          rel.affinity = nv.clamp(-100, 100);
          applied.add(path);
        } else if (inRelation(path, 'trust')) {
          final npcId = path.split('.')[1];
          final rel = _ensureRelation(state, npcId);
          final nv = kind == 'inc'
              ? rel.trust + (op.by ?? 0)
              : asIOr(op.value, rel.trust);
          rel.trust = nv.clamp(0, 100);
          applied.add(path);
        } else if (inRelation(path, 'status')) {
          final npcId = path.split('.')[1];
          final rel = _ensureRelation(state, npcId);
          rel.status = RelationStatusX.fromLabel(op.value);
          applied.add(path);
        } else if (inFlags(path)) {
          final key = path.split('.')[1];
          if (!_flagKeyRe.hasMatch(key)) {
            reject(op, 'bad flag key');
            break;
          }
          if (op.value is String && (op.value as String).length > 120) {
            op.value = (op.value as String).substring(0, 120);
          }
          final cur = state.flags[key];
          if (kind == 'inc' && cur is num) {
            state.flags[key] = (cur + (op.by ?? 0));
          } else if (kind == 'set' && (op.value is String || op.value is num || op.value is bool)) {
            state.flags[key] = op.value;
          } else {
            reject(op, 'flags supports set/inc of scalar');
            break;
          }
          if (state.flags.length > 200) {
            reject(op, 'flags full');
            state.flags.remove(key);
          }
          applied.add(path);
        } else if (inReputation(path)) {
          final facId = path.split('.')[1];
          if (bible.factions.every((f) => f.id != facId)) {
            reject(op, 'unknown factionId');
            break;
          }
          final cur = state.reputation[facId] ?? 0;
          final nv = kind == 'inc' ? cur + (op.by ?? 0) : asIOr(op.value, cur);
          state.reputation[facId] = nv.clamp(-100, 100);
          applied.add(path);
        } else {
          reject(op, 'path not in whitelist');
        }
    }
  }
  return ApplyResult(rejected, applied);
}

Relation _ensureRelation(RunState state, String npcId) {
  return state.relations.putIfAbsent(
    npcId,
    () => Relation(affinity: 0, trust: 20, status: RelationStatus.moSheng),
  );
}

void _applyRealm(
  RunState state,
  WorldBible bible,
  Op op,
  String kind,
  void Function(Op, String) reject,
  List<String> applied,
) {
  final path = op.path;
  final realm = state.character.realm;
  switch (path) {
    case 'character.realm.stage':
      final v = asI(op.value);
      final tier = v == null ? null : bible.tierByStage(v);
      if (kind != 'set' || tier == null) {
        reject(op, 'stage must set to a valid Tier.stage');
        break;
      }
      if (v! < realm.stage) {
        reject(op, 'stage can only rise');
        break;
      }
      if (v > realm.stage + 1) {
        reject(op, 'stage jump too large');
        break;
      }
      realm.stage = v;
      realm.stageName = tier.name;
      applied.add(path);
      break;
    case 'character.realm.stageName':
      final tier = bible.tierByName(asSOr(op.value, ''));
      if (kind != 'set' || tier == null || tier.stage != realm.stage) {
        reject(op, 'stageName must match current stage');
        break;
      }
      realm.stageName = tier.name;
      applied.add(path);
      break;
    case 'character.realm.layer':
      final tier = bible.tierByStage(realm.stage);
      final maxLayer = tier?.maxLayer ?? 1;
      final nv = kind == 'inc' ? realm.layer + (op.by ?? 0) : asIOr(op.value, realm.layer);
      if (nv < realm.layer) {
        reject(op, 'layer can only rise');
        break;
      }
      if (nv > maxLayer) {
        reject(op, 'layer beyond maxLayer');
        break;
      }
      realm.layer = nv;
      applied.add(path);
      break;
    case 'character.realm.progress':
      final nv = kind == 'inc' ? realm.progress + (op.by ?? 0) : asIOr(op.value, realm.progress);
      realm.progress = nv.clamp(0, 100);
      applied.add(path);
      break;
  }
}

void _applyConditions(
  RunState state,
  Op op,
  String kind,
  void Function(Op, String) reject,
  List<String> applied,
) {
  if (kind == 'push') {
    // 模型偶发把 value 写成字符串而非对象，非 Map 一律按缺对象拒绝
    final c = Condition.fromJson(op.value is Map ? op.value : null);
    if (c.id.isEmpty) {
      reject(op, 'condition push needs object');
      return;
    }
    state.character.conditions.removeWhere((e) => e.id == c.id);
    state.character.conditions.add(c);
    while (state.character.conditions.length > 10) {
      state.character.conditions.removeAt(0);
    }
    applied.add(op.path);
  } else if (kind == 'remove') {
    final id = asS(op.value) ?? '';
    state.character.conditions.removeWhere((e) => e.id == id);
    applied.add(op.path);
  } else {
    reject(op, 'conditions supports push/remove only');
  }
}

void _applyInventory(
  RunState state,
  Op op,
  String kind,
  void Function(Op, String) reject,
  List<String> applied,
) {
  if (kind == 'push') {
    final item = Item.fromJson(op.value is Map ? op.value : null);
    if (item.id.isEmpty || item.qty < 1) {
      reject(op, 'inventory push needs item');
      return;
    }
    final existing = state.inventory.where((e) => e.id == item.id).toList();
    if (existing.isEmpty) {
      if (state.inventory.length >= 100) {
        reject(op, 'inventory full');
        return;
      }
      state.inventory.add(item);
    } else {
      existing.first.qty += item.qty;
    }
    applied.add(op.path);
  } else if (kind == 'remove') {
    final id = asS(op.value) ?? '';
    state.inventory.removeWhere((e) => e.id == id);
    applied.add(op.path);
  } else {
    reject(op, 'inventory supports push/remove only');
  }
}

void _applyThreads(
  RunState state,
  Op op,
  String kind,
  void Function(Op, String) reject,
  List<String> applied,
) {
  if (kind == 'push') {
    final t = Thread.fromJson(op.value is Map ? op.value : null);
    if (t.id.isEmpty) {
      reject(op, 'thread push needs object');
      return;
    }
    state.threads.removeWhere((e) => e.id == t.id);
    t.status = 'open';
    t.createdAtTurn = state.meta.turnNo;
    state.threads.add(t);
    final openCount = state.threads.where((e) => e.status == 'open').length;
    if (openCount > 50) {
      reject(op, 'open threads full');
      state.threads.remove(t);
      return;
    }
    applied.add(op.path);
  } else if (kind == 'remove') {
    final id = asS(op.value) ?? '';
    for (final t in state.threads) {
      if (t.id == id) t.status = 'closed';
    }
    applied.add(op.path);
  } else {
    reject(op, 'threads supports push/remove only');
  }
}
