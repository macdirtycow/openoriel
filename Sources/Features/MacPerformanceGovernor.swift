import Foundation
import Observation
import WebKit
#if os(macOS)
import AppKit
#endif

/// Mac performance governors that act on Oriel-managed WebKit resources.
/// Honest scope: tab pool, JS timer throttle, memory-pressure hibernation — not a fake OS CPU %.
@Observable
@MainActor
final class MacPerformanceGovernor {
    enum CPULevel: Int, CaseIterable, Identifiable, Codable, Sendable {
        case off = 0
        case balanced = 40
        case strict = 70
        case max = 90

        var id: Int { rawValue }

        var displayName: String {
            switch self {
            case .off: "Off"
            case .balanced: "Balanced"
            case .strict: "Strict"
            case .max: "Max"
            }
        }

        /// Multiplier applied to setTimeout / rAF pacing (higher = slower timers).
        var timerStretch: Double {
            switch self {
            case .off: 1.0
            case .balanced: 1.35
            case .strict: 1.9
            case .max: 2.6
            }
        }
    }

    enum RAMLevel: Int, CaseIterable, Identifiable, Codable, Sendable {
        case off = 0
        case relaxed = 1
        case balanced = 2
        case strict = 3

        var id: Int { rawValue }

        var displayName: String {
            switch self {
            case .off: "Off"
            case .relaxed: "Relaxed"
            case .balanced: "Balanced"
            case .strict: "Strict"
            }
        }

        var softWebViewLimit: Int? {
            switch self {
            case .off: nil
            case .relaxed: 10
            case .balanced: 6
            case .strict: 4
            }
        }
    }

    var cpuLevel: CPULevel {
        didSet {
            UserDefaults.standard.set(cpuLevel.rawValue, forKey: cpuKey)
            applyCPUThrottleToActiveTabs()
        }
    }

    var ramLevel: RAMLevel {
        didSet {
            UserDefaults.standard.set(ramLevel.rawValue, forKey: ramKey)
            applyRAMPolicy()
        }
    }

    private(set) var memoryPressureLabel: String = "Normal"
    private(set) var lastHibernateReason: String?

    private let cpuKey = "oriel.macGovernor.cpu"
    private let ramKey = "oriel.macGovernor.ram"
    private var pressureSource: DispatchSourceMemoryPressure?
    private weak var environment: AppEnvironment?

    init() {
        let cpuRaw = UserDefaults.standard.object(forKey: cpuKey) as? Int
        cpuLevel = CPULevel(rawValue: cpuRaw ?? CPULevel.off.rawValue) ?? .off
        let ramRaw = UserDefaults.standard.object(forKey: ramKey) as? Int
        ramLevel = RAMLevel(rawValue: ramRaw ?? RAMLevel.off.rawValue) ?? .off
    }

    func attach(environment: AppEnvironment) {
        self.environment = environment
        startMemoryPressureMonitor()
        applyRAMPolicy()
        applyCPUThrottleToActiveTabs()
    }

    func applyCPUThrottleToActiveTabs() {
        guard let environment else { return }
        let script = Self.cpuThrottleScript(stretch: cpuLevel.timerStretch, enabled: cpuLevel != .off)
        for tab in environment.tabs.tabs {
            tab.webView?.evaluateJavaScript(script, completionHandler: nil)
        }
    }

    func applyCPUThrottle(to webView: WKWebView?) {
        guard let webView else { return }
        let script = Self.cpuThrottleScript(stretch: cpuLevel.timerStretch, enabled: cpuLevel != .off)
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func applyRAMPolicy() {
        guard let environment else { return }
        if let limit = ramLevel.softWebViewLimit {
            // Respect Pulse limit when stricter.
            let pulseLimit = environment.settings.edition.isPulse
                ? environment.settings.pulseWebViewLimit
                : 12
            WebViewPool.shared.softLimit = min(limit, pulseLimit)
        } else {
            environment.settings.refreshPulsePoolLimitPublic()
        }
    }

    func hibernateUnderPressure(force: Bool = false) {
        guard let environment else { return }
        guard force || ramLevel != .off else { return }
        lastHibernateReason = force ? "Manual" : "Memory pressure (\(memoryPressureLabel))"
        environment.hibernateBackgroundTabs()
        applyRAMPolicy()
    }

    // MARK: - Memory pressure

    private func startMemoryPressureMonitor() {
        #if os(macOS)
        pressureSource?.cancel()
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical, .normal],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let event = source.data
            if event.contains(.critical) {
                self.memoryPressureLabel = "Critical"
                if self.ramLevel != .off {
                    self.hibernateUnderPressure()
                }
            } else if event.contains(.warning) {
                self.memoryPressureLabel = "Warning"
                if self.ramLevel == .strict || self.ramLevel == .balanced {
                    self.hibernateUnderPressure()
                }
            } else {
                self.memoryPressureLabel = "Normal"
            }
        }
        source.resume()
        pressureSource = source
        #else
        memoryPressureLabel = "Unavailable"
        #endif
    }

    static func cpuThrottleScript(stretch: Double, enabled: Bool) -> String {
        if !enabled {
            return """
            (function(){
              if (window.__orielCPURestore) { try { window.__orielCPURestore(); } catch(e) {} }
              window.__orielCPURestore = null;
              window.__orielCPUThrottle = false;
              return true;
            })();
            """
        }
        let factor = max(1.0, stretch)
        return """
        (function(){
          if (window.__orielCPUThrottle) {
            window.__orielCPUStretch = \(factor);
            return true;
          }
          window.__orielCPUThrottle = true;
          window.__orielCPUStretch = \(factor);
          var _st = window.setTimeout.bind(window);
          var _si = window.setInterval.bind(window);
          var _raf = window.requestAnimationFrame.bind(window);
          window.setTimeout = function(fn, ms) {
            var wait = (typeof ms === 'number' ? ms : 0) * window.__orielCPUStretch;
            return _st(fn, wait);
          };
          window.setInterval = function(fn, ms) {
            var wait = (typeof ms === 'number' ? ms : 0) * window.__orielCPUStretch;
            return _si(fn, wait);
          };
          window.requestAnimationFrame = function(fn) {
            return _raf(function(t) {
              _st(function(){ fn(t); }, 8 * (window.__orielCPUStretch - 1));
            });
          };
          window.__orielCPURestore = function() {
            window.setTimeout = _st;
            window.setInterval = _si;
            window.requestAnimationFrame = _raf;
          };
          return true;
        })();
        """
    }
}
