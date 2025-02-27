import CFrida

@objc(FridaRelay)
public class Relay: NSObject {
    internal let handle: OpaquePointer

    @objc
    init(address: String, username: String, password: String, kind: RelayKind) {
        self.handle = frida_relay_new(address, username, password, FridaRelayKind(kind.rawValue))

        super.init()
    }

    private init(handle: OpaquePointer) {
        self.handle = handle

        super.init()
    }

    @objc
    public func copy(with zone: NSZone?) -> Any {
        g_object_ref(gpointer(handle))
        return Relay(handle: handle)
    }

    deinit {
        g_object_unref(gpointer(handle))
    }

    @objc
    public var address: String {
        return String(cString: frida_relay_get_address(handle))
    }

    @objc
    public var username: String {
        return String(cString: frida_relay_get_username(handle))
    }

    @objc
    public var password: String {
        return String(cString: frida_relay_get_password(handle))
    }

    @objc
    public var kind: RelayKind {
        return RelayKind(rawValue: frida_relay_get_kind(handle).rawValue)!
    }

    @objc
    public override var description: String {
        return "Frida.Relay(address: \"\(address)\", username: \"\(username)\", password: \"\(password)\", kind: \(kind))"
    }

    @objc
    public override func isEqual(_ object: Any?) -> Bool {
        if let relay = object as? Relay {
            return relay.handle == handle
        } else {
            return false
        }
    }

    @objc
    public override var hash: Int {
        return handle.hashValue
    }
}

@objc(FridaRelayKind)
public enum RelayKind: UInt32, CustomStringConvertible {
    case turnUdp
    case turnTcp
    case turnTls

    public var description: String {
        switch self {
        case .turnUdp: return "turnUdp"
        case .turnTcp: return "turnTcp"
        case .turnTls: return "turnTls"
        }
    }
}
