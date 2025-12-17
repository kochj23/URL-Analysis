# URL Analysis

A native macOS application for analyzing web page performance with detailed network waterfall visualization. Built with Swift and SwiftUI.

![Platform](https://img.shields.io/badge/platform-macOS%2013.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

### 🌊 Waterfall Visualization
- **Detailed Timing Breakdown**: DNS lookup, TCP connection, SSL/TLS handshake, TTFB, and content download
- **HAR-Compatible Format**: Industry-standard HTTP Archive (HAR) 1.2 specification
- **Color-Coded Phases**: Visual representation of each timing phase
  - Purple: DNS Resolution
  - Orange: TCP Connection
  - Pink: SSL/TLS Handshake
  - Green: Waiting (Time To First Byte)
  - Blue: Content Download

### 🔍 Resource Filtering
- **Filter by Resource Type**: Documents, Stylesheets, Scripts, Images, Fonts, XHR/Fetch, Media
- **Domain Filtering**: Focus on specific domains
- **Search by URL**: Quick text-based filtering
- **Size and Duration Filters**: Find performance bottlenecks

### 🌐 Network Throttling
- **Built-in Presets**:
  - Slow 3G (400 Kbps)
  - Fast 3G (1.6 Mbps)
  - Slow 4G (3 Mbps)
  - Fast 4G (10 Mbps)
- **Realistic Latency Simulation**: Emulates real-world network conditions

### 📊 HAR Export
- Export complete network analysis to HAR format
- Compatible with Chrome DevTools, Firefox, and other HAR-compatible tools
- Share performance data with team members

### 🔬 Resource Inspector
- **Headers Tab**: View all request and response headers
- **Timing Tab**: Detailed breakdown of each timing phase
- **Request Tab**: Inspect HTTP method, URL, and request body
- **Response Tab**: Preview response body and metadata

### 📈 Performance Metrics
- Total page load time
- Number of requests
- Total data transferred
- Per-resource timing and size information

## Installation

### Requirements
- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building from source)

### Building from Source

1. **Clone the repository**:
   ```bash
   git clone https://github.com/kochj23/URL-Analysis.git
   cd URL-Analysis
   ```

2. **Open in Xcode**:
   ```bash
   open URL-Analysis.xcodeproj
   ```

3. **Build and run**:
   - Select the "URL Analysis" scheme
   - Press `⌘R` to build and run
   - Or use Product → Run from the menu

4. **Archive for distribution** (optional):
   ```bash
   xcodebuild -project URL-Analysis.xcodeproj \
     -scheme "URL Analysis" \
     -configuration Release \
     -archivePath ~/Desktop/URL-Analysis.xcarchive \
     archive
   ```

## Usage

### Basic Workflow

1. **Enter a URL**: Type or paste the URL you want to analyze in the top address bar
2. **Load the page**: Click "Load" or press Return
3. **Analyze the waterfall**: View all network resources in the waterfall panel on the right
4. **Inspect resources**: Click any resource to see detailed information in the inspector panel
5. **Export results**: Click "Export HAR" to save the analysis for later review or sharing

### Filtering Resources

1. Click the **Filter** button in the waterfall toolbar
2. Toggle resource types on/off (Documents, Scripts, Images, etc.)
3. Select specific domains to focus on
4. Use the search field to filter by URL

### Network Throttling

1. Select a throttling preset from the dropdown in the waterfall toolbar
2. Reload the page to see how it performs under constrained network conditions
3. Use this to test performance for users on slower connections

### Understanding the Waterfall

Each horizontal bar represents a network request with color-coded phases:
- **Purple**: DNS Resolution - Time to resolve the domain name to an IP address
- **Orange**: TCP Connection - Time to establish a TCP connection
- **Pink**: SSL/TLS - Time for SSL/TLS handshake (HTTPS only)
- **Green**: Waiting (TTFB) - Time waiting for the first byte of response
- **Blue**: Content Download - Time to download the response body

The position of each bar shows when the request started relative to page load.

## Technical Details

### Architecture

- **SwiftUI**: Modern declarative UI framework
- **WKWebView**: Apple's WebKit engine for rendering web pages
- **Custom URLProtocol**: Network interception for timing capture
- **HAR Format**: Standard HTTP Archive format for data export
- **MVVM Pattern**: Clean separation of UI and business logic

### Security

- **App Sandbox**: Enabled for security
- **Network Client Access**: Required entitlement for web access
- **File Access**: User-selected read/write for HAR export

### Performance

- Minimal overhead on network requests
- Efficient memory usage with streaming response capture
- Non-blocking UI with async/await patterns

## Troubleshooting

### Issue: Network requests not appearing

**Solution**: Ensure the app has network access permissions. Check System Settings → Privacy & Security → Network.

### Issue: Export HAR fails

**Solution**: Make sure you've granted the app permission to save files. Try selecting a different save location.

### Issue: Throttling doesn't seem to work

**Solution**: Network throttling is simulated at the application level. Some requests may bypass throttling. For more accurate throttling, use macOS Network Link Conditioner.

## Limitations

- **Single Session**: Currently supports one URL analysis at a time
- **macOS Only**: Not available for iOS/iPadOS
- **Throttling Accuracy**: Simulated throttling is approximate, not hardware-level
- **WebSocket Inspection**: Limited support for WebSocket connections

## Roadmap

- [ ] Support for multiple tabs/sessions
- [ ] Performance score calculation
- [ ] Custom throttling profiles
- [ ] Request replay functionality
- [ ] WebSocket detailed inspection
- [ ] Screenshot capture during page load
- [ ] Compare multiple page loads
- [ ] Dark mode support
- [ ] Keyboard shortcuts for common actions

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

**Jordan Koch**
- GitHub: [@kochj23](https://github.com/kochj23)

## Acknowledgments

- Inspired by Chrome DevTools Network Panel
- HAR specification: http://www.softwareishard.com/blog/har-12-spec/
- Built with Apple's WebKit and SwiftUI frameworks

## Support

If you encounter any issues or have questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Search existing [GitHub Issues](https://github.com/kochj23/URL-Analysis/issues)
3. Open a new issue with detailed information

---

**Built with ❤️ for web performance analysis**
