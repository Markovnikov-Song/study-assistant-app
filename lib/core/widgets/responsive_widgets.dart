import 'package:flutter/material.dart';
import '../utils/device_info.dart';

/// 设备感知组件 - 根据设备类型返回不同 widget
class DeviceBuilder extends StatelessWidget {
  /// 移动端 widget
  final Widget? mobile;

  /// 平板 widget
  final Widget? tablet;

  /// 桌面端 widget
  final Widget? desktop;

  /// 大屏幕（平板横屏+桌面）widget
  final Widget? largeScreen;

  const DeviceBuilder({
    super.key,
    this.mobile,
    this.tablet,
    this.desktop,
    this.largeScreen,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = DeviceInfo.deviceType;

    Widget? child;
    if (largeScreen != null && deviceType != DeviceType.mobile) {
      child = largeScreen;
    } else {
      switch (deviceType) {
        case DeviceType.mobile:
          child = mobile;
        case DeviceType.tablet:
          child = tablet ?? mobile;
        case DeviceType.desktop:
          child = desktop ?? mobile;
      }
    }

    return child ?? const SizedBox.shrink();
  }
}

/// 屏幕尺寸感知组件 - 根据屏幕宽度返回不同 widget
class ScreenBuilder extends StatelessWidget {
  /// 小屏幕 widget (<600)
  final Widget? small;

  /// 中等屏幕 widget (600-1024)
  final Widget? medium;

  /// 大屏幕 widget (>1024)
  final Widget? large;

  /// 自定义断点 builder
  final Widget Function(BuildContext context, Breakpoint breakpoint)? breakpoint;

  const ScreenBuilder({
    super.key,
    this.small,
    this.medium,
    this.large,
    this.breakpoint,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (breakpoint != null) {
      Breakpoint bp;
      if (width < Breakpoints.mobile) {
        bp = Breakpoint.small;
      } else if (width < Breakpoints.desktop) {
        bp = Breakpoint.medium;
      } else {
        bp = Breakpoint.large;
      }
      return breakpoint!(context, bp);
    }

    if (width < Breakpoints.mobile) {
      return small ?? const SizedBox.shrink();
    } else if (width < Breakpoints.desktop) {
      return medium ?? small ?? const SizedBox.shrink();
    } else {
      return large ?? small ?? const SizedBox.shrink();
    }
  }
}

/// 断点枚举
enum Breakpoint {
  small,   // <600
  medium,  // 600-1024
  large,   // >1024
}

/// 响应式 padding
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsets? mobilePadding;
  final EdgeInsets? tabletPadding;
  final EdgeInsets? desktopPadding;

  const ResponsivePadding({
    super.key,
    required this.child,
    this.mobilePadding,
    this.tabletPadding,
    this.desktopPadding,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = DeviceInfo.deviceType;

    EdgeInsets padding;
    switch (deviceType) {
      case DeviceType.mobile:
        padding = mobilePadding ?? const EdgeInsets.symmetric(horizontal: 16);
      case DeviceType.tablet:
        padding = tabletPadding ?? const EdgeInsets.symmetric(horizontal: 24);
      case DeviceType.desktop:
        padding = desktopPadding ?? const EdgeInsets.symmetric(horizontal: 32);
    }

    return Padding(padding: padding, child: child);
  }
}

/// 响应式边距容器
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final double? mobileMaxWidth;
  final double? tabletMaxWidth;
  final double? desktopMaxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.mobileMaxWidth,
    this.tabletMaxWidth,
    this.desktopMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = DeviceInfo.deviceType;

    double? targetMaxWidth = maxWidth;
    switch (deviceType) {
      case DeviceType.mobile:
        targetMaxWidth = mobileMaxWidth ?? maxWidth ?? 600;
      case DeviceType.tablet:
        targetMaxWidth = tabletMaxWidth ?? maxWidth ?? 800;
      case DeviceType.desktop:
        targetMaxWidth = desktopMaxWidth ?? maxWidth ?? 1200;
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: targetMaxWidth),
        child: child,
      ),
    );
  }
}

/// 响应式 GridView
class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;
  final double runSpacing;

  const ResponsiveGridView({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = DeviceInfo.deviceType;

    int columns;
    switch (deviceType) {
      case DeviceType.mobile:
        columns = mobileColumns;
      case DeviceType.tablet:
        columns = tabletColumns;
      case DeviceType.desktop:
        columns = desktopColumns;
    }

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: children.map((child) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - spacing * (columns - 1)) / columns,
          child: child,
        );
      }).toList(),
    );
  }
}

/// 响应式按钮
class ResponsiveButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isPrimary;

  const ResponsiveButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = DeviceInfo.deviceType;

    // 桌面端按钮可以更宽
    final minWidth = deviceType == DeviceType.desktop ? 120.0 : 0.0;

    if (isPrimary) {
      return FilledButton(
        onPressed: onPressed,
        style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(minWidth, 48))),
        child: child,
      );
    } else {
      return OutlinedButton(
        onPressed: onPressed,
        style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(minWidth, 48))),
        child: child,
      );
    }
  }
}

/// 响应式卡片
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = DeviceInfo.deviceType;

    // 桌面端卡片可以有阴影
    final elevation = deviceType == DeviceType.desktop ? 2.0 : 0.0;

    Widget content = Card(
      elevation: elevation,
      child: Padding(
        padding: padding ?? EdgeInsets.all(deviceType == DeviceType.mobile ? 12 : 16),
        child: child,
      ),
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      );
    }

    return content;
  }
}
