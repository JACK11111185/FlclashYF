class ProfileSwitchEpoch {
  int _epoch = 0;
  int? _profileId;

  int get epoch => _epoch;

  int select(int? profileId) {
    if (_profileId != profileId || _epoch == 0) {
      _profileId = profileId;
      _epoch++;
    }
    return _epoch;
  }

  bool accepts({required int epoch, required int? profileId}) {
    return epoch == _epoch && profileId == _profileId;
  }
}
