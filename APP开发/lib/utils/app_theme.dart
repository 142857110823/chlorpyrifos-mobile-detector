import 'package:flutter/material.dart';
import 'constants.dart';

/// 应用主题配置
class AppTheme {
  /// 亮色主题
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: _lightColorScheme,
    scaffoldBackgroundColor: _lightColorScheme.background,
    appBarTheme: _appBarTheme,
    cardTheme: _cardTheme,
    buttonTheme: _buttonTheme,
    textTheme: _lightTextTheme,
    inputDecorationTheme: _inputDecorationTheme,
    elevatedButtonTheme: _elevatedButtonTheme,
    outlinedButtonTheme: _outlinedButtonTheme,
    textButtonTheme: _textButtonTheme,
    bottomNavigationBarTheme: _bottomNavigationBarTheme,
    tabBarTheme: _tabBarTheme,
    dividerTheme: _dividerTheme,
    progressIndicatorTheme: _progressIndicatorTheme,
  );

  /// 暗色主题
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: _darkColorScheme,
    scaffoldBackgroundColor: _darkColorScheme.background,
    appBarTheme: _appBarTheme.copyWith(
      backgroundColor: _darkColorScheme.surface,
      foregroundColor: _darkColorScheme.onSurface,
    ),
    cardTheme: _cardTheme.copyWith(
      color: _darkColorScheme.surfaceVariant,
    ),
    buttonTheme: _buttonTheme,
    textTheme: _darkTextTheme,
    inputDecorationTheme: _inputDecorationTheme.copyWith(
      fillColor: _darkColorScheme.surfaceVariant,
      hintStyle: TextStyle(color: _darkColorScheme.onSurfaceVariant),
    ),
    elevatedButtonTheme: _elevatedButtonTheme,
    outlinedButtonTheme: _outlinedButtonTheme,
    textButtonTheme: _textButtonTheme,
    bottomNavigationBarTheme: _bottomNavigationBarTheme.copyWith(
      backgroundColor: _darkColorScheme.surface,
      selectedItemColor: _darkColorScheme.primary,
      unselectedItemColor: _darkColorScheme.onSurfaceVariant,
    ),
    tabBarTheme: _tabBarTheme,
    dividerTheme: _dividerTheme,
    progressIndicatorTheme: _progressIndicatorTheme,
  );

  /// 亮色配色方案
  static final ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppConstants.primaryColor,
    onPrimary: Colors.white,
    primaryContainer: AppConstants.primaryColorLight,
    onPrimaryContainer: AppConstants.primaryColorDark,
    secondary: AppConstants.accentColor,
    onSecondary: Colors.white,
    secondaryContainer: Colors.blue[100]!,
    onSecondaryContainer: Colors.blue[800]!,
    background: Colors.grey[50]!,
    onBackground: Colors.grey[900]!,
    surface: Colors.white,
    onSurface: Colors.grey[900]!,
    surfaceVariant: Colors.grey[100]!,
    onSurfaceVariant: Colors.grey[800]!,
    error: AppConstants.errorColor,
    onError: Colors.white,
    errorContainer: Colors.red[100]!,
    onErrorContainer: Colors.red[800]!,
    outline: Colors.grey[300]!,
    outlineVariant: Colors.grey[200]!,
    shadow: Colors.black.withValues(alpha: 0.1),
    scrim: Colors.black.withValues(alpha: 0.5),
    inverseSurface: Colors.grey[900]!,
    onInverseSurface: Colors.white,
    inversePrimary: Colors.blue[300]!,
  );

  /// 暗色配色方案
  static final ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Colors.green[400]!,
    onPrimary: Colors.black,
    primaryContainer: Colors.green[700]!,
    onPrimaryContainer: Colors.green[200]!,
    secondary: Colors.blue[400]!,
    onSecondary: Colors.black,
    secondaryContainer: Colors.blue[700]!,
    onSecondaryContainer: Colors.blue[200]!,
    background: Colors.grey[900]!,
    onBackground: Colors.grey[100]!,
    surface: Colors.grey[800]!,
    onSurface: Colors.grey[100]!,
    surfaceVariant: Colors.grey[700]!,
    onSurfaceVariant: Colors.grey[300]!,
    error: Colors.red[400]!,
    onError: Colors.black,
    errorContainer: Colors.red[800]!,
    onErrorContainer: Colors.red[200]!,
    outline: Colors.grey[600]!,
    outlineVariant: Colors.grey[700]!,
    shadow: Colors.black.withValues(alpha: 0.3),
    scrim: Colors.black.withValues(alpha: 0.8),
    inverseSurface: Colors.grey[100]!,
    onInverseSurface: Colors.grey[900]!,
    inversePrimary: Colors.blue[700]!,
  );

  /// 应用栏主题
  static final AppBarTheme _appBarTheme = AppBarTheme(
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    toolbarHeight: 64,
  );

  /// 卡片主题
  static final CardThemeData _cardTheme = CardThemeData(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
    ),
    margin: EdgeInsets.all(AppConstants.paddingMedium),
    surfaceTintColor: Colors.white,
  );

  /// 按钮主题
  static final ButtonThemeData _buttonTheme = ButtonThemeData(
    buttonColor: AppConstants.primaryColor,
    textTheme: ButtonTextTheme.primary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
    ),
  );

  /// 文本主题（亮色）
  static final TextTheme _lightTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    ),
    displaySmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    ),
    headlineLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    ),
    headlineMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    ),
    headlineSmall: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    ),
    titleLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    ),
    titleMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    ),
    titleSmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      color: Colors.black87,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      color: Colors.black87,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      color: Colors.black87,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.black87,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Colors.black87,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: Colors.black87,
    ),
  );

  /// 文本主题（暗色）
  static final TextTheme _darkTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    displaySmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    headlineLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    headlineMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    headlineSmall: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    titleLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
    titleMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
    titleSmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      color: Colors.white70,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      color: Colors.white70,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      color: Colors.white70,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.white70,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Colors.white70,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: Colors.white70,
    ),
  );

  /// 输入装饰主题
  static final InputDecorationTheme _inputDecorationTheme =
      InputDecorationTheme(
    filled: true,
    fillColor: Colors.grey[50],
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      borderSide: BorderSide(color: Colors.grey[300]!),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      borderSide: BorderSide(color: Colors.grey[300]!),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      borderSide: BorderSide(color: AppConstants.primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      borderSide: BorderSide(color: AppConstants.errorColor),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      borderSide: BorderSide(color: AppConstants.errorColor, width: 2),
    ),
    contentPadding: EdgeInsets.symmetric(
      horizontal: AppConstants.paddingMedium,
      vertical: AppConstants.paddingMedium,
    ),
    hintStyle: TextStyle(color: Colors.grey[400]),
    labelStyle: TextStyle(color: Colors.grey[600]),
    errorStyle: TextStyle(color: AppConstants.errorColor),
  );

  ///  Elevated按钮主题
  static final ElevatedButtonThemeData _elevatedButtonTheme =
      ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingMedium,
      ),
      textStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
    ),
  );

  ///  Outline按钮主题
  static final OutlinedButtonThemeData _outlinedButtonTheme =
      OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingMedium,
      ),
      textStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  /// 文本按钮主题
  static final TextButtonThemeData _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingMedium,
      ),
      textStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  /// 底部导航栏主题
  static final BottomNavigationBarThemeData _bottomNavigationBarTheme =
      BottomNavigationBarThemeData(
    type: BottomNavigationBarType.fixed,
    selectedItemColor: AppConstants.primaryColor,
    unselectedItemColor: Colors.grey[500],
    backgroundColor: Colors.white,
    elevation: 8,
    selectedLabelStyle: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
    unselectedLabelStyle: TextStyle(
      fontSize: 12,
    ),
  );

  /// 标签栏主题
  static final TabBarThemeData _tabBarTheme = TabBarThemeData(
    labelColor: AppConstants.primaryColor,
    unselectedLabelColor: Colors.grey[500],
    indicator: BoxDecoration(
      color: AppConstants.primaryColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
    ),
    labelStyle: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    unselectedLabelStyle: TextStyle(
      fontSize: 14,
    ),
  );

  /// 分割线主题
  static final DividerThemeData _dividerTheme = DividerThemeData(
    color: Colors.grey[200],
    thickness: 1,
    indent: 0,
    endIndent: 0,
  );

  /// 进度指示器主题
  static final ProgressIndicatorThemeData _progressIndicatorTheme =
      ProgressIndicatorThemeData(
    color: AppConstants.primaryColor,
    linearTrackColor: Colors.grey[200],
    circularTrackColor: Colors.grey[200],
  );
}

