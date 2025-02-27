import CFrida

@objc(FridaPortalMembership)
public class PortalMembership: NSObject, NSCopying {
    public typealias TerminateComplete = (_ result: TerminateResult) -> Void
    public typealias TerminateResult = () throws -> Bool

    private let handle: OpaquePointer

    init(handle: OpaquePointer) {
        self.handle = handle

        super.init()
    }

    @objc
    public func copy(with zone: NSZone?) -> Any {
        g_object_ref(gpointer(handle))
        return PortalMembership(handle: handle)
    }

    deinit {
        let h = gpointer(handle)
        Runtime.scheduleOnFridaThread {
            g_object_unref(h)
        }
    }

    @objc
    public override var description: String {
        return "Frida.PortalMembership()"
    }

    @objc
    public override func isEqual(_ object: Any?) -> Bool {
        if let membership = object as? PortalMembership {
            return membership.handle == handle
        } else {
            return false
        }
    }

    @objc
    public override var hash: Int {
        return handle.hashValue
    }

    @objc
    public func terminateAsync(completionHandler: @escaping (Bool, NSError?) -> Void) {
        terminate { resultCallback in
            do {
                completionHandler(try resultCallback(), nil)
            } catch {
                completionHandler(false, error as NSError)
            }
        }
    }
    
    public func terminate(_ completionHandler: @escaping TerminateComplete = { _ in }) {
        Runtime.scheduleOnFridaThread {
            frida_portal_membership_terminate(self.handle, nil, { source, result, data in
                let operation = Unmanaged<AsyncOperation<TerminateComplete>>.fromOpaque(data!).takeRetainedValue()

                var rawError: UnsafeMutablePointer<GError>? = nil
                frida_portal_membership_terminate_finish(OpaquePointer(source), result, &rawError)
                if let rawError = rawError {
                    let error = Marshal.takeNativeError(rawError)
                    Runtime.scheduleOnMainThread {
                        operation.completionHandler { throw error }
                    }
                    return
                }

                Runtime.scheduleOnMainThread {
                    operation.completionHandler { true }
                }
            }, Unmanaged.passRetained(AsyncOperation<TerminateComplete>(completionHandler)).toOpaque())
        }
    }
}
