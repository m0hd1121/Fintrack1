import Foundation
import Network

@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.fintrack.network", qos: .utility)

    var isConnected = true
    var connectionType: ConnectionType = .wifi

    enum ConnectionType: String {
        case wifi     = "Wi-Fi"
        case cellular = "Cellular"
        case ethernet = "Ethernet"
        case unknown  = "Unknown"

        var icon: String {
            switch self {
            case .wifi:     return "wifi"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .ethernet: return "cable.connector"
            case .unknown:  return "network"
            }
        }
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .ethernet
                } else {
                    self?.connectionType = .unknown
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
