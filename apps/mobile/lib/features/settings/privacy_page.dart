import 'package:flutter/material.dart';

const privacyNoticeVersion = '2026-10-29.1';

const privacySections = <(String, String)>[
  (
    '本机存储',
    '远行没有账号、社区或自建云端存档。世界、草稿、小说副本、存档正文、选择、用量和反馈保存在应用的本机存储中；API Key 存在系统安全存储中。应用不自动上传统计或反馈。',
  ),
  (
    '模型请求会发送什么',
    '生成剧情、共创世界、随行问答及小说导入需要联网。相关输入、世界设定、角色状态、近期正文与记忆会发送到你在设置中选择的模型服务商；小说导入会逐块发送原文，并发送摘要和抽取结果。测试连接也会向该服务商发出请求。API Key 随请求用于鉴权。请勿输入无权提供的作品、个人敏感信息或第三方秘密。',
  ),
  (
    '第三方服务与费用',
    '请求由设备直连你配置的服务地址，远行不代持 Key、不代收模型费用。服务商可能位于境外，其保存期限、训练用途和数据处理规则由其政策决定，不能由本应用保证。使用前请核实服务商与地址，并自行承担模型调用费用。清除本机 Key 不会撤销服务商上的凭据。',
  ),
  (
    '导出与反馈',
    '世界包和存档包通过系统分享面板由你主动发出。存档包含正文、选择与状态；诊断包含模型配置、用量、反馈原文和近期事件，不主动读取 API Key，不自动附带完整剧情。反馈中手动写入的敏感内容可能随包导出，请先检查。反馈只记录在本机，不代表开发者已收到；当前测试版尚未配置官方支持渠道。',
  ),
  (
    '数据管理与留存',
    '用量记录保留 90 天，本地事件保留 7 天，诊断文件默认保留最近 5 份，清理在启动或导出时执行。可删除单局、世界或诊断文件；设置中的“清空全部数据”需确认并完全关闭后重开，在冷启动时删除本机存档、草稿、导入副本、导出缓存、配置、反馈、日志和 Key，然后恢复内置世界。清理失败会阻止进入应用并允许重试。已另存、已分享或服务商已收到的数据无法由本机清理撤回。',
  ),
  (
    '版权与未成年人',
    '仅导入你创作或获授权的作品。小说导入世界及其存档不可导出；内置世界仅可导出存档，青少年模式关闭世界及存档导入导出、自由输入和随行问答。AI 内容可能有误，并含虚构的死亡及暴力后果描写，不构成现实建议。未成年人请在监护人指导下使用。',
  ),
  (
    '测试版说明',
    '以上是当前版本的数据处理事实与使用须知。发行主体、正式联系方式、用户协议及适用法律条款仍待发布前确认，本告知不表示应用已完成法务审核或取得商店上架资质。',
  ),
];

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key, this.onAccept, this.onDecline});

  final Future<void> Function()? onAccept;
  final VoidCallback? onDecline;

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  bool _agreed = false;
  bool _saving = false;
  String? _error;

  Future<void> _accept() async {
    if (!_agreed || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onAccept!();
    } catch (_) {
      if (mounted) setState(() => _error = '无法保存确认，请重试。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隐私与使用须知')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Text(
              '数据告知版本 $privacyNoticeVersion',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 16),
            const Text(
              '本机保存，不等于模型请求不外发。',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            for (final section in privacySections) ...[
              const SizedBox(height: 24),
              Text(
                section.$1,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                section.$2,
                style: const TextStyle(fontSize: 14, height: 1.7),
              ),
            ],
            if (widget.onAccept != null) ...[
              const SizedBox(height: 24),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _agreed,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _agreed = value!),
                title: const Text('我已阅读，并知悉生成与导入会向自选模型服务发送相关内容。'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_error != null) Text(_error!),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _agreed && !_saving ? _accept : null,
                child: Text(_saving ? '正在保存……' : '同意并继续'),
              ),
              TextButton(
                onPressed: _saving ? null : widget.onDecline,
                child: const Text('不同意，暂不使用'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
