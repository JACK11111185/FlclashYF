import Flutter
import UIKit
import XCTest

class RunnerTests: XCTestCase {

  func testProfileEpochContractSourcesRemainWired() throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let sharedState = try String(
      contentsOf: root.appendingPathComponent("Runner/Storage/SharedStateStore.swift")
    )
    let provider = try String(
      contentsOf: root.appendingPathComponent("NECore/PacketTunnelProvider.swift")
    )
    let router = try String(
      contentsOf: root.appendingPathComponent("Runner/Core/CoreMessageRouter.swift")
    )

    XCTAssertTrue(sharedState.contains("appliedProfileEpoch"))
    XCTAssertTrue(sharedState.contains("markCurrentProfileApplied"))
    XCTAssertTrue(provider.contains("isConfigurationMessage"))
    XCTAssertTrue(provider.contains("markProfileEpochApplied"))
    XCTAssertTrue(router.contains("didApplyCurrentProfile"))
    XCTAssertTrue(router.contains("profile_switching"))
  }

}
