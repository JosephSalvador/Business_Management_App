import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/features/roles/data/role_models.dart';
import 'package:jolinx_app/features/roles/presentation/role_permission_groups.dart';
import 'package:jolinx_app/l10n/generated/app_localizations.dart';

void main() {
  test('groups permissions by their product area and sorts each group', () {
    final groups = groupPermissionsByArea(const [
      Permission(name: 'Sales.View'),
      Permission(name: 'Products.Update'),
      Permission(name: 'Sales.Create'),
    ]);

    // Group labels are the raw area keys; display localization happens via
    // roleAreaLabel at render time.
    expect(groups.map((group) => group.label), ['Products', 'Sales']);
    expect(
      groups.last.permissions.map((permission) => permission.name),
      ['Sales.Create', 'Sales.View'],
    );
  });

  test('roleAreaLabel localizes known areas and falls back to the raw key',
      () {
    final sw = lookupAppLocalizations(const Locale('sw'));
    final en = lookupAppLocalizations(const Locale('en'));

    expect(roleAreaLabel(sw, 'Products'), 'Bidhaa');
    expect(roleAreaLabel(sw, 'Sales'), 'Mauzo');
    expect(roleAreaLabel(en, 'Products'), 'Products');
    expect(roleAreaLabel(en, 'UnknownArea'), 'UnknownArea');
  });
}
