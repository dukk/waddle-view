import 'package:test/test.dart';
import 'package:waddle_shared/auth/adoption_challenge_format.dart';
import 'package:waddle_shared/persistence/tables.dart';

void main() {
  test('formatAdoptionChallengeCode inserts hyphen', () {
    expect(formatAdoptionChallengeCode('abcd1234'), 'ABCD-1234');
    expect(formatAdoptionChallengeCode('ABCD-1234'), 'ABCD-1234');
  });

  test('normalizeAdoptionChallengeCode strips separators', () {
    expect(normalizeAdoptionChallengeCode('ab12-cd34'), 'AB12CD34');
  });

  test('adoptionRoleDisplayLabel maps known roles', () {
    expect(adoptionRoleDisplayLabel(kUserRoleAdmin), 'Admin');
    expect(adoptionRoleDisplayLabel(kUserRolePowerViewer), 'Power viewer');
  });
}
