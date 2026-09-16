import Foundation

final class SharedStateStore {
  private let sharedStateKey = "sharedState"
  private let setupParamsKey = "setupParams"
  private let runTimeKey = "runTime"
  private let profileEpochKey = "profileEpoch"
  private let appliedProfileEpochKey = "appliedProfileEpoch"
  private let eventQueueDirectoryName = "core-events"

  private var lastProfileID: Int?
  private var profileChanged = false

  let appGroupIdentifier = "group.\(Bundle.main.bundleIdentifier!)"
  let eventNotificationName = "\(Bundle.main.bundleIdentifier!).NECore.event"

  func saveSharedState(_ data: Data) -> Bool {
    guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      return false
    }
    if lastProfileID == nil,
      let existingData = userDefaults.data(forKey: sharedStateKey),
      let existing = try? JSONSerialization.jsonObject(with: existingData)
        as? [String: Any]
    {
      lastProfileID = existing["currentProfileId"] as? Int
    }
    let previousProfileID = lastProfileID
    var stateData = data
    if var json = try? JSONSerialization.jsonObject(with: data)
      as? [String: Any]
    {
      let profileID = json["currentProfileId"] as? Int
      profileChanged = previousProfileID != profileID
      let epoch = userDefaults.integer(forKey: profileEpochKey)
      let nextEpoch = lastProfileID != profileID ? epoch &+ 1 : max(epoch, 1)
      lastProfileID = profileID
      userDefaults.set(nextEpoch, forKey: profileEpochKey)
      json["profileEpoch"] = nextEpoch
      stateData = (try? JSONSerialization.data(withJSONObject: json)) ?? data
      if let setupParams = json[setupParamsKey],
        !(setupParams is NSNull),
        JSONSerialization.isValidJSONObject(setupParams),
        let setupData = try? JSONSerialization.data(withJSONObject: setupParams)
      {
        userDefaults.set(setupData, forKey: setupParamsKey)
      }
    }
    userDefaults.set(stateData, forKey: sharedStateKey)
    userDefaults.synchronize()
    return true
  }

  func consumeProfileChange() -> Bool {
    let changed = profileChanged
    profileChanged = false
    return changed
  }

  func profileEpoch() -> UInt64 {
    UInt64(UserDefaults(suiteName: appGroupIdentifier)?.integer(
      forKey: profileEpochKey
    ) ?? 0)
  }

  func markCurrentProfileApplied() {
    UserDefaults(suiteName: appGroupIdentifier)?.set(
      profileEpoch(),
      forKey: appliedProfileEpochKey
    )
  }

  func appliedProfileEpoch() -> UInt64 {
    UInt64(UserDefaults(suiteName: appGroupIdentifier)?.integer(
      forKey: appliedProfileEpochKey
    ) ?? 0)
  }

  func isCurrentProfileApplied() -> Bool {
    let epoch = profileEpoch()
    return epoch != 0 && appliedProfileEpoch() == epoch
  }

  func isCurrentProfileEpoch(_ epoch: UInt64) -> Bool {
    profileEpoch() == epoch
  }

  func loadTunnelConfiguration() -> TunnelConfiguration {
    guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier),
      let data = userDefaults.data(forKey: sharedStateKey),
      let sharedState = try? JSONDecoder().decode(
        SharedStatePayload.self,
        from: data
      )
    else {
      return TunnelConfiguration()
    }
    return TunnelConfiguration(
      options: sharedState.vpnOptions?.networkExtensionOptions ??
        NetworkExtensionOptions(),
      excludeSSIDs: sharedState.excludeSSIDs ?? [],
      alwaysOn: sharedState.alwaysOn ?? false
    )
  }

  func appGroupDirectory() -> URL? {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    )
  }

  func eventQueueDirectory() -> URL? {
    appGroupDirectory()?.appendingPathComponent(
      eventQueueDirectoryName,
      isDirectory: true
    )
  }

  func runTime() -> Int {
    UserDefaults(suiteName: appGroupIdentifier)?
      .integer(forKey: runTimeKey) ?? 0
  }
}

struct TunnelConfiguration {
  let options: NetworkExtensionOptions
  let excludeSSIDs: [String]
  let alwaysOn: Bool

  init(
    options: NetworkExtensionOptions = NetworkExtensionOptions(),
    excludeSSIDs: [String] = [],
    alwaysOn: Bool = false
  ) {
    self.options = options
    self.excludeSSIDs = excludeSSIDs
    self.alwaysOn = alwaysOn
  }
}

struct NetworkExtensionOptions {
  var includeAllNetworks = false
  var excludeLocalNetworks = true
  var excludeAPNs = true
  var excludeCellularServices = true
  var enforceRoutes = false
  var excludeDeviceCommunication = true
}

private struct SharedStatePayload: Decodable {
  let vpnOptions: VpnOptionsPayload?
  let excludeSSIDs: [String]?
  let alwaysOn: Bool?
}

private struct VpnOptionsPayload: Decodable {
  let includeAllNetworks: Bool?
  let excludeLocalNetworks: Bool?
  let excludeAPNs: Bool?
  let excludeCellularServices: Bool?
  let enforceRoutes: Bool?
  let excludeDeviceCommunication: Bool?

  var networkExtensionOptions: NetworkExtensionOptions {
    NetworkExtensionOptions(
      includeAllNetworks: includeAllNetworks ?? false,
      excludeLocalNetworks: excludeLocalNetworks ?? true,
      excludeAPNs: excludeAPNs ?? true,
      excludeCellularServices: excludeCellularServices ?? true,
      enforceRoutes: enforceRoutes ?? false,
      excludeDeviceCommunication: excludeDeviceCommunication ?? true
    )
  }
}
