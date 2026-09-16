import 'package:fl_clash/common/profile_switch_epoch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile switches invalidate responses from the previous epoch', () {
    final epochs = ProfileSwitchEpoch();
    final first = epochs.select(10);
    final second = epochs.select(20);

    expect(epochs.accepts(epoch: first, profileId: 10), isFalse);
    expect(epochs.accepts(epoch: second, profileId: 20), isTrue);
  });

  test('reselecting the active profile preserves its epoch', () {
    final epochs = ProfileSwitchEpoch();
    final first = epochs.select(10);
    final repeated = epochs.select(10);

    expect(repeated, first);
    expect(epochs.accepts(epoch: first, profileId: 10), isTrue);
  });

  test('an epoch never accepts a response for another profile', () {
    final epochs = ProfileSwitchEpoch();
    final epoch = epochs.select(10);

    expect(epochs.accepts(epoch: epoch, profileId: 20), isFalse);
  });
}
