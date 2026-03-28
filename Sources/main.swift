import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusBarController()
    }
}

final class StatusBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let monitor = NetworkMonitor()
    private let autoLaunchManager = AutoLaunchManager()
    private var autoLaunchMenuItem: NSMenuItem?

    init() {
        setupMenu()
        setupButton()

        monitor.onSpeedUpdate = { [weak self] upload, download in
            DispatchQueue.main.async {
                self?.updateTitle(upload: upload, download: download)
            }
        }
        monitor.start()
    }

    private func setupButton() {
        guard let button = statusItem.button else { return }
        if let cell = button.cell as? NSButtonCell {
            cell.wraps = false
            cell.usesSingleLineMode = true
            cell.lineBreakMode = .byClipping
        }
        updateTitle(upload: 0, download: 0)
    }

    private func setupMenu() {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "Network Monitor", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        let autoLaunchItem = NSMenuItem(title: "开机自启", action: #selector(toggleAutoLaunch), keyEquivalent: "")
        autoLaunchItem.target = self
        autoLaunchMenuItem = autoLaunchItem
        menu.addItem(autoLaunchItem)
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        refreshAutoLaunchMenuState()
        autoLaunchManager.applyCurrentSetting(startNow: false)
    }

    private func updateTitle(upload: UInt64, download: UInt64) {
        guard let button = statusItem.button else { return }

        let text = "↑\(ByteFormatter.speed(upload))/s ↓\(ByteFormatter.speed(download))/s"
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 0

        button.attributedTitle = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
                .paragraphStyle: paragraph
            ]
        )
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }

    @objc
    private func toggleAutoLaunch() {
        autoLaunchManager.isEnabled.toggle()
        autoLaunchManager.applyCurrentSetting(startNow: false)
        refreshAutoLaunchMenuState()
    }

    private func refreshAutoLaunchMenuState() {
        autoLaunchMenuItem?.state = autoLaunchManager.isEnabled ? .on : .off
    }
}

final class NetworkMonitor {
    private var timer: DispatchSourceTimer?
    private var previousSample = InterfaceSample(upload: 0, download: 0)
    private let queue = DispatchQueue(label: "network.monitor.timer")

    var onSpeedUpdate: ((UInt64, UInt64) -> Void)?

    func start() {
        previousSample = readSample()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let current = self.readSample()

            let upload = current.upload >= self.previousSample.upload ? current.upload - self.previousSample.upload : 0
            let download = current.download >= self.previousSample.download ? current.download - self.previousSample.download : 0

            self.previousSample = current
            self.onSpeedUpdate?(upload, download)
        }
        timer.resume()
        self.timer = timer
    }

    private func readSample() -> InterfaceSample {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else {
            return InterfaceSample(upload: 0, download: 0)
        }
        defer { freeifaddrs(addresses) }

        var upload: UInt64 = 0
        var download: UInt64 = 0
        var pointer = first

        while true {
            let interface = pointer.pointee

            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isRunning = (flags & IFF_RUNNING) == IFF_RUNNING
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK

            if isUp && isRunning && !isLoopback,
               let addr = interface.ifa_addr,
               addr.pointee.sa_family == UInt8(AF_LINK),
               let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self) {
                upload += UInt64(data.pointee.ifi_obytes)
                download += UInt64(data.pointee.ifi_ibytes)
            }

            if let next = interface.ifa_next {
                pointer = next
            } else {
                break
            }
        }

        return InterfaceSample(upload: upload, download: download)
    }
}

private struct InterfaceSample {
    let upload: UInt64
    let download: UInt64
}

enum ByteFormatter {
    private static let units = ["B", "KB", "MB", "GB", "TB"]

    static func speed(_ bytes: UInt64) -> String {
        if bytes == 0 { return "0B" }

        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if value >= 100 || unitIndex == 0 {
            return String(format: "%.0f%@", value, units[unitIndex])
        }
        return String(format: "%.1f%@", value, units[unitIndex])
    }
}

final class AutoLaunchManager {
    private let defaults = UserDefaults.standard
    private let key = "autoLaunchEnabled"
    private let launchAgentLabel = "com.zyg.networkmonitor"

    var isEnabled: Bool {
        get {
            if defaults.object(forKey: key) == nil {
                defaults.set(true, forKey: key)
                return true
            }
            return defaults.bool(forKey: key)
        }
        set {
            defaults.set(newValue, forKey: key)
        }
    }

    func applyCurrentSetting(startNow: Bool) {
        if isEnabled {
            installLaunchAgent(startNow: startNow)
        } else {
            uninstallLaunchAgent()
        }
    }

    private func installLaunchAgent(startNow: Bool) {
        guard let executablePath = Bundle.main.executableURL?.path else { return }

        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(launchAgentLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executablePath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """

        do {
            let path = launchAgentPlistPath()
            try FileManager.default.createDirectory(
                at: path.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try plistContent.write(to: path, atomically: true, encoding: .utf8)
            if startNow {
                runLaunchctl(arguments: ["bootstrap", "gui/\(getuid())", path.path])
            }
        } catch {
            // Ignore write failures to avoid affecting core network monitoring.
        }
    }

    private func uninstallLaunchAgent() {
        let path = launchAgentPlistPath()
        runLaunchctl(arguments: ["bootout", "gui/\(getuid())", path.path])
        try? FileManager.default.removeItem(at: path)
    }

    private func launchAgentPlistPath() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(launchAgentLabel).plist")
    }

    private func runLaunchctl(arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        try? process.run()
        process.waitUntilExit()
    }
}

@main
struct NetworkMonitorApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
