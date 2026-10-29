import 'dart:convert';
import 'dart:io';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

const _fakeKey = 'sk-security-test-only';
const _secret = 'url-secret-test-only';
const _invalidUrls = <String, String>{
  '远程 HTTP': 'http://api.example.invalid/v1',
  'localhost 后缀': 'http://localhost.evil/v1',
  'localhost 子域': 'http://evil.localhost/v1',
  'localhost 尾点': 'http://localhost./v1',
  '10 私网': 'http://10.0.0.1/v1',
  '172 私网': 'http://172.16.0.1/v1',
  '192 私网': 'http://192.168.1.1/v1',
  '链路本地': 'http://169.254.169.254/v1',
  '非精确 IPv4 loopback': 'http://127.0.0.2/v1',
  'IPv4 缩写': 'http://127.1/v1',
  'IPv4 整数': 'http://2130706433/v1',
  'IPv4 十六进制': 'http://0x7f000001/v1',
  'IPv4 前导零': 'http://127.000.000.001/v1',
  'IPv4 映射 IPv6': 'http://[::ffff:127.0.0.1]/v1',
  'IPv6 非精确写法': 'http://[0:0:0:0:0:0:0:1]/v1',
  'IPv6 私网': 'http://[fd00::1]/v1',
  'IPv6 scope': 'http://[::1%25lo0]/v1',
  '编码 localhost': 'http://local%68ost/v1',
  '编码 IPv4': 'http://%31%32%37.0.0.1/v1',
  'HTTP 用户信息': 'http://user:$_secret@localhost/v1',
  'HTTPS 用户信息': 'https://user:$_secret@api.example.invalid/v1',
  '空用户信息': 'http://@localhost/v1',
  'HTTPS 空用户信息': 'https://@api.example.invalid/v1',
  '用户名伪装 host': 'http://localhost@evil.invalid/v1',
  '密码含非法端口': 'https://user:$_secret@localhost:not-a-port/v1',
  '空地址': '',
  '缺少 host': 'https:///v1',
  '空 authority': 'https://',
  '缺少双斜线': 'https:api.example.invalid/v1',
  '相对地址': '/v1',
  '相对 scheme': '//localhost/v1',
  'FTP scheme': 'ftp://localhost/v1',
  'WebSocket scheme': 'wss://localhost/v1',
  '不合法 scheme': '1https://localhost/v1',
  'JavaScript scheme': 'javascript:$_secret',
  '错误 IPv6': 'http://[::1/v1',
  '非数字端口': 'http://localhost:abc/v1',
  '端口越界': 'https://localhost:65536/v1',
  '零端口': 'http://localhost:0/v1',
  '前导空格': ' https://localhost/v1',
  'host 空格': 'https://local host/v1',
  'host 编码空格': 'https://local%20host/v1',
  '换行': 'https://localhost/\n$_secret',
  '反斜线': r'http://localhost\@evil.invalid/v1',
};

ModelSettings _settings(
  String url, [
  LlmProtocol protocol = LlmProtocol.openai_chat,
]) => ModelSettings(
  protocol: protocol,
  baseUrl: url,
  narrativeModel: 'fake-model',
  smallModel: 'fake-small-model',
);

GatewayRequest _request() => GatewayRequest(
  role: GatewayRole.narrator,
  system: 'local security test',
  user: 'ping',
  maxTokens: 8,
);

class _CountingKeyStore extends InMemoryKeyStore {
  int reads = 0;
  void Function()? onRead;

  @override
  Future<String?> read() {
    reads++;
    onRead?.call();
    return super.read();
  }
}

class _LocalHttpOverrides extends HttpOverrides {
  final ports = <int>{};
  final connections = <Uri>[];
  final clients = <HttpClient>[];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    clients.add(client);
    client.findProxy = (_) => 'DIRECT';
    client.connectionFactory = (uri, proxyHost, proxyPort) {
      connections.add(uri);
      if (!ports.contains(uri.port) ||
          !{'localhost', '127.0.0.1', '::1'}.contains(uri.host) ||
          proxyHost != null) {
        throw StateError('测试禁止非白名单 loopback 连接');
      }
      final address = uri.host == '::1'
          ? InternetAddress.loopbackIPv6
          : InternetAddress.loopbackIPv4;
      return Socket.startConnect(address, uri.port);
    };
    return client;
  }

  void close() {
    for (final client in clients) {
      client.close(force: true);
    }
  }
}

