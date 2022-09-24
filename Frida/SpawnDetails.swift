import CFrida

@objc(FridaSpawnDetails)
public class SpawnDetails: NSObject, NSCopying {
    private let handle: OpaquePointer

    init(handle: OpaquePointer) {
        self.handle = handle
    }

    @objc
    public func copy(with zone: NSZone?) -> Any {
        g_object_ref(gpointer(handle))
        return SpawnDetails(handle: handle)
    }

    deinit {
        g_object_unref(gpointer(handle))
    }

    @objc(processIdentifier)
    public var pid: UInt {
        return UInt(frida_spawn_get_pid(handle))
    }

    @objc
    public var identifier: String? {
        if let rawIdentifier = frida_spawn_get_identifier(handle) {
            return String(cString: rawIdentifier)
        }
        return nil
    }

    @objc
    public override var description: String {
        if let identifier = self.identifier {
            return "Frida.SpawnDetails(pid: \(pid), identifier: \"\(identifier)\")"
        } else {
            return "Frida.SpawnDetails(pid: \(pid))"
        }
    }

    @objc
    public override func isEqual(_ object: Any?) -> Bool {
        if let details = object as? SpawnDetails {
            return details.handle == handle
        } else {
            return false
        }
    }

    @objc
    public override var hash: Int {
        return handle.hashValue
    }
}
