import Foundation

enum PacketTunnelEnvironment {
  static let extensionBundleIdentifier = Bundle.main.bundleIdentifier!
  static let baseBundleIdentifier = String(
    extensionBundleIdentifier.dropLast(".NECore".count)
  )
  static let appGroupIdentifier = "group.\(baseBundleIdentifier)"
  static let widgetIdentifier = "\(baseBundleIdentifier).Widget"
  static let eventNotificationName =
    "\(extensionBundleIdentifier).event"
}

enum SharedStateSource: String {
  case options
  case defaults
  case snapshot
}

enum SharedStateFailure: String {
  case suiteUnavailable = "suite_unavailable"
  case noData = "no_data"
  case decodeFailed = "decode_failed"
}

struct SharedStateLoadResult {
  let options: PacketTunnelVPNOptions?
  let source: SharedStateSource?
  let failure: SharedStateFailure?
  let byteCount: Int
}

final class PacketTunnelSharedStateStore {
  private static let emptySetupParams = Data("{}".utf8)

  private let sharedStateKey = "sharedState"
  private let setupParamsKey = "setupParams"
  private let runTimeKey = "runTime"
  private let profileEpochKey = "profileEpoch"
  private let appliedProfileEpochKey = "appliedProfileEpoch"
  private let tunnelAttemptIDKey = "tunnelAttemptID"
  private let snapshotFileName = "shared-state.json"
  private var startOptionsData: Data?

  func adoptStartOptions(_ options: [String: NSObject]?) {
    guard let options else { return }
    if let text = options[sharedStateKey] as? String,
      let data = text.data(using: .utf8)
    {
      startOptionsData = data
      userDefaults?.set(data, forKey: sharedStateKey)
    }
    if let attemptID = options[tunnelAttemptIDKey] as? String {
      userDefaults?.set(attemptID, forKey: tunnelAttemptIDKey)
    }
  }

  func loadVPNOptionsResult() -> SharedStateLoadResult {
    var failure: SharedStateFailure?
    if let data = startOptionsData,
      let options = decodeVPNOptions(data)
    {
      return SharedStateLoadResult(options: options, source: .options, failure: nil, byteCount: data.count)
    } else if startOptionsData != nil {
      failure = .decodeFailed
    }
    if let userDefaults {
      if let data = userDefaults.data(forKey: sharedStateKey),
        let options = decodeVPNOptions(data)
      {
        return SharedStateLoadResult(options: options, source: .defaults, failure: nil, byteCount: data.count)
      } else if userDefaults.data(forKey: sharedStateKey) != nil {
        failure = .decodeFailed
      }
    } else {
      failure = .suiteUnavailable
    }
    if let data = snapshotData(), let options = decodeVPNOptions(data) {
      userDefaults?.set(data, forKey: sharedStateKey)
      return SharedStateLoadResult(options: options, source: .snapshot, failure: nil, byteCount: data.count)
    }
    return SharedStateLoadResult(
      options: nil,
      source: nil,
      failure: failure ?? .noData,
      byteCount: 0
    )
  }

  func loadVPNOptions() -> PacketTunnelVPNOptions? {
    loadVPNOptionsResult().options
  }

  private func decodeVPNOptions(_ data: Data) -> PacketTunnelVPNOptions? {
    guard let sharedState = try? JSONDecoder().decode(
      PacketTunnelSharedState.self,
      from: data
    ) else { return nil }
    return sharedState.vpnOptions
  }

  private func snapshotData() -> Data? {
    guard let url = appGroupDirectory()?.appendingPathComponent(snapshotFileName) else {
      return nil
    }
    return try? Data(contentsOf: url)
  }

  func loadSetupParams() -> Data {
    if let data = startOptionsData, let params = setupParams(from: data) {
      return params
    }
    if let data = userDefaults?.data(forKey: setupParamsKey) {
      return data
    }
    if let data = userDefaults?.data(forKey: sharedStateKey),
      let params = setupParams(from: data)
    {
      userDefaults?.set(params, forKey: setupParamsKey)
      return params
    }
    if let data = snapshotData(), let params = setupParams(from: data) {
      userDefaults?.set(params, forKey: setupParamsKey)
      return params
    }
    return Self.emptySetupParams
  }

  private func setupParams(from data: Data) -> Data? {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let params = json[setupParamsKey],
      !(params is NSNull),
      JSONSerialization.isValidJSONObject(params)
    else { return nil }
    return try? JSONSerialization.data(withJSONObject: params)
  }

