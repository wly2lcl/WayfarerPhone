// 校验 docs/ 与 README 中的相对 Markdown 链接指向的文件存在（M0-01-01 产物）
// 用法：dart run tool/check_links.dart；有断链时 exit 1
import 'dart:io';

final _link = RegExp(r'\[[^\]]*\]\(([^)\s]+)\)');

void main() {
  final docs = Directory('docs');
  final files = <File>[
    if (docs.existsSync())
      ...docs
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md')),
    if (File('README.md').existsSync()) File('README.md'),
  ];
  var broken = 0;
  for (final f in files) {
    for (final m in _link.allMatches(f.readAsStringSync())) {
      final target = m.group(1)!;
      if (target.startsWith('http') ||
          target.startsWith('mailto:') ||
          target.startsWith('#')) {
        continue;
      }
      final path = target.split('#').first;
      if (path.isEmpty) continue;
      final resolved = '${f.parent.path}/$path';
      if (!File(resolved).existsSync() && !Directory(resolved).existsSync()) {
        stderr.writeln('${f.path}: 断链 -> $target');
        broken++;
      }
    }
  }
  stderr.writeln('检查 ${files.length} 个文件，断链 $broken 处');
  exit(broken == 0 ? 0 : 1);
}
