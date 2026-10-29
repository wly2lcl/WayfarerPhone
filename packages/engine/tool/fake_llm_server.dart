// 假 LLM 服务（真机验证用）：全部走 OpenAI SSE 格式（网关 complete/stream 均流式）。
// 按提示词标记路由角色：分类器/导演/提取器秒回 JSON，其余（叙事/随行）慢速吐字，
// 给真机「停止生成」留出操作窗口。
// 用法：dart run tool/fake_llm_server.dart [port]
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 8899 : int.parse(args[0]);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('fake llm on :$port');
  await for (final req in server) {
    if (req.method == 'GET') {
      req.response.write('ok');
      await req.response.close();
      continue;
    }
    final body = await utf8.decoder.bind(req).join();
    try {
      await _handle(req, body);
    } catch (e) {
      stderr.writeln('err: $e');
      req.response.statusCode = 500;
      await req.response.close();
    }
  }
}

Future<void> _handle(HttpRequest req, String body) async {
  final json = body.isEmpty ? <String, dynamic>{} : jsonDecode(body) as Map;
  final messages = (json['messages'] as List?) ?? const [];
  final user = messages
      .map((m) => ((m as Map)['content'] ?? '').toString())
      .join('\n');
  stdout.writeln('${DateTime.now().second}s '
      '${req.method} ${req.uri.path} user=${user.length}ch');

  req.response.headers
      .set(HttpHeaders.contentTypeHeader, 'text/event-stream; charset=utf-8');

  Future<void> chunk(String content) async {
    final payload = jsonEncode({
      'choices': [
        {'delta': {'content': content}}
      ],
    });
    req.response.add(utf8.encode('data: $payload\n\n'));
    await req.response.flush();
  }

  if (user.contains('你的唯一任务是判断')) {
    // 分类器：一律 action，意图取玩家输入
    await chunk('{"kind":"action","intent":"四处看看"}');
  } else if (user.contains('你是这个世界的导演')) {
    await chunk(
        '{"beat":"daily","summary":"夜色山道，一段平稳的日常","npcActions":[],"reveals":["夜风渐凉"],"mood":"平静","nextChoices":[{"intent":"继续赶路","risk":"low"},{"intent":"寻一处避风处歇脚","risk":"low"}],"advanceTimeDays":1,"chapterEnd":null}');
  } else if (user.contains('提取')) {
    await chunk(
        '{"ops":[],"facts":["山道夜风渐凉"],"openThreads":[],"closeThreads":[],"choices":[{"intent":"继续赶路","label":"继续赶路"},{"intent":"寻一处避风处歇脚","label":"歇脚避风"}]}');
  } else {
    // 叙事/随行：首字立即，之后每 1s 一小段，共 40 段（约 40s 操作窗口）
    await chunk('夜色像一层湿布覆在山道上。');
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await chunk('夜风掠过林梢，远处隐约有钟声。');
    }
  }
  req.response.add(utf8.encode('data: [DONE]\n\n'));
  await req.response.close();
}
