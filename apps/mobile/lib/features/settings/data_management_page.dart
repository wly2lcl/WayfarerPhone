import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';

class DataManagementPage extends ConsumerStatefulWidget {
  const DataManagementPage({super.key});

  @override
  ConsumerState<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends ConsumerState<DataManagementPage> {
  bool _scheduling = false;

  Future<void> _requestReset() async {
    if (_scheduling) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空全部本机数据？'),
        content: const SingleChildScrollView(
          child: Text(
            '此操作不可恢复。请先导出需要保留的世界和存档。\n\n'
            '确认后请完全关闭应用再重开。下一次冷启动将删除存档、草稿、导入副本、导出与诊断缓存、反馈、日志、设置和 API Key，并重新显示隐私告知与年龄确认。内置世界将恢复。\n\n'
            '不会删除系统文件中另存的原件，无法撤回已经分享的文件或发送给模型服务商的数据。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认，重启后清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _scheduling = true);
    try {
      await ref.read(scheduleDataResetProvider)();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未能安排清理，数据尚未清除，请重试。')));
    } finally {
      if (mounted) setState(() => _scheduling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teen = ref.watch(teenModeProvider);
    return PopScope(
      canPop: !_scheduling,
      child: Scaffold(
        appBar: AppBar(title: const Text('数据管理')),
        body: AbsorbPointer(
          absorbing: _scheduling,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                '导出我的数据',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                '世界用 .world 包保存，单局用 .run 包保存，可通过系统分享面板另存。存档包包含正文、选择与状态，不包含 API Key。诊断包只用于排错，不能恢复存档。',
                style: TextStyle(height: 1.7),
              ),
              const SizedBox(height: 12),
              const Text('小说导入世界及其存档不可导出；内置世界只可导出存档。草稿需先冻结为世界，试玩局不支持导出。'),
              if (teen) ...[
                const SizedBox(height: 16),
                const Text('青少年模式下不可导出世界或存档。'),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: teen ? null : () => context.push('/manage'),
                child: const Text('管理并导出世界'),
              ),
              OutlinedButton(
                onPressed: teen ? null : () => context.push('/library'),
                child: const Text('导出或删除存档'),
              ),
              const SizedBox(height: 32),
              const Text(
                '清空全部数据',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                '仅清理本应用拥有的本机数据。为避免生成或导入任务写回，清理在完全关闭应用后的下一次启动执行；确认后当前会话将锁定。',
                style: TextStyle(height: 1.7),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _scheduling ? null : _requestReset,
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(_scheduling ? '正在安排……' : '清空全部数据'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
