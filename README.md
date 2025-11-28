# Lottie to MP4 Renderer

A command-line tool that renders Lottie animations (JSON files) to MP4 video files on macOS.

## Features

- Convert Lottie JSON animations to high-quality MP4 videos
- Customizable output scaling
- Configurable video bitrate for quality control
- Progress indication during rendering
- Built with Swift and optimized for macOS

## Usage

### Basic Usage

Convert a Lottie file to MP4 with default settings:

```bash
lottie2mp4 animation.json
```

This will create `animation.mp4` in the same directory.

### Specify Output Path

```bash
lottie2mp4 animation.json output/my-video.mp4
```

### Custom Scale Factor

Render at 2x scale for higher resolution:

```bash
lottie2mp4 animation.json --scale 2.0
```

### Custom Bitrate

Set a specific bitrate (5 Mbps in this example):

```bash
lottie2mp4 animation.json --bitrate 5000000
```

## Examples

### Basic Animation Export
```bash
# Convert logo animation to MP4
lottie2mp4 logo-animation.json

# Output: logo-animation.mp4
```

### High-Resolution Export
```bash
# Export at 3x scale for retina displays
lottie2mp4 button-animation.json --scale 3.0

# Output: button-animation.mp4 (3x original size)
```

### Quality-Controlled Export
```bash
# Export with specific quality settings
lottie2mp4 complex-animation.json final-video.mp4 --scale 2.0 --bitrate 10000000

# Output: final-video.mp4 (2x scale, 10 Mbps bitrate)
```

## Technical Details

### Video Specifications

- **Codec**: H.264 High Profile
- **Format**: MP4 container
- **Color Space**: sRGB
- **Frame Rate**: Matches original Lottie animation
- **Resolution**: Based on original animation size × scale factor

### Performance

The tool renders frame-by-frame to ensure accurate representation of the original Lottie animation. Progress is displayed during rendering with dots indicating every 10 frames processed.

### Dependencies

- **Lottie**: For parsing and rendering Lottie animations
- **AVFoundation**: For video encoding and file writing
- **AppKit**: For macOS-specific rendering operations
- **ArgumentParser**: For command-line interface

## Troubleshooting

### Common Issues

**"Could not load Lottie file"**
- Ensure the input file is a valid Lottie JSON file
- Check that the file path is correct
- Verify the file is not corrupted

**"Could not create AVAssetWriter"**
- Ensure the output directory exists
- Check write permissions for the output location
- Verify sufficient disk space

**Rendering appears stuck**
- Large animations may take significant time
- Wait for progress dots to indicate ongoing rendering
- Complex animations with many elements will render slower

### Performance Tips

- Use lower scale factors for faster rendering
- Consider reducing bitrate for smaller file sizes
- Complex animations with many layers will take longer to render

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License

Copyright (c) 2025 Alex Baryzhikov

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
