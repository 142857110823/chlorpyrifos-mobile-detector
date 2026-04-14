import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';
import '../services/services.dart';
import '../utils/utils.dart';

/// 设置页面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storageService = StorageService();
  final CloudService _cloudService = CloudService();

  String _themeMode = 'system';
  bool _autoConnect = true;
  bool _cloudSync = false;
  bool _notification = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _themeMode = _storageService.getThemeMode();
      _autoConnect = _storageService.getSetting<bool>('autoConnect') ?? true;
      _cloudSync = _storageService.getSetting<bool>('cloudSync') ?? false;
      _notification = _storageService.getSetting<bool>('notification') ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          _buildSection(
            title: '外观',
            children: [
              _buildThemeTile(),
            ],
          ),
          _buildSection(
            title: '设备连接',
            children: [
              SwitchListTile(
                title: const Text('自动连接'),
                subtitle: const Text('启动时自动连接上次使用的设备'),
                value: _autoConnect,
                onChanged: (value) async {
                  await _storageService.saveSetting('autoConnect', value);
                  setState(() => _autoConnect = value);
                },
              ),
              ListTile(
                title: const Text('已保存的设备'),
                subtitle: const Text('管理已配对的检测设备'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pushNamed(context, RouteNames.deviceConnection);
                },
              ),
            ],
          ),
          _buildSection(
            title: '数据同步',
            children: [
              SwitchListTile(
                title: const Text('云端同步'),
                subtitle:
                    Text(_cloudService.isAuthenticated ? '已登录' : '登录后可同步数据'),
                value: _cloudSync,
                onChanged: _cloudService.isAuthenticated
                    ? (value) async {
                        await _storageService.saveSetting('cloudSync', value);
                        setState(() => _cloudSync = value);
                      }
                    : null,
              ),
              ListTile(
                title: Text(_cloudService.isAuthenticated ? '账户管理' : '登录'),
                subtitle: Text(
                    _cloudService.isAuthenticated ? '管理云端账户' : '登录以使用云端功能'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pushNamed(context, RouteNames.login);
                },
              ),
              ListTile(
                title: const Text('导出数据'),
                subtitle: const Text('将检测记录导出为文件'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showExportDialog,
              ),
            ],
          ),
          _buildSection(
            title: '通知',
            children: [
              SwitchListTile(
                title: const Text('消息通知'),
                subtitle: const Text('接收检测完成等通知'),
                value: _notification,
                onChanged: (value) async {
                  await _storageService.saveSetting('notification', value);
                  setState(() => _notification = value);
                },
              ),
            ],
          ),
          _buildSection(
            title: 'AI模型',
            children: [
              ListTile(
                title: const Text('模型版本'),
                subtitle: Text(
                    _storageService.getSetting<String>('modelVersion') ??
                        '1.0.0'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _checkModelUpdate,
              ),
            ],
          ),
          _buildSection(
            title: '其他',
            children: [
              ListTile(
                title: const Text('使用帮助'),
                leading: const Icon(Icons.help_outline),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showHelpDialog();
                },
              ),
              ListTile(
                title: const Text('意见反馈'),
                leading: const Icon(Icons.feedback_outlined),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showFeedbackDialog();
                },
              ),
              ListTile(
                title: const Text('关于'),
                leading: const Icon(Icons.info_outline),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showAboutDialog,
              ),
            ],
          ),
          _buildSection(
            title: '数据管理',
            children: [
              ListTile(
                title: const Text('清除缓存'),
                leading: const Icon(Icons.cached),
                onTap: () async {
                  final confirmed = await Helpers.showConfirmDialog(
                    context,
                    title: '清除缓存',
                    content: '确定要清除应用缓存吗？',
                  );
                  if (confirmed) {
                    await _storageService.clearCache();
                    if (!mounted) return;
                    Helpers.showSnackBar(context, '缓存已清除');
                  }
                },
              ),
              ListTile(
                title: const Text(
                  '清除所有数据',
                  style: TextStyle(color: Colors.red),
                ),
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                onTap: () async {
                  final confirmed = await Helpers.showConfirmDialog(
                    context,
                    title: '清除所有数据',
                    content: '确定要清除所有检测记录和设置吗？此操作不可撤销！',
                    isDangerous: true,
                  );
                  if (confirmed) {
                    await _storageService.clearAllData();
                    if (!mounted) return;
                    Helpers.showSnackBar(context, '所有数据已清除');
                    _loadSettings();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '${AppConstants.appName} v${AppConstants.appVersion}',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSection(
      {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }

  Widget _buildThemeTile() {
    return ListTile(
      title: const Text('主题模式'),
      subtitle: Text(_getThemeModeText()),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('选择主题'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('跟随系统'),
                  value: 'system',
                  groupValue: _themeMode,
                  onChanged: _updateThemeMode,
                ),
                RadioListTile<String>(
                  title: const Text('浅色模式'),
                  value: 'light',
                  groupValue: _themeMode,
                  onChanged: _updateThemeMode,
                ),
                RadioListTile<String>(
                  title: const Text('深色模式'),
                  value: 'dark',
                  groupValue: _themeMode,
                  onChanged: _updateThemeMode,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getThemeModeText() {
    switch (_themeMode) {
      case 'light':
        return '浅色模式';
      case 'dark':
        return '深色模式';
      default:
        return '跟随系统';
    }
  }

  void _updateThemeMode(String? value) async {
    if (value != null) {
      await context.read<AppProvider>().setThemeMode(value);
      if (!mounted) return;
      setState(() => _themeMode = value);
      Navigator.pop(context);
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出数据'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.description),
              title: Text('导出为JSON'),
              subtitle: Text('完整数据，可用于备份'),
            ),
            ListTile(
              leading: Icon(Icons.table_chart),
              title: Text('导出为CSV'),
              subtitle: Text('表格格式，可用于分析'),
            ),
            ListTile(
              leading: Icon(Icons.picture_as_pdf),
              title: Text('导出为PDF'),
              subtitle: Text('报告格式，可用于打印'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkModelUpdate() async {
    final modelUpdateService = ModelUpdateService();
    Helpers.showLoadingDialog(context, message: '检查更新中...');

    try {
      final currentVersion =
          _storageService.getSetting<String>('modelVersion') ?? '1.0.0';
      final modelInfo =
          await modelUpdateService.checkForUpdates(currentVersion);

      if (!mounted) return;
      Helpers.hideLoadingDialog(context);

      if (modelInfo != null) {
        final confirmed = await Helpers.showConfirmDialog(
          context,
          title: '发现新版本',
          content: '新版本 ${modelInfo.version} 可用\n\n大小：${modelInfo.size} MB',
          confirmText: '立即更新',
        );
        if (confirmed) {
          _downloadAndUpdateModel(modelUpdateService, modelInfo);
        }
      } else {
        Helpers.showSnackBar(context, '已是最新版本');
      }
    } catch (e) {
      if (!mounted) return;
      Helpers.hideLoadingDialog(context);
      Helpers.showSnackBar(context, '检查更新失败', isError: true);
    }
  }

  Future<void> _downloadAndUpdateModel(
      ModelUpdateService service, ModelInfo modelInfo) async {
    // 显示下载进度对话框
    late BuildContext dialogContext;
    bool dialogClosed = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        dialogContext = context;
        return StatefulBuilder(
          builder: (context, setState) {
            double progress = 0;
            String status = '准备下载...';

            // 开始下载和更新
            service.downloadAndUpdateModel(
              modelInfo,
              (updateStatus, value) {
                // 更新进度对话框
                setState(() {
                  progress = value;
                  switch (updateStatus) {
                    case ModelUpdateStatus.checking:
                      status = '检查更新中...';
                      break;
                    case ModelUpdateStatus.downloading:
                      status = '下载中...';
                      break;
                    case ModelUpdateStatus.verifying:
                      status = '验证模型中...';
                      break;
                    case ModelUpdateStatus.updating:
                      status = '更新模型中...';
                      break;
                    case ModelUpdateStatus.completed:
                      status = '更新完成！';
                      break;
                    case ModelUpdateStatus.error:
                      status = '更新失败';
                      break;
                    case ModelUpdateStatus.noUpdate:
                      status = '无更新';
                      break;
                  }
                });
              },
            ).then((updatedModel) async {
              // 关闭对话框
              if (!dialogClosed) {
                dialogClosed = true;
                Navigator.pop(dialogContext);
              }

              if (!mounted) return;

              if (updatedModel != null) {
                // 保存新模型版本
                await _storageService.saveSetting(
                    'modelVersion', modelInfo.version);
                if (!mounted) return;
                Helpers.showSnackBar(context, '模型更新成功！');
              } else {
                Helpers.showSnackBar(context, '模型更新失败', isError: true);
              }
            }).catchError((e) {
              // 关闭对话框
              if (!dialogClosed) {
                dialogClosed = true;
                Navigator.pop(dialogContext);
              }
              if (!mounted) return;
              Helpers.showSnackBar(context, '更新失败：$e', isError: true);
            });

            return AlertDialog(
              title: const Text('更新模型'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(status),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text('${(progress * 100).toStringAsFixed(0)}%'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('使用帮助'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('设备连接', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('1. 打开蓝牙并确保检测设备已开启'),
              Text('2. 在"设备连接"页面搜索并连接设备'),
              Text('3. 等待连接成功后即可开始检测'),
              SizedBox(height: 12),
              Text('开始检测', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('1. 确保设备已连接'),
              Text('2. 输入样品名称和类别'),
              Text('3. 将样品放置在检测区域'),
              Text('4. 点击"开始检测"按钮'),
              SizedBox(height: 12),
              Text('查看历史', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('在"历史"页面可查看所有检测记录，支持搜索、筛选和导出功能。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('意见反馈'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请描述您遇到的问题或建议：'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '请输入反馈内容...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Helpers.showSnackBar(context, '感谢您的反馈！');
            },
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: AppConstants.appVersion,
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppConstants.primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.science,
          size: 36,
          color: Colors.white,
        ),
      ),
      children: [
        const SizedBox(height: 16),
        const Text('基于多光谱技术的毒死蜱残留快速检测系统'),
        const SizedBox(height: 8),
        const Text(
          '大学生创新创业项目',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }
}
