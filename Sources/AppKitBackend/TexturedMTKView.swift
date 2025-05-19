import AppKit
import MetalKit
import SwiftCrossUI

/// A more advanced implementation of MTKViewRepresentable that renders a textured quad.
public struct TexturedMTKView: MTKViewRepresentable {
    // MARK: - Properties
    
    /// The color to clear the background with
    public var clearColor: Color
    
    /// The image to use as a texture
    public var image: NSImage?
    
    /// The rotation angle in radians
    public var rotation: Float
    
    // MARK: - Private Properties
    
    private var pipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    private var texture: MTLTexture?
    private var samplerState: MTLSamplerState?
    
    // MARK: - Initialization
    
    public init(clearColor: Color = .black, image: NSImage? = nil, rotation: Float = 0) {
        self.clearColor = clearColor
        self.image = image
        self.rotation = rotation
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
        
        // Create the render pipeline and resources
        if let device = view.device {
            createRenderPipeline(device: device)
            createBuffers(device: device)
            createSamplerState(device: device)
            createTexture(device: device)
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
        
        // Update the texture if the image changed
        if let device = nsView.device {
            createTexture(device: device)
        }
        
        // Trigger a redraw
        nsView.setNeedsDisplay()
    }
    
    @MainActor
    public func drawableSizeWillChange(view: MTKView, size: CGSize) {
        // Nothing special needed for this example
    }
    
    @MainActor
    public func draw(in view: MTKView) {
        // Use a semaphore to ensure we don't have too many frames in flight
        let semaphore = DispatchSemaphore(value: 1)
        _ = semaphore.wait(timeout: .distantFuture)
        defer { semaphore.signal() }
        
        // Validate all required resources
        guard let device = view.device,
              let commandQueue = view.currentCommandQueue ?? device.makeCommandQueue(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
              let pipelineState = self.pipelineState,
              let vertexBuffer = self.vertexBuffer,
              let indexBuffer = self.indexBuffer,
              let drawable = view.currentDrawable else {
            if view.currentDrawable == nil {
                print("TexturedMTKView: Current drawable is nil")
            }
            if renderPassDescriptor == nil {
                print("TexturedMTKView: Render pass descriptor is nil")
            }
            return
        }
        
        // Set the render pipeline state
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Set the vertex buffer
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // Set the rotation uniform
        var uniforms = Uniforms(rotation: rotation)
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)
        
        // Set the texture and sampler state
        if let texture = self.texture, let samplerState = self.samplerState {
            renderEncoder.setFragmentTexture(texture, index: 0)
            renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        }
        
        // Draw the quad
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
        
        // End encoding
        renderEncoder.endEncoding()
        
        // Schedule drawable presentation
        commandBuffer.present(drawable)
        
        // Add completion handler to track errors
        commandBuffer.addCompletedHandler { buffer in
            if let error = buffer.error {
                print("TexturedMTKView: Command buffer error: \(error)")
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
        guard let vertexFunction = library.makeFunction(name: "texturedVertexShader") else {
            print("Failed to create vertex function")
            return
        }
        
        // Create the fragment function
        guard let fragmentFunction = library.makeFunction(name: "texturedFragmentShader") else {
            print("Failed to create fragment function")
            return
        }
        
        // Create the render pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Create the render pipeline state
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline state: \(error)")
        }
    }
    
    private func createBuffers(device: MTLDevice) {
        // Define the quad vertices (position and texture coordinates)
        let vertices: [Vertex] = [
            Vertex(position: SIMD2<Float>(-0.5, 0.5), texCoord: SIMD2<Float>(0, 0)),
            Vertex(position: SIMD2<Float>(-0.5, -0.5), texCoord: SIMD2<Float>(0, 1)),
            Vertex(position: SIMD2<Float>(0.5, -0.5), texCoord: SIMD2<Float>(1, 1)),
            Vertex(position: SIMD2<Float>(0.5, 0.5), texCoord: SIMD2<Float>(1, 0))
        ]
        
        // Create the vertex buffer with shared storage mode for better performance
        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Vertex>.stride,
            options: .storageModeShared
        )
        
        // Define the indices for drawing two triangles
        let indices: [UInt16] = [
            0, 1, 2,
            0, 2, 3
        ]
        
        // Create the index buffer with shared storage mode for better performance
        indexBuffer = device.makeBuffer(
            bytes: indices,
            length: indices.count * MemoryLayout<UInt16>.stride,
            options: .storageModeShared
        )
    }
    
    private func createSamplerState(device: MTLDevice) {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        
        samplerState = device.makeSamplerState(descriptor: samplerDescriptor)
    }
    
    private func createTexture(device: MTLDevice) {
        guard let image = self.image else {
            return
        }
        
        // Create a texture from the NSImage
        let textureLoader = MTKTextureLoader(device: device)
        
        // Convert NSImage to CGImage
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("Failed to convert NSImage to CGImage")
            return
        }
        
        do {
            texture = try textureLoader.newTexture(cgImage: cgImage, options: nil)
        } catch {
            print("Failed to create texture: \(error)")
        }
    }
}

// MARK: - Supporting Types

/// Vertex structure with position and texture coordinates
struct Vertex {
    var position: SIMD2<Float>
    var texCoord: SIMD2<Float>
}

/// Uniforms structure for shader parameters
struct Uniforms {
    var rotation: Float
}

// MARK: - Metal Shaders

#if canImport(Metal)
import Metal

// Extend the default library with textured shaders
extension MTLDevice {
    func makeDefaultLibrary() -> MTLLibrary? {
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        // Vertex shader structures
        struct VertexIn {
            float2 position [[attribute(0)]];
            float2 texCoord [[attribute(1)]];
        };
        
        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };
        
        struct Uniforms {
            float rotation;
        };
        
        // Basic vertex and fragment shaders
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
        
        // Textured vertex and fragment shaders
        vertex VertexOut texturedVertexShader(uint vertexID [[vertex_id]],
                                             constant Vertex *vertices [[buffer(0)]],
                                             constant Uniforms &uniforms [[buffer(1)]]) {
            Vertex in = vertices[vertexID];
            
            // Apply rotation
            float cosR = cos(uniforms.rotation);
            float sinR = sin(uniforms.rotation);
            float2 rotatedPosition = float2(
                in.position.x * cosR - in.position.y * sinR,
                in.position.x * sinR + in.position.y * cosR
            );
            
            VertexOut out;
            out.position = float4(rotatedPosition, 0.0, 1.0);
            out.texCoord = in.texCoord;
            return out;
        }
        
        fragment float4 texturedFragmentShader(VertexOut in [[stage_in]],
                                              texture2d<float> texture [[texture(0)]],
                                              sampler textureSampler [[sampler(0)]]) {
            return texture.sample(textureSampler, in.texCoord);
        }
        
        // Vertex structure
        struct Vertex {
            float2 position;
            float2 texCoord;
        };
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