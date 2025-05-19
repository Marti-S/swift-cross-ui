import AppKit
import MetalKit
import SwiftCrossUI

#if canImport(PixarUSD)
import PixarUSD

/// A specialized MTKViewRepresentable for rendering USD scenes with Hydra
public struct USDMTKView: MTKViewRepresentable {
    // MARK: - Properties
    
    /// The Hydra render engine
    private let hydraEngine: Hydra.RenderEngine
    
    /// The current time code for rendering
    private let timeCode: Double
    
    /// The background color
    private let backgroundColor: NSColor
    
    /// Semaphore to control in-flight rendering
    private let inFlightSemaphore = DispatchSemaphore(value: 1)
    
    // MARK: - Initialization
    
    /// Creates a new USDMTKView
    /// - Parameters:
    ///   - hydraEngine: The Hydra render engine
    ///   - timeCode: The time code for rendering
    ///   - backgroundColor: The background color (default is clear)
    public init(
        hydraEngine: Hydra.RenderEngine,
        timeCode: Double = 0.0,
        backgroundColor: Color = .clear
    ) {
        self.hydraEngine = hydraEngine
        self.timeCode = timeCode
        self.backgroundColor = backgroundColor.nsColor
    }
    
    // MARK: - MTKViewRepresentable
    
    public func makeDevice() -> MTLDevice? {
        return hydraEngine.hydraDevice
    }
    
    public func makeCommandQueue(device: MTLDevice) -> MTLCommandQueue? {
        return device.makeCommandQueue()
    }
    
    public func makeNSView(context: NSViewRepresentableContext<Coordinator>) -> MTKView {
        let mtkView = super.makeNSView(context: context)
        
        // Configure the view with safe defaults
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = true
        mtkView.framebufferOnly = true
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.sampleCount = 1
        
        // Set clear color
        mtkView.clearColor = MTLClearColor(
            red: Double(backgroundColor.redComponent),
            green: Double(backgroundColor.greenComponent),
            blue: Double(backgroundColor.blueComponent),
            alpha: Double(backgroundColor.alphaComponent)
        )
        
        // Configure layer properties
        if let metalLayer = mtkView.layer as? CAMetalLayer {
            metalLayer.framebufferOnly = true
            metalLayer.presentsWithTransaction = false
            metalLayer.displaySyncEnabled = true
            metalLayer.allowsNextDrawableTimeout = true
        }
        
        return mtkView
    }
    
    public func updateNSView(_ nsView: MTKView, context: NSViewRepresentableContext<Coordinator>) {
        // Ensure view has valid size
        if nsView.bounds.width <= 0 || nsView.bounds.height <= 0 {
            return
        }
        
        // Update drawable size with valid dimensions
        let scale = nsView.window?.backingScaleFactor ?? 1.0
        let width = max(1, nsView.bounds.width * scale)
        let height = max(1, nsView.bounds.height * scale)
        nsView.drawableSize = CGSize(width: width, height: height)
        
        // Trigger a redraw
        nsView.setNeedsDisplay()
    }
    
    public func draw(in view: MTKView) {
        // Validate view size
        guard view.bounds.width > 0, view.bounds.height > 0 else {
            return
        }
        
        // Get Hydra graphics interface
        guard let hgi = hydraEngine.getHgi() else {
            print("HYDRA: Failed to retrieve hgi.")
            return
        }
        
        // Wait for previous frame to complete
        _ = inFlightSemaphore.wait(timeout: .distantFuture)
        defer { inFlightSemaphore.signal() }
        
        // Start frame
        hgi.pointee.StartFrame()
        
        // Get view size
        let viewSize = view.drawableSize
        
        // Render the scene
        guard let hgiTexture = hydraEngine.render(at: timeCode, viewSize: viewSize),
              let metalTexture = getMetalTexture(from: hgiTexture),
              let commandBuffer = hgi.pointee.GetPrimaryCommandBuffer(),
              let currentRenderPassDescriptor = view.currentRenderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor),
              let currentDrawable = view.currentDrawable else {
            // End frame even if rendering fails
            hgi.pointee.EndFrame()
            return
        }
        
        // Blit the texture to the view
        renderEncoder.pushDebugGroup("USDViewBlit")
        renderEncoder.setFragmentTexture(metalTexture, index: 0)
        
        // Create a simple fullscreen triangle
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
        
        // Present drawable and commit command buffer
        commandBuffer.present(currentDrawable)
        
        // End frame
        hgi.pointee.CommitPrimaryCommandBuffer()
        hgi.pointee.EndFrame()
    }
    
    // MARK: - Helper Methods
    
    /// Converts an HgiTextureHandle to an MTLTexture
    private func getMetalTexture(from hgiTexture: Pixar.HgiTextureHandle) -> MTLTexture? {
        // Get the HGI texture
        guard let hgiTex = hgiTexture.Get() else {
            print("HYDRA: Failed to retrieve the hgi texture.")
            return nil
        }
        
        // Get the raw pointer from the HGI handle
        let rawPtr = UnsafeRawPointer(hgiTex)
        
        // Get the HGI texture from the raw pointer
        let texPtr: Pixar.HgiMetalTexture = Unmanaged.fromOpaque(rawPtr).takeUnretainedValue()
        
        // Get the Metal texture from the HGI texture
        let metalTexture = texPtr.GetTextureId()
        return metalTexture
    }
}
#endif