Future<void> _localOnly(
  Future<void> Function(_LocalHttpOverrides network) body,
) async {
  final network = _LocalHttpOverrides();
  await HttpOverrides.runWithHttpOverrides(() async {
    try {
      await body(network);
    } finally {
      network.close();
    }
  }, network);
}

Future<HttpServer> _server(
  _LocalHttpOverrides network, {
  bool ipv6 = false,
}) async {
  final server = await HttpServer.bind(
    ipv6 ? InternetAddress.loopbackIPv6 : InternetAddress.loopbackIPv4,
    0,
  );
  network.ports.add(server.port);
  addTearDown(() => server.close(force: true));
  return server;
}

Future<void> _respondOk(HttpRequest request, LlmProtocol protocol) async {
  await request.drain<void>();
  request.response.headers.contentType = ContentType(
    'text',
    'event-stream',
    charset: 'utf-8',
  );
  final frames = switch (protocol) {
    LlmProtocol.openai_chat =>
      'data: {"choices":[{"delta":{"content":"ok"}}]}\n\ndata: [DONE]\n\n',
    LlmProtocol.openai_responses =>
      'data: {"type":"response.output_text.delta","delta":"ok"}\n\n'
          'data: {"type":"response.completed"}\n\n',
    LlmProtocol.anthropic_messages =>
      'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"ok"}}\n\n'
          'data: {"type":"message_stop"}\n\n',
  };
  request.response.add(utf8.encode(frames));
  await request.response.close();
}

const _entrypoints = ['complete', 'stream', 'testConnection'];

TypeMatcher<EngineException> get _policyError => isA<EngineException>()
    .having((e) => e.code, 'code', EngineCode.modelNotConfigured)
    .having((e) => e.canRetry, 'canRetry', isFalse)
    .having((e) => e.details, 'details', isNull)
    .having(
      (e) => e.toString(),
      '脱敏错误',
      allOf(isNot(contains(_secret)), isNot(contains(_fakeKey))),
    );

Future<void> _expectBlocked(ModelGateway gateway, String entrypoint) async {
  switch (entrypoint) {
    case 'complete':
      await expectLater(gateway.complete(_request()), throwsA(_policyError));
    case 'stream':
      await expectLater(
        gateway.stream(_request()).toList(),
        throwsA(_policyError),
      );
    case 'testConnection':
      final report = await gateway.testConnection();
      expect(report.ok, isFalse);
      expect(report.errorCode, EngineCode.modelNotConfigured);
      expect(report.message, isNotEmpty);
      expect(report.message, isNot(contains(_secret)));
      expect(report.message, isNot(contains(_fakeKey)));
    default:
      fail('未知测试入口');
  }
}

Future<void> _expectOk(ModelGateway gateway, String entrypoint) async {
  switch (entrypoint) {
    case 'complete':
      expect((await gateway.complete(_request())).text, 'ok');
    case 'stream':
      expect((await gateway.stream(_request()).toList()).join(), 'ok');
    case 'testConnection':
      final report = await gateway.testConnection();
      expect(report.ok, isTrue);
      expect(report.message, 'ok');
    default:
      fail('未知测试入口');
  }
}

