# URL Analysis

A professional-grade native macOS application for analyzing web page performance with detailed network waterfall visualization, Core Web Vitals tracking, and comprehensive performance scoring. Built with Swift and SwiftUI.

![Platform](https://img.shields.io/badge/platform-macOS%2013.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)
![Version](https://img.shields.io/badge/version-1.3.0-brightgreen)

## Features

### 🤖 AI-Powered Analysis (NEW in v1.3.0)
URL Analysis now includes **6 AI-powered features** for deep insights beyond rule-based analysis:

#### 1. AI Performance Insights 💡
- Natural language explanations of performance issues
- Context-aware analysis: "Your page loads slowly because of 3 large uncompressed images from cdn.example.com"
- Identifies root causes, not just symptoms
- Actionable advice in plain English

#### 2. AI Security Analysis 🔒
- Detects suspicious URLs and phishing patterns
- Identifies malware indicators in network traffic
- Analyzes redirect chains for security risks
- Flags potentially malicious third-party scripts
- Risk scoring: Safe/Low/Medium/High/Critical

#### 3. AI Optimization Coach 🚀
- Detailed, context-specific optimization advice
- Goes beyond generic suggestions with specific examples
- "The largest image (hero.jpg, 2.3MB) should be converted to WebP and lazy-loaded"
- Implementation guidance with code examples
- Prioritization with reasoning

#### 4. AI Technology Stack Detection 🔧
- Automatically identifies frameworks and libraries from network traffic
- Detects: React, Vue, Angular, Next.js, WordPress, Shopify, and more
- Identifies analytics tools, CDNs, hosting providers
- Example: "This site uses React 18.2, Next.js, Tailwind CSS, and Vercel hosting"

#### 5. AI Privacy Impact Analysis 🛡️
- Explains what trackers are actually doing
- Privacy scoring (0-100, 100 = best privacy)
- "Google Analytics is collecting: page views, user interactions, device info, approximate location"
- Identifies data being collected and potential risks
- Privacy recommendations

#### 6. AI Q&A Interface 💬
- Ask questions about the loaded page in natural language
- Example questions:
  - "Why is LCP so high?"
  - "What's causing the layout shift?"
  - "Is this URL safe?"
  - "What data is being collected?"
  - "How can I improve the performance score?"
- Context-aware answers based on actual network data

#### AI Backend Options
URL Analysis supports **3 AI backends** - choose what works best for your setup:

- **Ollama** - Fast GPU-accelerated (localhost:11434)
  - Setup: `brew install ollama && ollama serve && ollama pull llama2`

- **TinyLLM** by Jason Cox - Lightweight Docker-based (localhost:8000)
  - Setup: `git clone https://github.com/jasonacox/TinyLLM && cd TinyLLM && docker-compose up -d`
  - Project: https://github.com/jasonacox/TinyLLM

- **MLX Toolkit** - Python-based Apple Silicon optimization
  - Setup: `pip install mlx-lm`

- **Auto Mode** - Automatically selects best available backend

**Access AI Features:** Load a page → Click "🤖 AI Analysis" tab → Click "Run Full AI Analysis"

All AI processing happens **100% locally** - no data leaves your machine.

---

### 📊 Performance Budgets (v1.2.0)
- **Automatic Budget Enforcement**: Set thresholds and get instant alerts
- **Visual Alerts**: Red/orange banners when budgets exceeded
- **7 Metrics Tracked**: Load time, size, requests, score, LCP, CLS, FID
- **Quick Presets**: Mobile Fast, Desktop Standard, PWA
- **Severity Levels**: Critical, Warning, Minor with color-coding
- **Real-time Checking**: Violations detected immediately after load

### 💡 Optimization Suggestions (NEW in v1.2.0)
- **Automatic Analysis**: Detects 8 categories of performance issues
- **Prioritized List**: Sorted by impact (critical first) and difficulty
- **Estimated Savings**: Quantified potential improvements
- **Actionable Recommendations**: Specific steps to fix each issue
- **Categories**: Compression, Images, Caching, Render Blocking, JavaScript, CSS, Fonts, Connections
- **Impact + Difficulty**: Know what to fix first (high impact + easy = quick wins)

### 🌐 Third-Party Analysis (NEW in v1.2.0)
- **Domain Grouping**: All resources organized by domain
- **Provider Identification**: Auto-detects 20+ common third-party providers
- **Impact Calculation**: High/Medium/Low rating per domain
- **Category Tags**: Analytics, Advertising, Social Media, CDN, Fonts, Maps, Video, Tag Management
- **Cost Breakdown**: See duration, size, and request count per provider
- **Sorting Options**: By duration, size, or requests
- **First-Party Filtering**: Toggle to show only third-party resources

## Core Features

### 📊 Performance Score Card (NEW in v1.1.0)
- **0-100 Performance Score**: Single metric summarizing overall page performance
- **Category Breakdown**: Load time, resource count, size, and Web Vitals
- **Color-Coded Ratings**: Green (excellent), Orange (needs improvement), Red (poor)
- **Actionable Recommendations**: Specific advice for each category
- **Real-time Updates**: Score recalculates as resources load

### 🚀 Core Web Vitals (NEW in v1.1.0)
- **LCP (Largest Contentful Paint)**: Loading performance metric
- **CLS (Cumulative Layout Shift)**: Visual stability metric
- **FID (First Input Delay)**: Interactivity metric
- **Google Standards**: Thresholds aligned with Google Search ranking factors
- **Automatic Capture**: Uses browser's native Performance Observer API

### 🚫 Request Blocking (NEW in v1.1.0)
- **Quick Profiles**: One-click blocking for ads/trackers, images, or scripts
- **Custom Blocking**: Block specific domains or resource types
- **Performance Impact**: See how page performs without blocked resources
- **WKContentRuleList**: Native WebKit blocking (efficient and fast)

### 📸 Screenshot Timeline (NEW in v1.1.0)
- **Visual Filmstrip**: Automatic screenshots at 0s, 0.5s, 1s, 2s, 3s, 5s
- **Rendering Progress**: See exactly when content appears
- **Timeline Correlation**: Match visual changes with network activity
- **User Experience**: Understand what users actually see during load

### 🔄 Multiple URL Comparison (NEW in v1.1.0)
- **Up to 4 URLs**: Load and compare multiple sites simultaneously
- **Tab Interface**: Easy switching between URLs
- **Comparison View**: Side-by-side metrics table
- **Benchmarking**: Compare against competitors or test variants

## Core Features

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

1. **Enter a URL**: Type or paste URL, or click ⭐ for quick presets
2. **Load the page**: Click "Load" or press Return
3. **Wait 5-7 seconds**: For complete analysis (resources, vitals, suggestions)
4. **Review Results**:
   - **Toolbar**: Check for red/orange budget alerts
   - **Waterfall tab**: Network timing visualization
   - **Performance tab**: Overall score (0-100)
   - **Web Vitals tab**: LCP, CLS, FID metrics
   - **Optimize tab**: Prioritized fix suggestions
   - **3rd Party tab**: External dependency costs
   - **Budgets tab**: Budget compliance details
5. **Export**: Click "Export HAR" to save analysis

### Optimization Workflow

1. **Load your site** → Note budget violations in toolbar
2. **Click "Optimize" tab** → See prioritized suggestions
3. **Start with Critical/Easy** → Quick wins first
4. **Check "3rd Party" tab** → Identify external bottlenecks
5. **Implement fixes** → Make changes to your site
6. **Reload and verify** → Confirm improvements
7. **Adjust budgets** → Set targets for your team

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

- **macOS Only**: Not available for iOS/iPadOS (intentional - desktop tool)
- **Throttling Accuracy**: Simulated throttling is approximate, not hardware-level
- **WebSocket Inspection**: Limited support for WebSocket connections
- **FID Measurement**: Requires user interaction to capture (click or keyboard input)

## What's New in v1.3.0

- ✅ **AI-Powered Analysis** with 6 intelligent features
- ✅ **AI Performance Insights** - Natural language explanations
- ✅ **AI Security Analysis** - Threat and phishing detection
- ✅ **AI Optimization Coach** - Detailed advice with code examples
- ✅ **AI Technology Stack Detection** - Framework identification
- ✅ **AI Privacy Impact Analysis** - Tracker analysis and privacy scoring
- ✅ **AI Q&A Interface** - Ask questions about the page
- ✅ **Multi-Backend Support** - Ollama, TinyLLM (by Jason Cox), MLX Toolkit
- ✅ **100% Local AI** - No cloud, complete privacy

## What's New in v1.2.0

- ✅ **Performance Budgets** with automatic violation detection
- ✅ **Optimization Suggestions** (8 categories, auto-prioritized)
- ✅ **Third-Party Analysis** with provider identification
- ✅ Budget alert banner in toolbar
- ✅ Quick URL presets menu (⭐)
- ✅ Improved URL field with X button

## What's New in v1.1.0

- ✅ Performance Score Card (0-100 scoring system)
- ✅ Core Web Vitals tracking (LCP, CLS, FID)
- ✅ Request blocking (ads, trackers, resource types)
- ✅ Screenshot timeline (visual rendering progress)
- ✅ Multiple URL comparison (up to 4 sites)

## Roadmap

- [✅] **AI-powered analysis** (DONE in v1.3.0)
- [ ] AI-powered automatic optimization recommendations
- [ ] AI-generated performance reports with insights
- [ ] Custom throttling profiles with presets
- [ ] Request replay from HAR files
- [ ] WebSocket detailed inspection
- [ ] Historical performance tracking
- [ ] Dark mode support
- [ ] Keyboard shortcuts for common actions
- [✅] **Export performance reports to PDF** (DONE in v1.2.0)
- [ ] API/CLI mode for automation
- [ ] AI comparison mode (compare multiple URLs with AI insights)

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
- **TinyLLM by Jason Cox** (https://github.com/jasonacox/TinyLLM) - AI backend option
- **Ollama AI** (https://ollama.com) - AI backend option
- **Apple MLX** (https://github.com/ml-explore/mlx) - AI backend option

## Support

If you encounter any issues or have questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Search existing [GitHub Issues](https://github.com/kochj23/URL-Analysis/issues)
3. Open a new issue with detailed information

---

**Built with ❤️ for web performance analysis**
