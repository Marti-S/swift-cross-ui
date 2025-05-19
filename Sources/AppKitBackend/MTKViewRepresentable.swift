import AppKit
import MetalKit
import SwiftCrossUI

/// A protocol that you use to integrate a MetalKit view into your SwiftCrossUI view hierarchy.
public protocol MTKViewRepresentable: NSViewRepresentable where NSViewType == MTKView {
    /// Creates a Metal device for the view.
    @MainActor
    func makeDevice() -> MTLDevice?
    
    /// Creates a Metal command queue for the view.
    @MainActor
    func makeCommandQueue(device: MTLDevice) -> MTLCommandQueue?
    
    /// Called when the view needs to draw a new frame.
    @MainActor
    func draw(in view: MTKView)
    
    /// Called when the drawable size of the view will change.
    @MainActor
    func drawableSizeWillChange(view: MTKView, size: CGSize)
    
    /// Configure the MTKView with additional settings.
    @MainActor
    func configureView(_ view: MTKView)
}

/// A default implementation of MTKViewRepresentable that provides common functionality.
extension MTKViewRepresentable {
    /// Creates the MTKView instance and configures it with the Metal device and delegate.
    @MainActor
    public func makeNSView(context: NSViewRepresentableContext<Coordinator>) -> MTKView {
        let mtkView = MTKView()
        
        // Set up the Metal device
        let device = makeDevice()
        mtkView.device = device
        
        // Configure the view with safe defaults
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        mtkView.framebufferOnly = true
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.sampleCount = 1
        
        // Configure the CAMetalLayer for better performance and stability
        if let metalLayer = mtkView.layer as? CAMetalLayer {
            metalLayer.framebufferOnly = true
            metalLayer.presentsWithTransaction = false
            metalLayer.displaySyncEnabled = true
            metalLayer.allowsNextDrawableTimeout = true
            
            // Set a reasonable maximum drawable count to prevent resource issues
            metalLayer.maximumDrawableCount = 3
        }
        
        // Allow custom configuration
        configureView(mtkView)
        
        return mtkView
    }
    
    /// Updates the MTKView with new values.
    @MainActor
    public func updateNSView(_ nsView: MTKView, context: NSViewRepresentableContext<Coordinator>) {
        // Ensure view has valid size before updating drawable size
        if nsView.bounds.width > 0 && nsView.bounds.height > 0 {
            let scale = nsView.window?.backingScaleFactor ?? 1.0
            let width = max(1, nsView.bounds.width * scale)
            let height = max(1, nsView.bounds.height * scale)
            nsView.drawableSize = CGSize(width: width, height: height)
        }
    }
    
    /// Creates a default Metal device.
    @MainActor
    public func makeDevice() -> MTLDevice? {
        MTLCreateSystemDefaultDevice()
    }
    
    /// Creates a default command queue for the given device.
    @MainActor
    public func makeCommandQueue(device: MTLDevice) -> MTLCommandQueue? {
        device.makeCommandQueue()
    }
    
    /// Called when the drawable size of the view will change.
    @MainActor
    public func drawableSizeWillChange(view: MTKView, size: CGSize) {
        // Default implementation does nothing
    }
    
    /// Configure the MTKView with additional settings.
    @MainActor
    public func configureView(_ view: MTKView) {
        // Default implementation does nothing
    }
    
    /// Creates a coordinator that acts as the MTKViewDelegate.
    @MainActor
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// The coordinator class that acts as the MTKViewDelegate.
    public class Coordinator: NSObject, MTKViewDelegate {
        var parent: Self
        var commandQueue: MTLCommandQueue?
        
        init(_ parent: Self) {
            self.parent = parent
            super.init()
            
            // Set up the command queue if we have a device
            if let device = parent.makeDevice() {
                self.commandQueue = parent.makeCommandQueue(device: device)
            }
        }
        
        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Validate size to prevent invalid dimensions
            let validSize = CGSize(
                width: size.width.isFinite && size.width > 0 ? size.width : 1,
                height: size.height.isFinite && size.height > 0 ? size.height : 1
            )
            
            parent.drawableSizeWillChange(view: view, size: validSize)
        }
        
        public func draw(in view: MTKView) {
            // Ensure view has valid size before drawing
            guard view.bounds.width > 0, view.bounds.height > 0,
                  view.drawableSize.width > 0, view.drawableSize.height > 0,
                  view.drawableSize.width.isFinite, view.drawableSize.height.isFinite else {
                return
            }
            
            // Ensure we have a valid current drawable before drawing
            guard view.currentDrawable != nil else {
                return
            }
            
            parent.draw(in: view)
        }
    }
}