import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mini_app_models.dart';
import 'mini_app_service.dart';

final miniAppServiceProvider = Provider<MiniAppService>((ref) {
  return MiniAppService();
});

final miniAppsProvider = FutureProvider<List<MiniAppSummary>>((ref) async {
  return ref.read(miniAppServiceProvider).listApps();
});

final miniAppBlockRegistryProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  return ref.read(miniAppServiceProvider).getBlockRegistry();
});

final workshopWorkflowRegistryProvider =
    FutureProvider<WorkshopWorkflowRegistry>((ref) async {
      return ref.read(miniAppServiceProvider).getWorkflowRegistry();
    });

final workshopResourceActorTypesProvider =
    FutureProvider<List<WorkshopResourceActorType>>((ref) async {
      return ref.read(miniAppServiceProvider).getResourceActorTypes();
    });

final miniAppProvider = FutureProvider.family<MiniAppRecord, String>((
  ref,
  id,
) async {
  return ref.read(miniAppServiceProvider).getApp(id);
});
