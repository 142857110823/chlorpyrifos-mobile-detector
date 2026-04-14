import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/providers.dart';
import 'screens/screens.dart';
import 'services/services.dart';
import 'utils/utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置状态栏样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // 设置屏幕方向
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    // 初始化存储服务
    await StorageService().init();

    // 初始化错误处理服务
    ErrorHandlingService().initialize();

    // 初始化性能监控服务
    PerformanceMonitorService().initialize();

    // 初始化安全服务
    await SecurityService().initialize();

    // 初始化日志服务
    await LoggingService().initialize();

    // 初始化光谱分析服务
    await SpectralAnalysisService().initialize();

    // 初始化全局状态管理器
    await AppStateManager().initialize();
  } catch (e, stackTrace) {
    print('服务初始化失败: $e');
    print(stackTrace);
  }

  // 添加应用生命周期监听器
  WidgetsBinding.instance.addObserver(
    _AppLifecycleObserver(),
  );

  runApp(const PesticideDetectorApp());
}

/// 应用生命周期观察者
class _AppLifecycleObserver with WidgetsBindingObserver {
  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.detached) {
      // 应用退出时释放资源
      await _disposeAllServices();
    }
  }

  /// 释放所有服务资源
  Future<void> _disposeAllServices() async {
    try {
      // 释放蓝牙服务资源
      BluetoothService().dispose();

      // 释放AI分析服务资源
      AIAnalysisService().dispose();

      // 释放光谱分析服务资源
      SpectralAnalysisService().dispose();

      // 释放全局状态管理器资源
      AppStateManager().dispose();

      // 释放存储服务资源
      await StorageService().close();

      print('所有服务资源已释放');
    } catch (e) {
      print('释放服务资源时出错: $e');
    }
  }
}

/// 毒死蜱检测应用主入口
class PesticideDetectorApp extends StatelessWidget {
  const PesticideDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateManager()..initialize()),
        ChangeNotifierProvider(create: (_) => AppProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => DetectionProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()..initialize()),
      ],
      child: Consumer<AppProvider>(
        builder: (context, appProvider, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,

            // 主题配置
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: _getThemeMode(appProvider.themeMode),

            // 路由配置
            initialRoute: RouteNames.splash,
            routes: {
              RouteNames.splash: (context) => const SplashScreen(),
              RouteNames.home: (context) => const MainNavigationScreen(),
              RouteNames.detection: (context) => const DetectionScreen(),
              RouteNames.history: (context) => const HistoryScreen(),
              RouteNames.settings: (context) => const SettingsScreen(),
              RouteNames.deviceConnection: (context) =>
                  const DeviceConnectionScreen(),
              RouteNames.login: (context) => const LoginScreen(),
              RouteNames.register: (context) => const RegisterScreen(),
              RouteNames.spectralImageDetection: (context) => const SpectralImageDetectionScreen(),
              RouteNames.imagePreview: (context) => const ImagePreviewScreen(imagePath: ''),
              RouteNames.result: (context) => const ResultScreen(results: []),
            },

            // 本地化配置
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [
              Locale('zh', 'CN'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          );
        },
      ),
    );
  }

  ThemeMode _getThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

/// 主导航页面（带底部导航栏）
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    DetectionScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.science_outlined),
            activeIcon: Icon(Icons.science),
            label: '检测',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: '历史',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