void main() {
  group('ModelSettings URL 策略', () {
    for (final url in [
      'https://api.example.invalid/v1',
      'https://api.example.invalid:8443/v1/',
      'HTTPS://API.EXAMPLE.INVALID/v1',
      'https://10.0.0.1/v1',
      'http://localhost:8080/v1',
      'http://LOCALHOST/v1',
      'http://127.0.0.1:8080/v1',
      'http://[::1]:8080/v1',
      'http://[::1]/v1',
    ]) {
      test('允许 $url（仅解析，不联网）', () {
        expect(ModelSettings.validateEndpointUrl(url), Uri.parse(url));
      });
    }

    for (final entry in _invalidUrls.entries) {
      test('拒绝 ${entry.key}，错误不回显 URL', () {
        expect(
          () => ModelSettings.validateEndpointUrl(entry.value),
          throwsA(
            _policyError.having(
              (e) => e.message,
              '修正提示',
              allOf(contains('HTTPS'), contains('localhost')),
            ),
          ),
        );
        try {
          ModelSettings.validateEndpointUrl(entry.value);
        } on EngineException catch (e) {
          if (entry.value.isNotEmpty) {
            expect(e.toString(), isNot(contains(entry.value)));
          }
        }
      });
    }
  });

  group('唯一 gateway 请求边界', () {
    for (final protocol in LlmProtocol.values) {
      for (final entrypoint in _entrypoints) {
        test(
          '$protocol $entrypoint 在读 Key / 连接前拒绝全部非法地址',
          () => _localOnly((network) async {
            final keys = _CountingKeyStore();
            await keys.write(_fakeKey);
            for (final url in _invalidUrls.values) {
              final usage = <UsageRecord>[];
              final gateway = ModelGateway(
                GatewayConfig(
                  settings: () => _settings(url, protocol),
                  keyStore: keys,
                  onUsage: usage.add,
                ),
              );
              await _expectBlocked(gateway, entrypoint);
              expect(keys.reads, 0, reason: url);
              expect(network.connections, isEmpty, reason: url);
              final recorded = entrypoint != 'testConnection' && url.isNotEmpty;
              expect(usage, hasLength(recorded ? 1 : 0), reason: '配置错误不得重试');
              expect(usage.every((record) => !record.ok), isTrue);
            }
          }),
        );
      }

      for (final host in ['localhost', '127.0.0.1', '[::1]']) {
        test(
          '$protocol $host 三个入口仍可调用 loopback mock',
          () => _localOnly((network) async {
            final server = await _server(network, ipv6: host == '[::1]');
            final paths = <String>[];
            final credentials = <String?>[];
            server.listen((request) async {
              paths.add(request.uri.path);
              credentials.add(
                request.headers.value(
                  protocol == LlmProtocol.anthropic_messages
                      ? 'x-api-key'
                      : 'authorization',
                ),
              );
              await _respondOk(request, protocol);
            });
            final keys = _CountingKeyStore();
            await keys.write(_fakeKey);
            final gateway = ModelGateway(
              GatewayConfig(
                settings: () =>
                    _settings('http://$host:${server.port}/v1', protocol),
                keyStore: keys,
              ),
            );
            for (final entrypoint in _entrypoints) {
              await _expectOk(gateway, entrypoint);
            }
            final path = switch (protocol) {
              LlmProtocol.openai_chat => '/v1/chat/completions',
              LlmProtocol.openai_responses => '/v1/responses',
              LlmProtocol.anthropic_messages => '/v1/messages',
            };
            expect(paths, [path, path, path]);
            final credential = protocol == LlmProtocol.anthropic_messages
                ? _fakeKey
                : 'Bearer $_fakeKey';
            expect(credentials, [credential, credential, credential]);
            expect(keys.reads, 3);
          }),
        );
      }

      for (final status in [301, 303]) {
        for (final entrypoint in _entrypoints) {
          test(
            '$protocol $entrypoint 拒绝 $status，Key 不转发',
            () => _localOnly((network) async {
              final source = await _server(network);
              final target = await _server(network);
              final targetKeys = <String?>[];
              var targetHits = 0;
              target.listen((request) async {
                targetHits++;
                targetKeys.add(request.headers.value('authorization'));
                targetKeys.add(request.headers.value('x-api-key'));
                await _respondOk(request, protocol);
              });
              final sourceKeys = <String?>[];
              late String location;
              source.listen((request) async {
                sourceKeys.add(
                  request.headers.value(
                    protocol == LlmProtocol.anthropic_messages
                        ? 'x-api-key'
                        : 'authorization',
                  ),
                );
                await request.drain<void>();
                request.response.statusCode = status;
                request.response.headers.set('location', location);
                request.response.write('不得回显 $_secret $location');
                await request.response.close();
              });
              final keys = _CountingKeyStore();
              await keys.write(_fakeKey);
              final destinations = [
                'http://localhost:${target.port}/stolen',
                'http://127.0.0.1:${target.port}/stolen',
                'http://user:$_secret@localhost:${target.port}/stolen',
                'http://localhost.evil/$_secret',
                'https://other.example.invalid/$_secret',
              ];
              for (final destination in destinations) {
                location = destination;
                final usage = <UsageRecord>[];
                final gateway = ModelGateway(
                  GatewayConfig(
                    settings: () => _settings(
                      'http://127.0.0.1:${source.port}/v1',
                      protocol,
                    ),
                    keyStore: keys,
                    onUsage: usage.add,
                  ),
                );
                await _expectBlocked(gateway, entrypoint);
                expect(
                  usage,
                  hasLength(entrypoint == 'testConnection' ? 0 : 1),
                );
              }
              expect(keys.reads, destinations.length);
              final credential = protocol == LlmProtocol.anthropic_messages
                  ? _fakeKey
                  : 'Bearer $_fakeKey';
              expect(sourceKeys, List.filled(destinations.length, credential));
              expect(targetHits, 0);
              expect(targetKeys, isEmpty);
              expect(network.connections, isNotEmpty);
              expect(
                network.connections.every(
                  (uri) => uri.host == '127.0.0.1' && uri.port == source.port,
                ),
                isTrue,
              );
            }),
          );
        }
      }
    }

    test(
      '读 Key 期间设置被修改，不改变已经校验的请求地址',
      () => _localOnly((network) async {
        final server = await _server(network);
        var hits = 0;
        server.listen((request) async {
          hits++;
          await _respondOk(request, LlmProtocol.openai_chat);
        });
        final settings = _settings('http://127.0.0.1:${server.port}/v1');
        final keys = _CountingKeyStore()
          ..onRead = () => settings.baseUrl = 'http://localhost.evil/v1';
        await keys.write(_fakeKey);
        final gateway = ModelGateway(
          GatewayConfig(settings: () => settings, keyStore: keys),
        );
        await _expectOk(gateway, 'complete');
        await _expectBlocked(gateway, 'complete');
        expect(hits, 1);
        expect(keys.reads, 1);
        expect(
          network.connections.every(
            (uri) => uri.host == '127.0.0.1' && uri.port == server.port,
          ),
          isTrue,
        );
      }),
    );
  });

  group('Engine 保存设置', () {
    test(
      '非法 URL 保存失败，内存和数据库配置保持原值',
      () => _localOnly((network) async {
        final tmp = await Directory.systemTemp.createTemp('wf_url_save');
        final keys = _CountingKeyStore();
        await keys.write(_fakeKey);
        final engine = await Engine.open(
          dbPath: '${tmp.path}/app.db',
          keyStore: keys,
        );
        addTearDown(() async {
          await engine.close();
          await tmp.delete(recursive: true);
        });
        final original = _settings('https://api.example.invalid/v1');
        await engine.saveModelSettings(original);
        for (final url in _invalidUrls.values) {
          await expectLater(
            engine.saveModelSettings(_settings(url)),
            throwsA(_policyError),
          );
          expect(engine.modelSettings, same(original));
          expect(
            (await engine.loadModelSettings()).toJson(),
            original.toJson(),
          );
        }
        await expectLater(
          engine.saveModelSettings(
            _settings('http://remote.invalid')
              ..narrativeModel = ''
              ..smallModel = '',
          ),
          throwsA(_policyError),
        );
        expect(keys.reads, 0);
        expect(network.connections, isEmpty);
      }),
    );

    test(
      '允许全空配置清空，重开后仍未配置且不读 Key',
      () => _localOnly((network) async {
        final tmp = await Directory.systemTemp.createTemp('wf_url_clear');
        final path = '${tmp.path}/app.db';
        final keys = _CountingKeyStore();
        await keys.write(_fakeKey);
        var engine = await Engine.open(dbPath: path, keyStore: keys);
        addTearDown(() async {
          await engine.close();
          await tmp.delete(recursive: true);
        });
        await engine.saveModelSettings(
          _settings('https://api.example.invalid/v1'),
        );
        final empty = ModelSettings.fromJson(null);
        await engine.saveModelSettings(empty);
        expect(engine.modelSettings.configured, isFalse);
        expect((await engine.loadModelSettings()).toJson(), empty.toJson());
        await engine.close();
        engine = await Engine.open(dbPath: path, keyStore: keys);
        expect(engine.modelSettings.toJson(), empty.toJson());
        for (final entrypoint in _entrypoints) {
          await _expectBlocked(engine.gateway, entrypoint);
        }
        expect(keys.reads, 0);
        expect(network.connections, isEmpty);
      }),
    );

    test(
      '历史数据库中的 HTTP 地址不能绕过 gateway 校验',
      () => _localOnly((network) async {
        final tmp = await Directory.systemTemp.createTemp('wf_url_legacy');
        final path = '${tmp.path}/app.db';
        final keys = _CountingKeyStore();
        await keys.write(_fakeKey);
        var engine = await Engine.open(dbPath: path, keyStore: keys);
        addTearDown(() async {
          await engine.close();
          await tmp.delete(recursive: true);
        });
        await engine.writeAppSetting(
          'model_settings',
          jsonEncode(_settings('http://remote.invalid/v1').toJson()),
        );
        await engine.close();
        engine = await Engine.open(dbPath: path, keyStore: keys);
        for (final entrypoint in _entrypoints) {
          await _expectBlocked(engine.gateway, entrypoint);
        }
        expect(await engine.db.select(engine.db.usageLog).get(), hasLength(2));
        expect(keys.reads, 0);
        expect(network.connections, isEmpty);
      }),
    );
  });
}
