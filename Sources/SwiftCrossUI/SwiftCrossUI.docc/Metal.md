# Metal Integration

Integrate Metal rendering with SwiftCrossUI using MTKViewRepresentable.

## Overview

SwiftCrossUI provides integration with Metal through the `MTKViewRepresentable` protocol, which allows you to create custom Metal views that can be used within your SwiftCrossUI application.

The Metal integration is currently available only for macOS through the AppKitBackend.

## Getting Started

To use Metal in your SwiftCrossUI application, you need to create a view that conforms to the `MTKViewRepresentable` protocol:

```swift
import SwiftCrossUI
import AppKitBackend
import MetalKit

struct MyMetalView: MTKViewRepresentable {
    func makeDevice() -> MTLDevice? {
        MTLCreateSystemDefaultDevice()
    }
    
    func makeCommandQueue(device: MTLDevice) -> MTLCommandQueue? {
        device.makeCommandQueue()
    }
    
    func draw(in view: MTKView) {
        // Your Metal drawing code here
    }
}
```

You can then use this view in your SwiftCrossUI application:

```swift
struct ContentView: View {
    var body: some View {
        VStack {
            Text("Metal View")
            MyMetalView()
                .frame(width: 300, height: 300)
        }
    }
}
```

## MTKViewRepresentable Protocol

The `MTKViewRepresentable` protocol extends `NSViewRepresentable` and provides a convenient way to integrate Metal rendering with SwiftCrossUI:

```swift
public protocol MTKViewRepresentable: NSViewRepresentable where NSViewType == MTKView {
    func makeDevice() -> MTLDevice?
    func makeCommandQueue(device: MTLDevice) -> MTLCommandQueue?
    func draw(in view: MTKView)
}
```

### Required Methods

- `makeDevice()`: Creates and returns a Metal device for the view.
- `makeCommandQueue(device:)`: Creates and returns a Metal command queue for the given device.
- `draw(in:)`: Called when the view needs to draw a new frame.

### Default Implementations

The protocol provides default implementations for:

- `makeNSView(context:)`: Creates and configures an MTKView instance.
- `updateNSView(_:context:)`: Updates the MTKView with new values.
- `makeCoordinator()`: Creates a coordinator that acts as the MTKViewDelegate.

## Examples

SwiftCrossUI includes two example implementations of MTKViewRepresentable:

### SimpleMTKView

A basic implementation that renders a colored triangle:

```swift
struct SimpleMTKView: MTKViewRepresentable {
    var clearColor: Color
    var triangleColor: Color
    
    func draw(in view: MTKView) {
        // Draw a triangle with the specified color
    }
}
```

### TexturedMTKView

A more advanced implementation that renders a textured quad with rotation:

```swift
struct TexturedMTKView: MTKViewRepresentable {
    var clearColor: Color
    var image: NSImage?
    var rotation: Float
    
    func draw(in view: MTKView) {
        // Draw a textured quad with rotation
    }
}
```

## Best Practices

When working with Metal in SwiftCrossUI, consider the following best practices:

1. **Resource Management**: Create and manage Metal resources (buffers, textures, etc.) efficiently.
2. **Error Handling**: Handle errors gracefully when creating Metal resources.
3. **Performance**: Optimize your Metal code for performance, especially for complex rendering.
4. **State Management**: Manage Metal state (render pipeline state, sampler state, etc.) carefully.
5. **Memory Management**: Be mindful of memory usage, especially for large textures.

## Topics

### Essentials

- ``MTKViewRepresentable``
- ``SimpleMTKView``
- ``TexturedMTKView``

### Advanced Topics

- Metal Shaders
- Texture Loading
- Animation with Metal