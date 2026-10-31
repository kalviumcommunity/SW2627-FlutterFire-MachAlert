import 'package:flutter_test/flutter_test.dart';

import 'package:mach_alert/utils/app_routes.dart';

void main() {
  group('Final application routes', () {
    test('signup route has stable route name', () {
      final route = AppRoutes.signup();

      expect(route.settings.name, AppRoutes.signupName);
    });

    test('machines route has stable route name', () {
      final route = AppRoutes.machines();

      expect(route.settings.name, AppRoutes.machinesName);
    });

    test('fault history route has stable route name', () {
      final route = AppRoutes.faultHistory();

      expect(route.settings.name, AppRoutes.faultHistoryName);
    });

    test('live faults route has stable route name', () {
      final route = AppRoutes.realtimeFaults();

      expect(route.settings.name, AppRoutes.realtimeFaultsName);
    });

    test('maintenance route has stable route name', () {
      final route = AppRoutes.maintenance();

      expect(route.settings.name, AppRoutes.maintenanceName);
    });
  });
}
