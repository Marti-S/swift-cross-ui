# MTKView Integration in SwiftCrossUI

This document describes the implementation of Metal rendering in SwiftCrossUI through the `MTKViewRepresentable` protocol.

## Overview

The `MTKViewRepresentable` protocol provides a way to integrate Metal rendering into SwiftCrossUI applications. It extends `NSViewRepresentable` and provides a convenient API for creating and managing Metal views.

## Key Components

### MTKViewRepresentable Protocol

The core protocol that defines the interface for Metal views in SwiftCrossUI:

```swift
public protocol MTKViewRepresentable: NSViewRepresentable where NSViewType == MTKView {
    func makeDevice() -> MTLDevice?
    func makeCommandQueue(device: MTLDevice) -> MTLCommandQueue?
    func draw(in view: MTKView)
    func drawableSizeWillChange(view: MTKView, size: CGSize)
    func configureView(_ view: MTKView)
}
```

### Example Implementations

1. **SimpleMTKView**: A basic implementation that renders a colored triangle.
2. **TexturedMTKView**: A more advanced implementation that renders a textured quad with rotation.
3. **USDMTKView**: A specialized implementation for rendering USD scenes with Hydra.

## Common Issues and Solutions

The implementation addresses several common issues with Metal rendering:

### 1. CAMetalLayer Allocation Failures

```
[CAMetalLayer nextDrawable] returning nil because allocation failed.
```

**Solution**: 
- Validate drawable size before setting it
- Use a reasonable maximum drawable count
- Ensure proper synchronization with semaphores

### 2. Invalid Drawable Sizes

```
CAMetalLayer ignoring invalid setDrawableSize width=inf height=inf
```

**Solution**:
- Check for valid, finite dimensions before setting drawable size
- Set a minimum size of 1x1 to avoid zero dimensions
- Scale dimensions based on the window's backing scale factor

### 3. Missing Render Pass Descriptors

```
Failed to blit because there is no render pass descriptor for the current view.
```

**Solution**:
- Check for nil render pass descriptors before drawing
- Ensure the view has valid dimensions
- Properly configure the MTKView's pixel format and sample count

### 4. Multiple Presentation of Drawables

```
Each CAMetalLayerDrawable can only be presented once!
```

**Solution**:
- Use semaphores to control frame rendering
- Ensure proper command buffer completion
- Add error handling for command buffer execution

## Integration with SwiftUSD

The `USDMTKView` implementation demonstrates how to integrate with SwiftUSD's Hydra rendering engine:

1. Create a Hydra render engine with the desired renderer plugin
2. Get the Metal device from the Hydra engine
3. Render the scene using Hydra's render method
4. Convert the Hydra texture to a Metal texture
5. Blit the texture to the MTKView

## Best Practices

1. **Synchronization**: Use semaphores to control frame rendering and prevent resource contention
2. **Error Handling**: Add completion handlers to command buffers to catch and log errors
3. **Resource Management**: Use shared storage mode for buffers when possible
4. **Validation**: Check for nil values and valid dimensions before drawing
5. **Configuration**: Properly configure the MTKView and CAMetalLayer for optimal performance

## Example Usage

```swift
struct MyView: View {
    var body: some View {
        VStack {
            Text("Metal Rendering")
                .font(.title)
            
            SimpleMTKView(
                clearColor: .black,
                triangleColor: .blue
            )
            .frame(width: 400, height: 300)
            .cornerRadius(8)
        }
    }
}
```

## Platform Support

Currently, the implementation is macOS-only. Future work will extend support to other platforms like iOS, tvOS, and visionOS.