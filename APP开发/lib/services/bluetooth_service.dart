import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/device_info.dart';
import '../models/spectral_data.dart';
import 'error_handling_service.dart';

/// 蓝牙服务运行模式
enum BluetoothServiceMode {
  /// 真实蓝牙模式
  real,

  /// 模拟模式（用于开发和演示）
  mock,
}

/// 蓝牙服务类
/// 负责管理与多光谱检测设备的蓝牙连接和数据传输
class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  // 当前运行模式
  BluetoothServiceMode _mode = BluetoothServiceMode.mock;
  BluetoothServiceMode get mode => _mode;

  // 设备特征UUID
  static const String serviceUuid = '0000FFE0-0000-1000-8000-00805F9B34FB';
  static const String characteristicUuid =
      '0000FFE1-0000-1000-8000-00805F9B34FB';

  // 真实蓝牙相关
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _dataCharacteristic;
  StreamSubscription<List<int>>? _dataSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  // 自动重连相关
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int MAX_RECONNECT_ATTEMPTS = 5;

  // 设备状态监控
  Timer? _deviceStatusTimer;
  Map<String, dynamic> _deviceStatus = {};
  bool _manualDisconnect = false;
  bool _isDisposed = false;
  final List<BluetoothDevice> _cachedDevices = [];

  // Mock模式相关
  Timer? _mockDataTimer;
  bool _mockAcquiring = false;
  final Random _random = Random();

  // 状态流
  final _connectionStateController =
      StreamController<DeviceConnectionState>.broadcast();
  final _spectralDataController = StreamController<SpectralData>.broadcast();
  final _rawDataController = StreamController<List<int>>.broadcast();
  final _scanResultsController = StreamController<List<ScanResult>>.broadcast();
  final _deviceStatusController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<DeviceConnectionState> get connectionState =>
      _connectionStateController.stream;
  Stream<SpectralData> get spectralDataStream => _spectralDataController.stream;
  Stream<List<int>> get rawDataStream => _rawDataController.stream;
  Stream<List<ScanResult>> get scanResults => _scanResultsController.stream;
  Stream<Map<String, dynamic>> get deviceStatusStream =>
      _deviceStatusController.stream;

  DeviceConnectionState _currentState = DeviceConnectionState.disconnected;
  DeviceConnectionState get currentConnectionState => _currentState;

  DeviceInfo? _currentDeviceInfo;
  DeviceInfo? get currentDeviceInfo => _currentDeviceInfo;

  // 设备缓存
  /// ??????
  void setMode(BluetoothServiceMode mode) {
    if (_mode == mode) return;

    _mode = mode;
    _manualDisconnect = false;
    _reconnectTimer?.cancel();
    print('BluetoothService mode set to: $mode');
  }

  Future<bool> _checkBluetoothPermission() async {
    if (_mode == BluetoothServiceMode.mock) {
      return true;
    }

    // 检查位置权限（蓝牙扫描需要位置权限）
    final locationStatus = await Permission.location.status;
    if (locationStatus.isDenied) {
      final locationResult = await Permission.location.request();
      if (!locationResult.isGranted) {
        return false;
      }
    } else if (locationStatus.isPermanentlyDenied) {
      return false;
    }

    // 检查蓝牙权限
    final bluetoothStatus = await Permission.bluetooth.status;
    if (bluetoothStatus.isDenied) {
      final bluetoothResult = await Permission.bluetooth.request();
      if (!bluetoothResult.isGranted) {
        return false;
      }
    } else if (bluetoothStatus.isPermanentlyDenied) {
      return false;
    }

    // 检查蓝牙扫描权限（Android 12+）
    final bluetoothScanStatus = await Permission.bluetoothScan.status;
    if (bluetoothScanStatus.isDenied) {
      final bluetoothScanResult = await Permission.bluetoothScan.request();
      if (!bluetoothScanResult.isGranted) {
        return false;
      }
    } else if (bluetoothScanStatus.isPermanentlyDenied) {
      return false;
    }

    // 检查蓝牙连接权限（Android 12+）
    final bluetoothConnectStatus = await Permission.bluetoothConnect.status;
    if (bluetoothConnectStatus.isDenied) {
      final bluetoothConnectResult =
          await Permission.bluetoothConnect.request();
      if (!bluetoothConnectResult.isGranted) {
        return false;
      }
    } else if (bluetoothConnectStatus.isPermanentlyDenied) {
      return false;
    }

    return true;
  }

  /// 检查蓝牙是否可用
  Future<bool> isBluetoothAvailable() async {
    if (_mode == BluetoothServiceMode.mock) {
      return true;
    }

    // 检查蓝牙权限
    if (!await _checkBluetoothPermission()) {
      return false;
    }

    try {
      return await FlutterBluePlus.isSupported;
    } catch (e) {
      return false;
    }
  }

  /// 检查蓝牙是否开启
  Future<bool> isBluetoothOn() async {
    if (_mode == BluetoothServiceMode.mock) {
      return true;
    }

    // 检查蓝牙权限
    if (!await _checkBluetoothPermission()) {
      return false;
    }

    try {
      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (e) {
      return false;
    }
  }

  /// 请求打开蓝牙
  Future<void> turnOnBluetooth() async {
    if (_mode == BluetoothServiceMode.real) {
      // 检查蓝牙权限
      if (!await _checkBluetoothPermission()) {
        print('Bluetooth permission denied');
        return;
      }

      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        print('Error turning on Bluetooth: $e');
      }
    }
  }

  /// 扫描设备
  Stream<List<ScanResult>> scanDevices({
    Duration timeout = const Duration(seconds: 10),
  }) {
    if (_mode == BluetoothServiceMode.mock) {
      return _mockScanDevices(timeout);
    }
    return _realScanDevices(timeout);
  }

  /// 真实蓝牙扫描
  Stream<List<ScanResult>> _realScanDevices(Duration timeout) {
    // 检查蓝牙权限
    _checkBluetoothPermission().then((granted) {
      if (granted) {
        FlutterBluePlus.startScan(
          timeout: timeout,
          withServices: [Guid(serviceUuid)],
        );
      } else {
        print('Bluetooth permission denied, cannot start scan');
        // 发送空结果，避免UI阻塞
        Timer(Duration(milliseconds: 100), () {
          _scanResultsController.add([]);
        });
      }
    });
    return FlutterBluePlus.scanResults;
  }

  /// 模拟扫描
  Stream<List<ScanResult>> _mockScanDevices(Duration timeout) {
    // 模拟延迟后发送设备列表
    Timer(const Duration(milliseconds: 500), () {
      // 创建模拟的ScanResult需要真实的BluetoothDevice
      // 在Mock模式下，我们直接发送空列表，用户可以使用Mock连接
      _scanResultsController.add([]);
    });

    Timer(timeout, () {
      stopScan();
    });

    return _scanResultsController.stream;
  }

  /// 获取模拟设备列表
  List<MockDeviceInfo> getMockDevices() {
    return [
      MockDeviceInfo(
        id: 'MOCK_DEVICE_001',
        name: '多光谱检测仪 A1',
        rssi: -55,
      ),
      MockDeviceInfo(
        id: 'MOCK_DEVICE_002',
        name: '多光谱检测仪 B2',
        rssi: -68,
      ),
      MockDeviceInfo(
        id: 'MOCK_DEVICE_003',
        name: '农残检测设备 Pro',
        rssi: -72,
      ),
    ];
  }

  /// 停止扫描
  Future<void> stopScan() async {
    if (_mode == BluetoothServiceMode.real) {
      await FlutterBluePlus.stopScan();
    }
  }

  /// 连接真实蓝牙设备
  Future<bool> connectToRealDevice(BluetoothDevice device) async {
    return _connectToRealDevice(device, isReconnect: false);
  }

  Future<bool> _connectToRealDevice(
    BluetoothDevice device, {
    required bool isReconnect,
  }) async {
    return (await ErrorHandlingExtension.safeExecute<bool>(
          operation: () async {
            if (_mode != BluetoothServiceMode.real) {
              print('Cannot connect to real device in mock mode');
              return false;
            }

            if (!await _checkBluetoothPermission()) {
              print('Bluetooth permission denied, cannot connect to device');
              _updateConnectionState(DeviceConnectionState.error);
              return false;
            }

            _manualDisconnect = false;
            _reconnectTimer?.cancel();
            if (!isReconnect) {
              _reconnectAttempts = 0;
            }
            _updateConnectionState(DeviceConnectionState.connecting);

            if (!_cachedDevices
                .any((cached) => cached.remoteId.str == device.remoteId.str)) {
              _cachedDevices.add(device);
            }

            _connectionSubscription?.cancel();
            _connectionSubscription = device.connectionState.listen((state) {
              print('Device connection state changed: $state');
              if (state == BluetoothConnectionState.disconnected) {
                _handleDisconnection();
                if (!_manualDisconnect) {
                  _startReconnectAttempt(device);
                }
              } else if (state == BluetoothConnectionState.connected) {
                _manualDisconnect = false;
                _reconnectAttempts = 0;
                _startDeviceStatusMonitoring();
                _updateConnectionState(DeviceConnectionState.connected);
              }
            });

            await device.connect(
              timeout: const Duration(seconds: 15),
              autoConnect: false,
            );

            _connectedDevice = device;
            final services = await device.discoverServices();
            _dataCharacteristic = null;

            for (final service in services) {
              if (service.uuid.toString().toUpperCase().contains('FFE0')) {
                for (final char in service.characteristics) {
                  if (char.uuid.toString().toUpperCase().contains('FFE1')) {
                    _dataCharacteristic = char;
                    break;
                  }
                }
              }
              if (_dataCharacteristic != null) {
                break;
              }
            }

            if (_dataCharacteristic == null) {
              await device.disconnect();
              _updateConnectionState(DeviceConnectionState.error);
              return false;
            }

            await _dataCharacteristic!.setNotifyValue(true);
            _dataSubscription?.cancel();
            _dataSubscription = _dataCharacteristic!.onValueReceived.listen(
              _handleReceivedData,
              onError: (e) {
                ErrorHandlingService().reportError(
                  type: AppErrorType.bluetooth,
                  message: 'Data receive error: $e',
                  error: e,
                );
              },
            );

            _currentDeviceInfo = DeviceInfo(
              id: device.remoteId.str,
              name:
                  device.platformName.isNotEmpty ? device.platformName : '未知设备',
              macAddress: device.remoteId.str,
              lastConnectedAt: DateTime.now(),
            );

            _startDeviceStatusMonitoring();
            _updateConnectionState(DeviceConnectionState.connected);
            return true;
          },
          errorType: AppErrorType.bluetooth,
          errorMessage: 'Failed to connect to Bluetooth device',
          fallbackValue: false,
        )) ??
        false;
  }

  /// 连接模拟设备
  Future<bool> connectToMockDevice(MockDeviceInfo device) async {
    try {
      _manualDisconnect = false;
      _reconnectTimer?.cancel();
      _updateConnectionState(DeviceConnectionState.connecting);

      // 模拟连接延迟
      await Future.delayed(const Duration(seconds: 2));

      // 创建设备信息
      _currentDeviceInfo = DeviceInfo(
        id: device.id,
        name: device.name,
        macAddress: device.id,
        lastConnectedAt: DateTime.now(),
        batteryLevel: 85 + _random.nextInt(15),
        firmwareVersion: '2.1.0',
      );

      _updateConnectionState(DeviceConnectionState.connected);
      return true;
    } catch (e) {
      print('Mock connection error: $e');
      _updateConnectionState(DeviceConnectionState.error);
      return false;
    }
  }

  /// 通过设备ID连接（便捷方法）
  Future<bool> connectToDeviceById(String deviceId, String deviceName) async {
    if (_mode == BluetoothServiceMode.mock) {
      return connectToMockDevice(MockDeviceInfo(
        id: deviceId,
        name: deviceName,
      ));
    }

    final normalizedId = deviceId.toUpperCase();
    if (_connectedDevice?.remoteId.str.toUpperCase() == normalizedId) {
      _manualDisconnect = false;
      _updateConnectionState(DeviceConnectionState.connected);
      return true;
    }

    for (final cached in _cachedDevices) {
      if (cached.remoteId.str.toUpperCase() == normalizedId) {
        return _connectToRealDevice(cached, isReconnect: false);
      }
    }

    if (!await _checkBluetoothPermission()) {
      _updateConnectionState(DeviceConnectionState.error);
      return false;
    }

    StreamSubscription<List<ScanResult>>? subscription;

    try {
      _manualDisconnect = false;
      _updateConnectionState(DeviceConnectionState.connecting);
      final completer = Completer<BluetoothDevice?>();

      subscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final scannedId = result.device.remoteId.str.toUpperCase();
          final scannedName = result.device.platformName;
          if (scannedId == normalizedId ||
              (deviceName.isNotEmpty && scannedName == deviceName)) {
            if (!_cachedDevices.any(
              (cached) => cached.remoteId.str == result.device.remoteId.str,
            )) {
              _cachedDevices.add(result.device);
            }
            if (!completer.isCompleted) {
              completer.complete(result.device);
            }
            break;
          }
        }
      }, onError: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
        withServices: [Guid(serviceUuid)],
      );
      final found = await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => null,
      );

      await FlutterBluePlus.stopScan();
      await subscription.cancel();

      if (found == null) {
        _updateConnectionState(DeviceConnectionState.error);
        return false;
      }

      return _connectToRealDevice(found, isReconnect: false);
    } catch (e) {
      print('Failed to reconnect by device id: $e');
      _updateConnectionState(DeviceConnectionState.error);
      return false;
    } finally {
      await FlutterBluePlus.stopScan();
      await subscription?.cancel();
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    try {
      _manualDisconnect = true;
      _reconnectTimer?.cancel();
      _mockDataTimer?.cancel();
      _mockAcquiring = false;
      _dataSubscription?.cancel();
      _connectionSubscription?.cancel();

      if (_mode == BluetoothServiceMode.real && _connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
    } catch (e) {
      print('Disconnect error: $e');
    } finally {
      _handleDisconnection();
    }
  }

  /// 发送命令
  Future<bool> sendCommand(List<int> command) async {
    if (_mode == BluetoothServiceMode.mock) {
      // 模拟命令发送
      await Future.delayed(const Duration(milliseconds: 50));
      return true;
    }

    if (_dataCharacteristic == null) return false;

    try {
      await _dataCharacteristic!.write(command, withoutResponse: false);
      return true;
    } catch (e) {
      print('Send command error: $e');
      return false;
    }
  }

  /// 开始光谱采集
  Future<bool> startSpectralAcquisition() async {
    if (_currentState != DeviceConnectionState.connected) {
      return false;
    }

    if (_mode == BluetoothServiceMode.mock) {
      _mockAcquiring = true;
      _mockDataTimer?.cancel();
      _mockDataTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _generateMockSpectralData(),
      );
      return true;
    }

    // 发送开始采集命令
    return await sendCommand([0xAA, 0x01, 0x01, 0x55]);
  }

  /// 停止光谱采集
  Future<bool> stopSpectralAcquisition() async {
    if (_mode == BluetoothServiceMode.mock) {
      _mockAcquiring = false;
      _mockDataTimer?.cancel();
      return true;
    }

    // 发送停止采集命令
    return await sendCommand([0xAA, 0x01, 0x00, 0x55]);
  }

  /// 处理接收到的数据
  void _handleReceivedData(List<int> data) {
    if (_isDisposed) return;

    _rawDataController.add(data);
    final spectralData = _parseSpectralData(data);
    if (spectralData != null) {
      _spectralDataController.add(spectralData);
    }
  }

  /// 解析光谱数据
  SpectralData? _parseSpectralData(List<int> rawData) {
    try {
      if (rawData.length < 12) return null;
      if (rawData[0] != 0xAA || rawData.last != 0x55) return null;

      // 解析波长与强度
      final pointCount = (rawData[2] << 8) | rawData[3];
      final wavelengths = <double>[];
      final intensities = <double>[];

      for (var i = 0; i < pointCount; i++) {
        int offset = 4 + (i * 4);
        if (offset + 3 >= rawData.length) break;

        double wl = ((rawData[offset] << 8) | rawData[offset + 1]).toDouble();
        double its =
            ((rawData[offset + 2] << 8) | rawData[offset + 3]).toDouble();

        wavelengths.add(wl);
        intensities.add(its);
      }

      return SpectralData(
        id: 'SPEC_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        wavelengths: wavelengths,
        intensities: intensities,
        deviceId: _connectedDevice?.remoteId.str ??
            _currentDeviceInfo?.id ??
            'UNKNOWN',
      );
    } catch (e) {
      return null;
    }
  }

  /// 生成模拟光谱数据
  void _generateMockSpectralData() {
    if (!_mockAcquiring || _isDisposed) return;

    final wavelengths = <double>[];
    final intensities = <double>[];

    for (int i = 0; i < 256; i++) {
      double wavelength = 200.0 + i * 3.125;
      wavelengths.add(wavelength);
      double intensity = _generateMockIntensity(wavelength);
      intensities.add(intensity);
    }

    final spectralData = SpectralData(
      id: 'SPEC_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      wavelengths: wavelengths,
      intensities: intensities,
      deviceId: _currentDeviceInfo?.id ?? 'MOCK_DEV',
    );

    _spectralDataController.add(spectralData);
  }

  /// 生成模拟光谱数据 (公开接口)
  SpectralData generateMockSpectralData() {
    final wavelengths = <double>[];
    final intensities = <double>[];

    for (int i = 0; i < 256; i++) {
      double wavelength = 200.0 + i * 3.125;
      wavelengths.add(wavelength);
      double intensity = _generateMockIntensity(wavelength);
      intensities.add(intensity);
    }

    return SpectralData(
      id: 'SPEC_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      wavelengths: wavelengths,
      intensities: intensities,
      deviceId: _currentDeviceInfo?.id ?? 'MOCK_DEV',
    );
  }

  /// 生成模拟强度值（包含特征峰）
  double _generateMockIntensity(double wavelength) {
    double baseIntensity = 1000.0;

    // 添加基线漂移
    baseIntensity += 200 * sin(wavelength / 200);

    // 添加噪声
    baseIntensity += _random.nextDouble() * 50;

    // 添加特征峰（模拟农药残留特征）
    // 峰1：约450nm（蓝光区域）
    baseIntensity += 800 * exp(-pow(wavelength - 450, 2) / (2 * pow(30, 2)));

    // 峰2：约550nm（绿光区域）
    baseIntensity += 600 * exp(-pow(wavelength - 550, 2) / (2 * pow(25, 2)));

    // 峰3：约680nm（红光区域）
    baseIntensity += 1000 * exp(-pow(wavelength - 680, 2) / (2 * pow(35, 2)));

    // 峰4：约850nm（近红外区域）
    baseIntensity += 500 * exp(-pow(wavelength - 850, 2) / (2 * pow(40, 2)));

    // 随机添加农药特征峰（模拟不同浓度）
    if (_random.nextDouble() > 0.5) {
      baseIntensity += 300 * exp(-pow(wavelength - 520, 2) / (2 * pow(15, 2)));
    }
    if (_random.nextDouble() > 0.7) {
      baseIntensity += 250 * exp(-pow(wavelength - 620, 2) / (2 * pow(12, 2)));
    }

    return baseIntensity.clamp(0, 5000);
  }

  /// 更新连接状态
  void _updateConnectionState(DeviceConnectionState state) {
    if (_isDisposed || _currentState == state) return;

    _currentState = state;
    _connectionStateController.add(state);
  }

  /// 处理断开连接
  void _handleDisconnection() {
    _connectedDevice = null;
    _dataCharacteristic = null;
    _mockDataTimer?.cancel();
    _mockAcquiring = false;
    _deviceStatusTimer?.cancel();
    _dataSubscription?.cancel();
    _dataSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _updateConnectionState(DeviceConnectionState.disconnected);
  }

  /// 开始自动重连尝试
  void _startReconnectAttempt(BluetoothDevice device) {
    if (_manualDisconnect || _isDisposed) {
      return;
    }
    if (_reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
      print('Max reconnection attempts reached');
      _updateConnectionState(DeviceConnectionState.error);
      return;
    }

    _reconnectAttempts++;
    print(
        'Attempting to reconnect ($_reconnectAttempts/$MAX_RECONNECT_ATTEMPTS)...');

    _reconnectTimer?.cancel();
    _reconnectTimer =
        Timer(Duration(seconds: 3 * _reconnectAttempts), () async {
      try {
        print('Reconnecting to device...');
        await _connectToRealDevice(device, isReconnect: true);
      } catch (e) {
        print('Reconnection failed: $e');
      }
    });
  }

  /// 启动设备状态监控
  void _startDeviceStatusMonitoring() {
    _deviceStatusTimer?.cancel();
    final intervalSeconds = _reconnectAttempts > 0 ? 10 : 30;
    _deviceStatusTimer =
        Timer.periodic(Duration(seconds: intervalSeconds), (timer) {
      _updateDeviceStatus();
    });
  }

  /// 更新设备状态
  void _updateDeviceStatus() {
    if (_isDisposed || _currentDeviceInfo == null) return;

    final status = {
      'batteryLevel': _currentDeviceInfo?.batteryLevel ?? 0,
      'connectionTime': _currentDeviceInfo?.lastConnectedAt?.toString() ?? '',
      'signalStrength': _getSignalStrength(),
      'dataRate': _getDataRate(),
      'status': _currentState.toString(),
    };

    _deviceStatus = status;
    _deviceStatusController.add(status);
    print('Device status updated: $status');
  }

  /// 获取信号强度（模拟）
  int _getSignalStrength() {
    if (_mode == BluetoothServiceMode.mock) {
      return 70 + _random.nextInt(30);
    }
    return 80; // 实际设备需要通过BLE API获取
  }

  /// 获取数据速率（模拟）
  double _getDataRate() {
    if (_mode == BluetoothServiceMode.mock) {
      return 1.5 + _random.nextDouble() * 2.5;
    }
    return 2.0; // 实际设备需要通过统计数据计算
  }

  /// 获取设备状态
  Map<String, dynamic> get deviceStatus => _deviceStatus;

  /// 释放资源
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    _manualDisconnect = true;
    _mockDataTimer?.cancel();
    _reconnectTimer?.cancel();
    _deviceStatusTimer?.cancel();
    _dataSubscription?.cancel();
    _connectionSubscription?.cancel();
    _connectionStateController.close();
    _spectralDataController.close();
    _rawDataController.close();
    _scanResultsController.close();
    _deviceStatusController.close();
  }
}

/// 模拟设备信息
class MockDeviceInfo {
  final String id;
  final String name;
  final int rssi;

  MockDeviceInfo({
    required this.id,
    required this.name,
    this.rssi = -60,
  });
}
