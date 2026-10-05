import 'package:flutter_test/flutter_test.dart';
import 'package:jolinx_app/features/roles/data/role_models.dart';
import 'package:jolinx_app/features/roles/presentation/role_permission_groups.dart';

void main() {
  test('groups permissions by their product area and sorts each group', () {
    final groups = groupPermissionsByArea(const [
      Permission(name: 'Sales.View'),
      Permission(name: 'Products.Update'),
      Permission(name: 'Sales.Create'),
    ]);

    expect(groups.map((group) => group.label), ['Bidhaa', 'Mauzo']);
    expect(
      groups.last.permissions.map((permission) => permission.name),
      ['Sales.Create', 'Sales.View'],
    );
  });
}