/// 动画配置
class AppAnimations {
  /// 淡入动画
  static const fadeIn = FadeTransition(
    opacity: AlwaysStoppedAnimation(1.0),
  );

  /// 淡入动画（带曲线）
  static Widget fadeInWithCurve(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      ),
      child: child,
    );
  }

  /// 滑入动画（从右侧）
  static SlideTransition slideInFromRight(
      Widget child, Animation<double> animation) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      )),
      child: child,
    );
  }

  /// 滑入动画（从左侧）
  static SlideTransition slideInFromLeft(
      Widget child, Animation<double> animation) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      )),
      child: child,
    );
  }

  /// 滑入动画（从底部）
  static SlideTransition slideInFromBottom(
      Widget child, Animation<double> animation) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      )),
      child: child,
    );
  }

  /// 缩放动画
  static ScaleTransition scaleIn(Widget child, Animation<double> animation) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.9,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      )),
      child: child,
    );
  }

  /// 缩放动画（带弹跳效果）
  static ScaleTransition scaleInWithBounce(
      Widget child, Animation<double> animation) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.8,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.bounceOut,
      )),
      child: child,
    );
  }

  /// 组合动画（淡入+缩放）
  static Widget fadeScaleIn(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      )),
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 0.95,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        )),
        child: child,
      ),
    );
  }

  /// 组合动画（滑入+淡入）
  static Widget slideFadeIn(Widget child, Animation<double> animation) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.2),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      )),
      child: FadeTransition(
        opacity: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        )),
        child: child,
      ),
    );
  }

  /// 旋转动画
  static RotationTransition rotate(Widget child, Animation<double> animation) {
    return RotationTransition(
      turns: Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      )),
      child: child,
    );
  }

  /// 脉冲动画
  static Widget pulse(Widget child, Animation<double> animation) {
    return ScaleTransition(
      scale: TweenSequence<double>([
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 1.0, end: 1.05),
          weight: 50,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 1.05, end: 1.0),
          weight: 50,
        ),
      ]).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      )),
      child: child,
    );
  }
}

