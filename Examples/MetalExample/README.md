# Metal Example

This example demonstrates how to use Metal with SwiftCrossUI through the MTKViewRepresentable protocol.

## Features

- Integration of Metal rendering with SwiftCrossUI
- Two different Metal rendering examples:
  - SimpleMTKView: Renders a colored triangle
  - TexturedMTKView: Renders a textured quad with rotation

## Requirements

- macOS 10.15 or later
- Xcode 12.0 or later
- A Mac with Metal support

## Running the Example

To run this example, use the following command from the root of the repository:

```bash
swift run MetalExample
```

## Implementation Details

The Metal integration is implemented through the following components:

1. **MTKViewRepresentable**: A protocol that extends NSViewRepresentable to work with MTKView
2. **SimpleMTKView**: A basic implementation that renders a colored triangle
3. **TexturedMTKView**: A more advanced implementation that renders a textured quad with rotation

The example demonstrates:
- How to create and configure an MTKView
- How to handle Metal device and command queue creation
- How to create render pipelines and buffers
- How to implement Metal shaders
- How to integrate Metal rendering with SwiftCrossUI's view lifecycle

## Customizing

You can customize the example by:
- Changing the colors of the background and triangle
- Adjusting the rotation of the textured quad
- Switching between the simple and textured views

## Notes

This implementation is for macOS only. To support other platforms, additional work would be needed to create platform-specific implementations.