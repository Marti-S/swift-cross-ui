import SwiftCrossUI
import AppKitBackend

struct MetalExampleApp: App {
    var body: some Scene {
        WindowGroup("Metal Example") {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var clearColor = Color.black
    @State private var triangleColor = Color.blue
    @State private var rotation: Float = 0.0
    @State private var useTexturedView = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Metal Example")
                .font(.title)
            
            if useTexturedView {
                // Use the textured MTKView
                TexturedMTKView(
                    clearColor: clearColor,
                    rotation: rotation
                )
                .frame(width: 300, height: 300)
            } else {
                // Use the simple MTKView
                SimpleMTKView(
                    clearColor: clearColor,
                    triangleColor: triangleColor
                )
                .frame(width: 300, height: 300)
            }
            
            HStack {
                Text("Background:")
                ColorPicker("", selection: $clearColor)
            }
            
            if !useTexturedView {
                HStack {
                    Text("Triangle Color:")
                    ColorPicker("", selection: $triangleColor)
                }
            } else {
                HStack {
                    Text("Rotation:")
                    Slider(value: $rotation, in: 0...6.28)
                }
            }
            
            Toggle("Use Textured View", isOn: $useTexturedView)
            
            Text("This example demonstrates how to use MTKView with SwiftCrossUI")
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding(20)
    }
}

MetalExampleApp.main()