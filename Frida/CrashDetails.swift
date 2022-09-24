import CFrida

@objc(FridaCrashDetails)
public class CrashDetails: NSObject, NSCopying {
    private let handle: OpaquePointer

    init(handle: OpaquePointer) {
        self.handle = handle
    }

    @objc
    public func copy(with zone: NSZone?) -> Any {
        g_object_ref(gpointer(handle))
        return CrashDetails(handle: handle)
    }

    deinit {
        g_object_unref(gpointer(handle))
    }

    @objc(processIdentifier)
    public var pid: UInt {
        return UInt(frida_crash_get_pid(handle))
    }

    @objc
    public var processName: String {
        return String(cString: frida_crash_get_process_name(handle))
    }

    @objc
    public var summary: String {
        return String(cString: frida_crash_get_summary(handle))
    }

    @objc
    public var report: String {
        return String(cString: frida_crash_get_report(handle))
    }

    @objc
    public lazy var parameters: [String: Any] = {
        return Marshal.dictionaryFromParametersDict(frida_crash_get_parameters(handle))
    }()

    @objc
    public override var description: String {
        return "Frida.CrashDetails(pid: \(pid), processName: \"\(processName)\", summary: \"\(summary)\")"
    }

    @objc
    public override func isEqual(_ object: Any?) -> Bool {
        if let details = object as? CrashDetails {
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
