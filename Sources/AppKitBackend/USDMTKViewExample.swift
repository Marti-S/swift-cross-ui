import AppKit
import MetalKit
import SwiftCrossUI

#if canImport(PixarUSD)
import PixarUSD

/// A SwiftCrossUI view that demonstrates how to use MTKViewRepresentable with SwiftUSD
public struct USDViewerExample: View {
    // MARK: - Properties
    
    /// The USD file path to load
    private let usdFilePath: String
    
    /// The Hydra render engine
    private let hydraEngine: Hydra.RenderEngine
    
    /// The Metal renderer
    private let renderer: Hydra.MTLRenderer
    
    /// The current time code
    @State private var timeCode: Double = 0.0
    
    /// Whether to animate the scene
    @State private var isAnimating: Bool = false
    
    /// The animation timer
    @State private var timer: Timer? = nil
    
    // MARK: - Initialization
    
    /// Creates a new USDViewerExample
    /// - Parameter usdFilePath: The path to the USD file to load
    public init(usdFilePath: String) {
        self.usdFilePath = usdFilePath
        
        // Create the Hydra render engine
        self.hydraEngine = Hydra.RenderEngine(
            rendererPlugin: "HdStormRendererPlugin",
            usdFilePath: usdFilePath
        )
        
        // Create the Metal renderer
        self.renderer = Hydra.MTLRenderer(hydra: hydraEngine)
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack {
            // Title
            Text("USD Viewer")
                .font(.title)
                .padding()
            
            // USD view
            USDMTKView(
                hydraEngine: hydraEngine,
                timeCode: timeCode,
                backgroundColor: .black
            )
            .frame(minWidth: 640, minHeight: 480)
            .cornerRadius(8)
            .padding()
            
            // Controls
            HStack {
                Button(action: toggleAnimation) {
                    Text(isAnimating ? "Pause" : "Play")
                        .frame(width: 80)
                }
                
                Slider(value: $timeCode, in: 0...10, step: 0.1)
                    .disabled(isAnimating)
                    .frame(maxWidth: 300)
                
                Text("Time: \(String(format: "%.1f", timeCode))")
                    .frame(width: 80)
            }
            .padding()
        }
        .onAppear {
            // Set up the scene
            setupScene()
        }
        .onDisappear {
            // Clean up
            timer?.invalidate()
            timer = nil
        }
    }
    
    // MARK: - Private Methods
    
    /// Sets up the scene
    private func setupScene() {
        // Set the camera to a good viewing position
        hydraEngine.setDefaultCamera()
    }
    
    /// Toggles animation
    private func toggleAnimation() {
        isAnimating.toggle()
        
        if isAnimating {
            // Start animation
            timer = Timer.scheduledTimer(withTimeInterval: 1/30, repeats: true) { _ in
                timeCode += 1/30
                if timeCode > 10 {
                    timeCode = 0
                }
            }
        } else {
            // Stop animation
            timer?.invalidate()
            timer = nil
        }
    }
}

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
    
    public func configureView(_ view: MTKView) {
        // Configure the view with safe defaults
        view.clearColor = MTLClearColor(
            red: Double(backgroundColor.redComponent),
            green: Double(backgroundColor.greenComponent),
            blue: Double(backgroundColor.blueComponent),
            alpha: Double(backgroundColor.alphaComponent)
        )
        
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.sampleCount = 1
        
        // Configure layer properties
        if let metalLayer = view.layer as? CAMetalLayer {
            metalLayer.framebufferOnly = true
            metalLayer.presentsWithTransaction = false
            metalLayer.displaySyncEnabled = true
            metalLayer.allowsNextDrawableTimeout = true
            metalLayer.maximumDrawableCount = 3
        }
    }
    
    public func drawableSizeWillChange(view: MTKView, size: CGSize) {
        // Update the camera aspect ratio if needed
        let aspect = Float(size.width / size.height)
        hydraEngine.updateCameraAspectRatio(aspect: aspect)
    }
    
    public func draw(in view: MTKView) {
        // Validate view size
        guard view.bounds.width > 0, view.bounds.height > 0,
              view.drawableSize.width > 0, view.drawableSize.height > 0,
              view.drawableSize.width.isFinite, view.drawableSize.height.isFinite else {
            return
        }
        
        // Wait for previous frame to complete
        _ = inFlightSemaphore.wait(timeout: .distantFuture)
        defer { inFlightSemaphore.signal() }
        
        // Get Hydra graphics interface
        guard let hgi = hydraEngine.getHgi() else {
            print("HYDRA: Failed to retrieve hgi.")
            return
        }
        
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
            
            // Log errors
            if view.currentDrawable == nil {
                print("USDMTKView: Current drawable is nil")
            }
            if currentRenderPassDescriptor == nil {
                print("USDMTKView: Render pass descriptor is nil")
            }
            return
        }
        
        // Blit the texture to the view
        renderEncoder.pushDebugGroup("USDViewBlit")
        
        // Create a simple fullscreen quad
        let vertices: [SIMD2<Float>] = [
            SIMD2<Float>(-1, -1),
            SIMD2<Float>(-1, 1),
            SIMD2<Float>(1, 1),
            SIMD2<Float>(1, -1)
        ]
        
        let indices: [UInt16] = [
            0, 1, 2,
            0, 2, 3
        ]
        
        // Set the texture
        renderEncoder.setFragmentTexture(metalTexture, index: 0)
        
        // Draw the quad
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
        
        // Present drawable and commit command buffer
        commandBuffer.present(currentDrawable)
        
        // Add completion handler to track errors
        commandBuffer.addCompletedHandler { buffer in
            if let error = buffer.error {
                print("USDMTKView: Command buffer error: \(error)")
            }
        }
        
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

// MARK: - Extensions

extension Hydra.RenderEngine {
    /// Sets the camera to a default viewing position
    func setDefaultCamera() {
        // Set a default camera position
        let cameraPosition = SIMD3<Float>(0, 5, 10)
        let cameraTarget = SIMD3<Float>(0, 0, 0)
        let cameraUp = SIMD3<Float>(0, 1, 0)
        
        // Create a camera
        let camera = Hydra.FreeCamera(
            position: cameraPosition,
            target: cameraTarget,
            up: cameraUp,
            fov: 60.0,
            aspectRatio: 16.0 / 9.0,
            nearPlane: 0.1,
            farPlane: 1000.0
        )
        
        // Set the camera
        setCamera(camera)
    }
    
    /// Updates the camera aspect ratio
    /// - Parameter aspect: The new aspect ratio
    func updateCameraAspectRatio(aspect: Float) {
        guard let camera = getCamera() as? Hydra.FreeCamera else {
            return
        }
        
        // Create a new camera with the updated aspect ratio
        let newCamera = Hydra.FreeCamera(
            position: camera.position,
            target: camera.target,
            up: camera.up,
            fov: camera.fov,
            aspectRatio: aspect,
            nearPlane: camera.nearPlane,
            farPlane: camera.farPlane
        )
        
        // Set the camera
        setCamera(newCamera)
    }
}
#endif