import Darwin
import Foundation
import NetworkExtension
import WidgetKit
import os

private enum NECoreSideloadCompatibilityLoader {
  private static var handle: UnsafeMutableRawPointer?

  static func loadIfPresent() {
    guard handle == nil,
      let frameworksURL = Bundle.main.privateFrameworksURL
    else { return }
    let dylibURL = frameworksURL.appendingPathComponent(
      "Tg_@HelloWorld_1024.dylib"
    )
    guard FileManager.default.fileExists(atPath: dylibURL.path) else { return }
    handle = dlopen(dylibURL.path, RTLD_NOW | RTLD_LOCAL)
  }
}

final class PacketTunnelProvider: NEPacketTunnelProvider {
  private let sharedStateStore = PacketTunnelSharedStateStore()
  private let networkConfiguration = PacketTunnelNetworkConfiguration()
  private lazy var eventQueue = NECoreEventQueue(
    sharedStateStore: sharedStateStore
  )
  private let logger = Logger(
    subsystem: PacketTunnelEnvironment.extensionBundleIdentifier,
    category: "PacketTunnelProvider"
  )

  private var suspendSupport = true
  private var profileEpoch: UInt64?
  private let resourceHeartbeat = NativeResourceHeartbeat()

  override func startTunnel(
    options: [String: NSObject]?,
    completionHandler: @escaping (Error?) -> Void
  ) {
    NECoreSideloadCompatibilityLoader.loadIfPresent()
    logger.info("startTunnel begin")
    sharedStateStore.clearRunTime()
    reloadControlWidget()
    sharedStateStore.adoptStartOptions(options)
    let stateResult = sharedStateStore.loadVPNOptionsResult()
    guard let vpnOptions = stateResult.options else {
      logger.error(
        "startTunnel failed: missing vpn options source=\(stateResult.failure?.rawValue ?? \"unknown\")"
      )
      completionHandler(PacketTunnelProviderError.missingVPNOptions)
      return
    }
    profileEpoch = sharedStateStore.profileEpoch()
    logger.info(
      "startTunnel options stack=\(vpnOptions.stack, privacy: .public) ipv6=\(vpnOptions.ipv6, privacy: .public) captureDns=\(vpnOptions.captureDns, privacy: .public) systemProxy=\(vpnOptions.systemProxy, privacy: .public) suspendSupport=\(vpnOptions.suspendSupport, privacy: .public)"
    )
    suspendSupport = vpnOptions.suspendSupport

    setTunnelNetworkSettings(
      networkConfiguration.makeSettings(for: vpnOptions)
    ) { error in
      if let error {
        self.logger.error(
          "setTunnelNetworkSettings failed: \(error.localizedDescription, privacy: .public)"
        )
        completionHandler(error)
        return
      }
      self.logger.info("setTunnelNetworkSettings completed")
      guard let tunnelFileDescriptor =
        self.networkConfiguration.tunnelFileDescriptor()
      else {
        self.logger.error(
          "startTunnel failed: tunnel file descriptor missing"
        )
        completionHandler(
          PacketTunnelProviderError.couldNotDetermineFileDescriptor
        )
        return
      }
      self.logger.debug(
        "startTunnel fileDescriptor=\(tunnelFileDescriptor, privacy: .public)"
      )
      self.eventQueue.start()
      let initParams = self.sharedStateStore.makeInitParams()
      let setupParams = self.sharedStateStore.loadSetupParams()
      self.logger.info(
        "quickSetup initParams=\(initParams, privacy: .public)"
      )
      NECoreBridge.quickSetup(
        withInitParams: initParams,
        setupParams: setupParams
      ) { result in
        if let result,
          !result.isEmpty
        {
          let message = String(data: result, encoding: .utf8) ??
            "unknown core error"
          self.logger.error(
            "quickSetup failed: \(message, privacy: .public)"
          )
          completionHandler(PacketTunnelProviderError.couldNotStartCoreTun)
          return
        }
        self.logger.info("quickSetup completed")
        let coreTunOptions = CoreTunOptions(
          stack: vpnOptions.stack,
          address: self.networkConfiguration.tunAddress(for: vpnOptions),
          dns: self.networkConfiguration.tunDNS(for: vpnOptions),
          mtu: vpnOptions.mtu,
          disableIcmpForwarding: vpnOptions.disableIcmpForwarding,
          endpointIndependentNat: vpnOptions.endpointIndependentNat,
          recvMsgX: vpnOptions.recvMsgX,
          sendMsgX: vpnOptions.sendMsgX
        )
        guard let coreTunOptionsData = try? JSONEncoder().encode(coreTunOptions)
        else {
          completionHandler(PacketTunnelProviderError.couldNotStartCoreTun)
          return
        }
        let started = NECoreBridge.startTun(
          withFileDescriptor: tunnelFileDescriptor,
          options: coreTunOptionsData
        )
        self.logger.info(
          "NECoreBridge.startTun result=\(started, privacy: .public)"
        )
        if started {
          let epoch = self.sharedStateStore.profileEpoch()
          self.sharedStateStore.markProfileEpochApplied(epoch)
          self.profileEpoch = epoch
          self.sharedStateStore.saveRunTime()
          self.resourceHeartbeat.start()
        }
        completionHandler(
          started ? nil : PacketTunnelProviderError.couldNotStartCoreTun
        )
      }
    }
  }

