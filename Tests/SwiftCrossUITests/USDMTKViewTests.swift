import XCTest
@testable import SwiftCrossUI
@testable import AppKitBackend

#if canImport(PixarUSD) && canImport(MetalKit)
import PixarUSD
import MetalKit

final class USDMTKViewTests: XCTestCase {
    func testUSDMTKViewCreation() {
        // This test only runs on macOS
        #if os(macOS)
        // Skip the test if we can't create a Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Skipping test because Metal is not available")
            return
        }
        
        // Create a sample USD file path
        let sampleUsdPath = "/tmp/sample.usda"
        
        // Create a Hydra render engine
        let hydraEngine = Hydra.RenderEngine(
            rendererPlugin: "HdStormRendererPlugin",
            usdFilePath: sampleUsdPath
        )
        
        // Create a USDMTKView
        let usdMTKView = USDMTKView(
            hydraEngine: hydraEngine,
            timeCode: 0.0,
            backgroundColor: .black
        )
        
        // Create a context
        let coordinator = usdMTKView.makeCoordinator()
        let context = NSViewRepresentableContext<USDMTKView.Coordinator>(
            coordinator: coordinator,
            environment: EnvironmentValues()
        )
        
        // Create the NSView
        let nsView = usdMTKView.makeNSView(context: context)
        
        // Verify the view was created correctly
        XCTAssertTrue(nsView is MTKView)
        XCTAssertNotNil(nsView.device)
        
        // Update the view
        usdMTKView.updateNSView(nsView, context: context)
        
        // Test drawable size change
        let newSize = CGSize(width: 800, height: 600)
        usdMTKView.drawableSizeWillChange(view: nsView, size: newSize)
        
        // Verify the coordinator was set up correctly
        XCTAssertNotNil(coordinator.commandQueue)
        #endif
    }
}
#endif