# NetworkScanner

Add this to Info.plist:

```xml
    <key>NSBonjourServices</key>
    <array>
        <string>_airplay._tcp</string>
        <string>_apple-mobdev2._tcp</string>
        <string>_googlecast._tcp</string>
    </array>
    <key>NSLocalNetworkUsageDescription</key>
    <string>We need access to search devices in local network</string>
```
