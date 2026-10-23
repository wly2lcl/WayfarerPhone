import 'dart:async';

/// 同一局同时只处理一个回合的进程内串行队列（技术方案 §1 硬约束 3）
class SerialQueue {
  final _locks = <String, Future<void>>{};

  Future<T> run<T>(String key, Future<T> Function() task) {
    final prev = _locks[key] ?? Future.value();
    final done = Completer<void>();
    _locks[key] = done.future;
    return prev.then((_) => task()).whenComplete(() {
      done.complete();
      if (identical(_locks[key], done.future)) {
        _locks.remove(key);
      }
    });
  }
}