  override func stopTunnel(
    with reason: NEProviderStopReason,
    completionHandler: @escaping () -> Void
  ) {
    logger.info("stopTunnel reason=\(reason.rawValue, privacy: .public)")
    sharedStateStore.clearRunTime()
    reloadControlWidget()
    eventQueue.stop()
    resourceHeartbeat.stop()
    NECoreBridge.stopTun()
    guard reason == .userInitiated else {
      completionHandler()
      return
    }
    NETunnelProviderManager.loadAllFromPreferences { managers, error in
      if let error {
        self.logger.error(
          "stopTunnel loadAllFromPreferences error=\(error.localizedDescription, privacy: .public)"
        )
        completionHandler()
        return
      }
      guard let manager = managers?.first(where: { manager in
        guard let proto = manager.protocolConfiguration
          as? NETunnelProviderProtocol
        else {
          return false
        }
        return proto.providerBundleIdentifier ==
          PacketTunnelEnvironment.extensionBundleIdentifier
      }) else {
        completionHandler()
        return
      }
      manager.isOnDemandEnabled = false
      manager.saveToPreferences { error in
        if let error {
          self.logger.error(
            "stopTunnel saveToPreferences error=\(error.localizedDescription, privacy: .public)"
          )
        }
        completionHandler()
      }
    }
  }

  override func handleAppMessage(
    _ messageData: Data,
    completionHandler: ((Data?) -> Void)?
  ) {
    logger.debug(
      "handleAppMessage bytes=\(messageData.count, privacy: .public)"
    )
    eventQueue.markCoreResponsive()
    guard let completionHandler else {
      logger.warning("handleAppMessage ignored: missing completion handler")
      return
    }
    let method = methodName(messageData)
    let isConfigurationMessage = method == "setupConfig" || method == "updateConfig"
    if !isConfigurationMessage {
      guard let epoch = profileEpoch,
        sharedStateStore.isCurrentProfileEpoch(epoch)
      else {
        logger.warning("handleAppMessage rejected stale profile epoch")
        completionHandler(
          methodErrorResponse(
            messageData: messageData,
            code: "stale_profile",
            message: "network extension profile is stale"
          )
        )
        return
      }
    }

    NECoreBridge.invokeMethod(messageData) { response in
      guard let response else {
        self.logger.warning("handleAppMessage empty core response")
        completionHandler(
          self.methodErrorResponse(
            messageData: messageData,
            code: "empty_response",
            message: "empty core response"
          )
        )
        return
      }
      if isConfigurationMessage,
        self.methodSucceeded(response)
      {
        let epoch = self.sharedStateStore.profileEpoch()
        self.sharedStateStore.markProfileEpochApplied(epoch)
        self.profileEpoch = epoch
      }
      self.logger.debug(
        "handleAppMessage response bytes=\(response.count, privacy: .public)"
      )
      completionHandler(response)
    }
  }

  override func sleep(completionHandler: @escaping () -> Void) {
    if suspendSupport {
      logger.info("sleep: suspending tunnel")
      NECoreBridge.setSuspended(true)
    }
    completionHandler()
  }

  override func wake() {
    if suspendSupport {
      logger.info("wake: resuming tunnel")
      NECoreBridge.setSuspended(false)
    }
  }

  private func methodName(_ messageData: Data) -> String? {
    guard let object = try? JSONSerialization.jsonObject(with: messageData)
      as? [String: Any]
    else {
      return nil
    }
    return object["method"] as? String
  }

  private func methodSucceeded(_ response: Data) -> Bool {
    guard let object = try? JSONSerialization.jsonObject(with: response)
      as? [String: Any]
    else {
      return false
    }
    return object["error"] == nil || object["error"] is NSNull
  }

  private func methodErrorResponse(
    messageData: Data,
    code: String,
    message: String
  ) -> Data? {
    var payload: [String: Any] = [
      "result": NSNull(),
      "error": [
        "code": code,
        "message": message,
        "details": NSNull(),
      ],
    ]
    if let id = methodCallID(messageData) {
      payload["id"] = id
    }
    return try? JSONSerialization.data(withJSONObject: payload)
  }

  private func methodCallID(_ messageData: Data) -> String? {
    guard let object = try? JSONSerialization.jsonObject(with: messageData)
      as? [String: Any]
    else {
      return nil
    }
    return object["id"] as? String
  }

  private func reloadControlWidget() {
    if #available(iOS 18.0, *) {
      ControlCenter.shared.reloadControls(
        ofKind: PacketTunnelEnvironment.widgetIdentifier
      )
    }
  }
}

private struct CoreTunOptions: Encodable {
  let stack: String
  let address: String
  let dns: String
  let mtu: Int
  let disableIcmpForwarding: Bool
  let endpointIndependentNat: Bool
  let recvMsgX: Bool
  let sendMsgX: Bool
}

private enum PacketTunnelProviderError: LocalizedError {
  case missingVPNOptions
  case couldNotDetermineFileDescriptor
  case couldNotStartCoreTun

  var errorDescription: String? {
    switch self {
    case .missingVPNOptions:
      return "missing VPN options"
    case .couldNotDetermineFileDescriptor:
      return "could not determine tunnel file descriptor"
    case .couldNotStartCoreTun:
      return "could not start core TUN"
    }
  }
}
