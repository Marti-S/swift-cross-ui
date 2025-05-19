import AppKit
import MetalKit
import SwiftCrossUI

/// A simple implementation of MTKViewRepresentable that renders a colored triangle.
public struct SimpleMTKView: MTKViewRepresentable {
    // MARK: - Properties
    
    /// The color to clear the background with
    public var clearColor: Color
    
    /// The color of the triangle
    public var triangleColor: Color
    
    // MARK: - Private Properties
    
    private var pipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?
    private let semaphore = DispatchSemaphore(value: 1)
    
    // MARK: - Initialization
    
    public init(clearColor: Color = .black, triangleColor: Color = .blue) {
        self.clearColor = clearColor
        self.triangleColor = triangleColor
    }
    
    // MARK: - MTKViewRepresentable
    
    @MainActor
    public func configureView(_ view: MTKView) {
        // Set the clear color
        let nsColor = clearColor.nsColor
        view.clearColor = MTLClearColor(
            red: Double(nsColor.redComponent),
            green: Double(nsColor.greenComponent),
            blue: Double(nsColor.blueComponent),
            alpha: Double(nsColor.alphaComponent)
        )
        
        // Create the render pipeline
        if let device = view.device {
            createRenderPipeline(device: device)
            createVertexBuffer(device: device)
        }
    }
    
    @MainActor
    public func updateNSView(_ nsView: MTKView, context: NSViewRepresentableContext<Coordinator>) {
        // Call the parent implementation to handle drawable size updates
        super.updateNSView(nsView, context: context)
        
        // Update the clear color if it changed
        let nsColor = clearColor.nsColor
        nsView.clearColor = MTLClearColor(
            red: Double(nsColor.redComponent),
            green: Double(nsColor.greenComponent),
            blue: Double(nsColor.blueComponent),
            alpha: Double(nsColor.alphaComponent)
        )
        
        // Trigger a redraw
        nsView.setNeedsDisplay()
    }
    
    @MainActor
    public func drawableSizeWillChange(view: MTKView, size: CGSize) {
        // Nothing special needed for this simple example
    }
    
    @MainActor
    public func draw(in view: MTKView) {
        // Wait for previous frame to complete
        _ = semaphore.wait(timeout: .distantFuture)
        defer { semaphore.signal() }
        
        guard let device = view.device,
              let commandQueue = view.currentCommandQueue ?? device.makeCommandQueue(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
              let pipelineState = self.pipelineState,
              let vertexBuffer = self.vertexBuffer,
              let drawable = view.currentDrawable else {
            return
        }
        
        // Set the render pipeline state
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Set the vertex buffer
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // Set the triangle color
        let nsColor = triangleColor.nsColor
        var color = SIMD4<Float>(
            Float(nsColor.redComponent),
            Float(nsColor.greenComponent),
            Float(nsColor.blueComponent),
            Float(nsColor.alphaComponent)
        )
        renderEncoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
        
        // Draw the triangle
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        
        // End encoding
        renderEncoder.endEncoding()
        
        // Schedule drawable presentation
        commandBuffer.present(drawable)
        
        // Add completion handler to track errors
        commandBuffer.addCompletedHandler { buffer in
            if let error = buffer.error {
                print("Command buffer error: \(error)")
            }
        }
        
        // Commit the command buffer
        commandBuffer.commit()
    }
    
    // MARK: - Private Methods
    
    private func createRenderPipeline(device: MTLDevice) {
        // Create the shader library
        guard let library = device.makeDefaultLibrary() else {
            print("Failed to create default library")
            return
        }
        
        // Create the vertex function
        guard let vertexFunction = library.makeFunction(name: "vertexShader") else {
            print("Failed to create vertex function")
            return
        }
        
        // Create the fragment function
        guard let fragmentFunction = library.makeFunction(name: "fragmentShader") else {
            print("Failed to create fragment function")
            return
        }
        
        // Create the render pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Enable blending for transparency
        let colorAttachment = pipelineDescriptor.colorAttachments[0]!
        colorAttachment.isBlendingEnabled = true
        colorAttachment.rgbBlendOperation = .add
        colorAttachment.alphaBlendOperation = .add
        colorAttachment.sourceRGBBlendFactor = .sourceAlpha
        colorAttachment.sourceAlphaBlendFactor = .sourceAlpha
        colorAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        colorAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        // Create the render pipeline state
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline state: \(error)")
        }
    }
    
    private func createVertexBuffer(device: MTLDevice) {
        // Define the triangle vertices
        let vertices: [SIMD2<Float>] = [
            SIMD2<Float>(0, 0.5),
            SIMD2<Float>(-0.5, -0.5),
            SIMD2<Float>(0.5, -0.5)
        ]
        
        // Create the vertex buffer
        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<SIMD2<Float>>.stride,
            options: .storageModeShared
        )
    }
}

// MARK: - Metal Shaders

// Note: These shaders would normally be in a .metal file, but for simplicity
// we're defining them as strings that will be compiled at runtime.

#if canImport(Metal)
import Metal

// Create the default library with the shaders
extension MTLDevice {
    func makeDefaultLibrary() -> MTLLibrary? {
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        struct VertexOut {
            float4 position [[position]];
        };
        
        vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                                     constant float2 *vertices [[buffer(0)]]) {
            VertexOut out;
            out.position = float4(vertices[vertexID], 0.0, 1.0);
            return out;
        }
        
        fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                      constant float4 &color [[buffer(0)]]) {
            return color;
        }
        """
        
        do {
            return try makeLibrary(source: shaderSource, options: nil)
        } catch {
            print("Failed to create shader library: \(error)")
            return nil
        }
    }
}
#endif