  func profileEpoch() -> UInt64 {
    UInt64(userDefaults?.integer(forKey: profileEpochKey) ?? 0)
  }

  func markProfileEpochApplied(_ epoch: UInt64) {
    userDefaults?.set(epoch, forKey: appliedProfileEpochKey)
  }

  func isCurrentProfileEpoch(_ epoch: UInt64) -> Bool {
    profileEpoch() == epoch
  }

  func makeInitParams() -> String {
    let homeDirectory = appGroupDirectory()?.path ?? ""
    return "{\"home-dir\":\"\(homeDirectory)\",\"version\":0}"
  }

  func appGroupDirectory() -> URL? {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier:
        PacketTunnelEnvironment.appGroupIdentifier
    )
  }

  func saveRunTime() {
    let milliseconds = Int(Date().timeIntervalSince1970 * 1000)
    userDefaults?.set(milliseconds, forKey: runTimeKey)
  }

  func clearRunTime() {
    userDefaults?.removeObject(forKey: runTimeKey)
  }

  private var userDefaults: UserDefaults? {
    UserDefaults(
      suiteName: PacketTunnelEnvironment.appGroupIdentifier
    )
  }
}

private struct PacketTunnelSharedState: Decodable {
  let vpnOptions: PacketTunnelVPNOptions?
}

struct PacketTunnelVPNOptions: Decodable {
  let port: Int
  let ipv6: Bool
  let captureDns: Bool
  let systemProxy: Bool
  let suspendSupport: Bool
  let bypassDomain: [String]
  let stack: String
  let mtu: Int
  let routeAddress: [String]
  let disableIcmpForwarding: Bool
  let endpointIndependentNat: Bool
  let recvMsgX: Bool
  let sendMsgX: Bool
  let includeAllNetworks: Bool
  let excludeLocalNetworks: Bool
  let excludeAPNs: Bool
  let excludeCellularServices: Bool
  let enforceRoutes: Bool
  let excludeDeviceCommunication: Bool

  private enum CodingKeys: String, CodingKey {
    case port
    case ipv6
    case captureDns
    case systemProxy
    case suspendSupport
    case bypassDomain
    case stack
    case mtu
    case routeAddress
    case disableIcmpForwarding
    case endpointIndependentNat
    case recvMsgX
    case sendMsgX
    case includeAllNetworks
    case excludeLocalNetworks
    case excludeAPNs
    case excludeCellularServices
    case enforceRoutes
    case excludeDeviceCommunication
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    port = try container.decode(Int.self, forKey: .port)
    ipv6 = try container.decode(Bool.self, forKey: .ipv6)
    captureDns = try container.decode(Bool.self, forKey: .captureDns)
    systemProxy = try container.decode(Bool.self, forKey: .systemProxy)
    suspendSupport = try container.decodeIfPresent(
      Bool.self,
      forKey: .suspendSupport
    ) ?? true
    bypassDomain = try container.decodeIfPresent(
      [String].self,
      forKey: .bypassDomain
    ) ?? []
    stack = try container.decode(String.self, forKey: .stack)
    mtu = try container.decodeIfPresent(Int.self, forKey: .mtu) ?? 9000
    routeAddress = try container.decodeIfPresent(
      [String].self,
      forKey: .routeAddress
    ) ?? []
    disableIcmpForwarding = try container.decodeIfPresent(
      Bool.self,
      forKey: .disableIcmpForwarding
    ) ?? false
    endpointIndependentNat = try container.decodeIfPresent(
      Bool.self,
      forKey: .endpointIndependentNat
    ) ?? false
    recvMsgX = try container.decodeIfPresent(Bool.self, forKey: .recvMsgX) ?? true
    sendMsgX = try container.decodeIfPresent(Bool.self, forKey: .sendMsgX) ?? false
    includeAllNetworks = try container.decodeIfPresent(
      Bool.self,
      forKey: .includeAllNetworks
    ) ?? false
    excludeLocalNetworks = try container.decodeIfPresent(
      Bool.self,
      forKey: .excludeLocalNetworks
    ) ?? true
    excludeAPNs = try container.decodeIfPresent(
      Bool.self,
      forKey: .excludeAPNs
    ) ?? true
    excludeCellularServices = try container.decodeIfPresent(
      Bool.self,
      forKey: .excludeCellularServices
    ) ?? true
    enforceRoutes = try container.decodeIfPresent(
      Bool.self,
      forKey: .enforceRoutes
    ) ?? false
    excludeDeviceCommunication = try container.decodeIfPresent(
      Bool.self,
      forKey: .excludeDeviceCommunication
    ) ?? true
  }
}
