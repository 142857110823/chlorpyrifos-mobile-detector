import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide BluetoothService;
import '../models/models.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import '../widgets/widgets.dart';

/// 设备连接页面
class DeviceConnectionScreen extends StatefulWidget {
  const DeviceConnectionScreen({super.key});

  @override
  State<DeviceConnectionScreen> createState() => _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends State<DeviceConnectionScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  final StorageService _storageService = StorageService();

  bool _isScanning = false;
  bool _isBluetoothOn = false;
  List<ScanResult> _realScanResults = [];
  List<MockDeviceInfo> _mockDevices = [];
  List<DeviceInfo> _savedDevices = [];

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _scanTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _checkBluetooth();
    _loadSavedDevices();
    _loadMockDevices();
  }

  @override
  void dispose() {
    _scanTimeoutTimer?.cancel();
    _bluetoothService.stopScan();
    _scanSubscription?.cancel();
    super.dispose();
  }

  void _loadMockDevices() {
    _mockDevices = _bluetoothService.getMockDevices();
  }

  Future<void> _checkBluetooth() async {
    final isOn = await _bluetoothService.isBluetoothOn();
    if (!mounted) return;

    setState(() => _isBluetoothOn = isOn);

    if (isOn && _bluetoothService.mode == BluetoothServiceMode.real) {
      _startScan();
    }
  }

  Future<void> _loadSavedDevices() async {
    final devices = await _storageService.getAllDevices();
    if (!mounted) return;

    setState(() => _savedDevices = devices);
  }

  void _startScan() async {
    if (_isScanning) return;
    if (_bluetoothService.mode == BluetoothServiceMode.mock) return;

    setState(() {
      _isScanning = true;
      _realScanResults = [];
    });

    _scanTimeoutTimer?.cancel();
    _scanSubscription?.cancel();
    _scanSubscription = _bluetoothService.scanDevices().listen((results) {
      if (!mounted) return;
      setState(() => _realScanResults = results);
    });

    _scanTimeoutTimer = Timer(AppConstants.bluetoothScanTimeout, () {
      if (!mounted) return;
      if (_isScanning) {
        _stopScan();
      }
    });
  }

  void _stopScan() {
    _scanTimeoutTimer?.cancel();
    _bluetoothService.stopScan();
    _scanSubscription?.cancel();
    if (!mounted) return;
    setState(() => _isScanning = false);
  }

  void _toggleMode() {
    final switchToReal = _bluetoothService.mode == BluetoothServiceMode.mock;

    if (!switchToReal) {
      _stopScan();
    }

    _bluetoothService.setMode(
      switchToReal ? BluetoothServiceMode.real : BluetoothServiceMode.mock,
    );

    if (!mounted) return;
    setState(() {});

    if (switchToReal) {
      _checkBluetooth();
    }
  }
  @override
  Widget build(BuildContext context) {
    final isMockMode = _bluetoothService.mode == BluetoothServiceMode.mock;

    return Scaffold(
      appBar: AppBar(
        title: const Text('连接设备'),
        actions: [
          // 模式切换按钮
          TextButton.icon(
            onPressed: _toggleMode,
            icon: Icon(
              isMockMode ? Icons.developer_mode : Icons.bluetooth,
              size: 18,
            ),
            label: Text(
              isMockMode ? '模拟' : '蓝牙',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (!isMockMode && _isScanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (!isMockMode)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isBluetoothOn ? _startScan : null,
            ),
        ],
      ),
      body: isMockMode
          ? _buildMockModeBody()
          : (!_isBluetoothOn ? _buildBluetoothOffState() : _buildRealModeBody()),
    );
  }

  /// Mock模式界面
  Widget _buildMockModeBody() {
    return ListView(
      children: [
        // Mock模式提示
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '当前为模拟模式，用于开发测试。点击右上角切换到真实蓝牙模式。',
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        _buildCurrentDevice(),
        _buildSavedDevices(),
        _buildMockDevices(),
      ],
    );
  }

  /// 真实蓝牙模式界面
  Widget _buildRealModeBody() {
    return ListView(
      children: [
        _buildCurrentDevice(),
        _buildSavedDevices(),
        _buildRealScanResults(),
      ],
    );
  }

  Widget _buildBluetoothOffState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bluetooth_disabled,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            '蓝牙已关闭',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '请打开蓝牙以搜索检测设备',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await _bluetoothService.turnOnBluetooth();
              await Future.delayed(const Duration(seconds: 1));
              _checkBluetooth();
            },
            icon: const Icon(Icons.bluetooth),
            label: const Text('打开蓝牙'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              _bluetoothService.setMode(BluetoothServiceMode.mock);
              setState(() {});
            },
            child: const Text('使用模拟模式'),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentDevice() {
    return StreamBuilder<DeviceConnectionState>(
      stream: _bluetoothService.connectionState,
      initialData: _bluetoothService.currentConnectionState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? DeviceConnectionState.disconnected;
        final deviceInfo = _bluetoothService.currentDeviceInfo;

        if (state == DeviceConnectionState.disconnected) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '当前连接',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
            DeviceCard(
              name: deviceInfo?.name ?? '未知设备',
              macAddress: deviceInfo?.macAddress,
              connectionState: state,
              onTap: () {
                if (state == DeviceConnectionState.connected) {
                  _showDisconnectDialog();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSavedDevices() {
    if (_savedDevices.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '已保存的设备',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        ..._savedDevices.map((device) => DeviceCard(
              name: device.name,
              macAddress: device.macAddress,
              connectionState: DeviceConnectionState.disconnected,
              isFavorite: device.isFavorite,
              onTap: () => _connectToSavedDevice(device),
              onFavoriteToggle: () => _toggleFavorite(device),
            )),
      ],
    );
  }

  /// 模拟设备列表
  Widget _buildMockDevices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '模拟设备',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        ..._mockDevices.map((device) => DeviceCard(
              name: device.name,
              macAddress: device.id,
              rssi: device.rssi,
              connectionState: DeviceConnectionState.disconnected,
              onTap: () => _connectToMockDevice(device),
            )),
        const SizedBox(height: 100),
      ],
    );
  }

  /// 真实蓝牙扫描结果
  Widget _buildRealScanResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '搜索到的设备',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              if (_isScanning)
                const Text(
                  '搜索中...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ),
        if (_realScanResults.isEmpty && !_isScanning)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.bluetooth_searching,
                    size: 48,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '未发现设备',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '请确保检测设备已开启并在附近',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          ..._realScanResults.map((result) => DeviceCard(
                name: result.device.platformName.isNotEmpty
                    ? result.device.platformName
                    : '未知设备',
                macAddress: result.device.remoteId.str,
                rssi: result.rssi,
                connectionState: DeviceConnectionState.disconnected,
                onTap: () => _connectToRealDevice(result.device),
              )),
        const SizedBox(height: 100),
      ],
    );
  }

  /// 连接真实蓝牙设备
  Future<void> _connectToRealDevice(BluetoothDevice device) async {
    _stopScan();

    Helpers.showLoadingDialog(context, message: '正在连接...');

    final success = await _bluetoothService.connectToRealDevice(device);

    if (!mounted) return;
    Helpers.hideLoadingDialog(context);

    if (success) {
      final deviceInfo = _bluetoothService.currentDeviceInfo;
      if (deviceInfo != null) {
        await _storageService.saveDeviceInfo(deviceInfo);
        await _loadSavedDevices();
      }

      if (!mounted) return;
      Helpers.showSnackBar(context, '连接成功');
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      Helpers.showSnackBar(context, '连接失败，请重试', isError: true);
    }
  }

  /// 连接模拟设备
  Future<void> _connectToMockDevice(MockDeviceInfo device) async {
    Helpers.showLoadingDialog(context, message: '正在连接...');

    final success = await _bluetoothService.connectToMockDevice(device);

    if (!mounted) return;
    Helpers.hideLoadingDialog(context);

    if (success) {
      final deviceInfo = _bluetoothService.currentDeviceInfo;
      if (deviceInfo != null) {
        await _storageService.saveDeviceInfo(deviceInfo);
        await _loadSavedDevices();
      }

      if (!mounted) return;
      Helpers.showSnackBar(context, '连接成功');
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      Helpers.showSnackBar(context, '连接失败，请重试', isError: true);
    }
  }

  Future<void> _connectToSavedDevice(DeviceInfo device) async {
    Helpers.showLoadingDialog(context, message: '正在连接...');

    final success = await _bluetoothService.connectToDeviceById(
      device.macAddress ?? device.id,
      device.name,
    );

    if (!mounted) return;
    Helpers.hideLoadingDialog(context);

    if (success) {
      Helpers.showSnackBar(context, '连接成功');
      Navigator.pop(context);
    } else {
      Helpers.showSnackBar(context, '连接失败，请重试', isError: true);
    }
  }

  Future<void> _toggleFavorite(DeviceInfo device) async {
    final updated = device.copyWith(isFavorite: !device.isFavorite);
    await _storageService.saveDeviceInfo(updated);
    await _loadSavedDevices();
  }

  void _showDisconnectDialog() async {
    final confirmed = await Helpers.showConfirmDialog(
      context,
      title: '断开连接',
      content: '确定要断开与当前设备的连接吗？',
    );

    if (confirmed) {
      await _bluetoothService.disconnect();
      if (!mounted) return;
      Helpers.showSnackBar(context, '已断开连接');
    }
  }
}
