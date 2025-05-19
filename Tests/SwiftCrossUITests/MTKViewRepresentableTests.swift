import XCTest
@testable import SwiftCrossUI
@testable import AppKitBackend

#if canImport(MetalKit)
import MetalKit

final class MTKViewRepresentableTests: XCTestCase {
    func testMTKViewRepresentableCreation() {
        // This test only runs on macOS
        #if os(macOS)
        let metalView = TestMTKView()
        
        // Create a context
        let coordinator = metalView.makeCoordinator()
        let context = NSViewRepresentableContext<TestMTKView.Coordinator>(
            coordinator: coordinator,
            environment: EnvironmentValues()
        )
        
        // Create the NSView
        let nsView = metalView.makeNSView(context: context)
        
        // Verify the view was created correctly
        XCTAssertTrue(nsView is MTKView)
        XCTAssertNotNil(nsView.device)
        
        // Update the view
        metalView.updateNSView(nsView, context: context)
        
        // Verify the coordinator was set up correctly
        XCTAssertNotNil(coordinator.commandQueue)
        #endif
    }
}

// A simple MTKViewRepresentable implementation for testing
struct TestMTKView: MTKViewRepresentable {
    func draw(in view: MTKView) {
        // No drawing for tests
    }
}
#endif