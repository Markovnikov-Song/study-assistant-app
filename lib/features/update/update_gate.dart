import 'package:flutter/material.dart';

import '../../services/update_service.dart';
import 'update_dialog.dart';

class UpdateGate extends StatefulWidget {
  final Widget child;

  const UpdateGate({super.key, required this.child});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  bool _checkedThisLaunch = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_checkedThisLaunch) {
      _checkForUpdate();
    }
  }

  Future<void> _checkForUpdate() async {
    if (_checking || _checkedThisLaunch || !mounted) return;
    _checking = true;
    try {
      final result = await UpdateService.instance.checkForUpdate();
      _checkedThisLaunch = true;
      if (!result.hasUpdate || !mounted) return;
      await showUpdateDialog(context, result.info!, isForced: result.isForced);
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
