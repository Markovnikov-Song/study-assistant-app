import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

/// Shell 底部/侧边 Tab 路径（应用 [GoRouter.go] 切换）。
const shellTabRoutes = <String>{
  '/',
  R.courseSpace,
  R.toolkit,
  R.profile,
};

/// 从 Shell 内跳转到 Tab 用 [go]，全屏页（课程空间、脑图工坊等）用 [push]。
void navigateAppRoute(BuildContext context, String route) {
  if (shellTabRoutes.contains(route)) {
    context.go(route);
  } else {
    context.push(route);
  }
}