/// 响应式布局辅助类
class ResponsiveLayout {
  /// 获取屏幕宽度
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// 获取屏幕高度
  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// 判断是否为小屏幕
  static bool isSmallScreen(BuildContext context) {
    return getScreenWidth(context) < 600;
  }

  /// 判断是否为中等屏幕
  static bool isMediumScreen(BuildContext context) {
    final width = getScreenWidth(context);
    return width >= 600 && width < 900;
  }

  /// 判断是否为大屏幕
  static bool isLargeScreen(BuildContext context) {
    return getScreenWidth(context) >= 900;
  }

  /// 获取响应式字体大小
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final screenWidth = getScreenWidth(context);
    final scaleFactor = screenWidth / 375; // 以iPhone X宽度为基准
    return baseSize * scaleFactor;
  }

  /// 获取响应式边距
  static EdgeInsets getResponsivePadding(
      BuildContext context, double basePadding) {
    final screenWidth = getScreenWidth(context);
    final scaleFactor = screenWidth / 375; // 以iPhone X宽度为基准
    final padding = basePadding * scaleFactor;
    return EdgeInsets.all(padding);
  }

  /// 获取响应式容器宽度
  static double getResponsiveContainerWidth(
      BuildContext context, double percentage) {
    return getScreenWidth(context) * percentage;
  }

  /// 构建响应式布局
  static Widget buildResponsiveLayout({
    required BuildContext context,
    required Widget smallScreenWidget,
    required Widget mediumScreenWidget,
    required Widget largeScreenWidget,
  }) {
    if (isSmallScreen(context)) {
      return smallScreenWidget;
    } else if (isMediumScreen(context)) {
      return mediumScreenWidget;
    } else {
      return largeScreenWidget;
    }
  }
}
