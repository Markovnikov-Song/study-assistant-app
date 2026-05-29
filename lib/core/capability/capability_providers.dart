import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'capability_models.dart';
import 'capability_service.dart';

final capabilityServiceProvider = Provider<CapabilityService>((ref) {
  return CapabilityService();
});

final standaloneCapabilitiesProvider = FutureProvider<List<CapabilitySummary>>((
  ref,
) async {
  return ref.read(capabilityServiceProvider).listCapabilities(standalone: true);
});

final allCapabilitiesProvider = FutureProvider<List<CapabilitySummary>>((
  ref,
) async {
  return ref.read(capabilityServiceProvider).listCapabilities();
});
