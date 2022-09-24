import CFrida

@objc(FridaDeviceManager)
public class DeviceManager: NSObject, NSCopying {
    
    @objc
    public weak var delegate: DeviceManagerDelegate?

    public typealias CloseComplete = () -> Void

    public typealias EnumerateDevicesComplete = (_ result: EnumerateDevicesResult) -> Void
    public typealias EnumerateDevicesResult = () throws -> [Device]

    public typealias AddRemoteDeviceComplete = (_ result: AddRemoteDeviceResult) -> Void
    public typealias AddRemoteDeviceResult = () throws -> Device

    public typealias RemoveRemoteDeviceComplete = (_ result: RemoveRemoteDeviceResult) -> Void
    public typealias RemoveRemoteDeviceResult = () throws -> Bool

    private typealias AddedHandler = @convention(c) (_ manager: OpaquePointer, _ device: OpaquePointer, _ userData: gpointer) -> Void
    private typealias RemovedHandler = @convention(c) (_ manager: OpaquePointer, _ device: OpaquePointer, _ userData: gpointer) -> Void
    private typealias ChangedHandler = @convention(c) (_ manager: OpaquePointer, _ userData: gpointer) -> Void

    private let handle: OpaquePointer
    private var onChangedHandler: gulong = 0
    private var onAddedHandler: gulong = 0
    private var onRemovedHandler: gulong = 0

    @objc
    public convenience override init() {
        frida_init()

        self.init(handle: frida_device_manager_new())
    }
    
    @objc
    public static var sharedManager = DeviceManager()
    
    @objc
    public static func inCurrentDevice(completionBlock: @escaping (Device?) -> Void) -> Void {
        sharedManager.enumerateDevices { resultCallback in
            if let devices = try? resultCallback() {
                completionBlock(devices.first)
            } else {
                completionBlock(nil)
            }
        }
    }
    
    private static var localhostDevice: Device?
    
    @objc
    public static func inLocalhostDevice(completionBlock: @escaping (Device?) -> Void) -> Void {
        if let localhostDevice = localhostDevice {
            completionBlock(localhostDevice)
            return
        }
        sharedManager.addRemoteDevice(address: "::1") { resultCallback in
            if let device = try? resultCallback() {
                localhostDevice = device
                completionBlock(device)
            } else {
                completionBlock(nil)
            }
        }
    }

    init(handle: OpaquePointer) {
        self.handle = handle

        super.init()

        let rawHandle = gpointer(handle)
        onAddedHandler = g_signal_connect_data(rawHandle, "added", unsafeBitCast(onAdded, to: GCallback.self),
                                               gpointer(Unmanaged.passRetained(SignalConnection(instance: self)).toOpaque()),
                                               releaseConnection, GConnectFlags(0))
        onRemovedHandler = g_signal_connect_data(rawHandle, "removed", unsafeBitCast(onRemoved, to: GCallback.self),
                                                 gpointer(Unmanaged.passRetained(SignalConnection(instance: self)).toOpaque()),
                                                 releaseConnection, GConnectFlags(0))
        onChangedHandler = g_signal_connect_data(rawHandle, "changed", unsafeBitCast(onChanged, to: GCallback.self),
                                                 gpointer(Unmanaged.passRetained(SignalConnection(instance: self)).toOpaque()),
                                                 releaseConnection, GConnectFlags(0))
    }

    @objc
    public func copy(with zone: NSZone?) -> Any {
        g_object_ref(gpointer(handle))
        return DeviceManager(handle: handle)
    }

    deinit {
        let rawHandle = gpointer(handle)
        let handlers = [onAddedHandler, onRemovedHandler, onChangedHandler]
        Runtime.scheduleOnFridaThread {
            for handler in handlers {
                g_signal_handler_disconnect(rawHandle, handler)
            }
            g_object_unref(rawHandle)
        }
    }

    @objc
    public override var description: String {
        return "Frida.DeviceManager()"
    }

    @objc
    public override func isEqual(_ object: Any?) -> Bool {
        if let manager = object as? DeviceManager {
            return manager.handle == handle
        } else {
            return false
        }
    }

    @objc
    public override var hash: Int {
        return handle.hashValue
    }

    @objc
    public func closeAsync(completionHandler: @escaping () -> Void) {
        close { completionHandler() }
    }
    
    public func close(_ completionHandler: @escaping CloseComplete = {}) {
        Runtime.scheduleOnFridaThread {
            frida_device_manager_close(self.handle, nil, { source, result, data in
                let operation = Unmanaged<AsyncOperation<CloseComplete>>.fromOpaque(UnsafeRawPointer(data)!).takeRetainedValue()

                frida_device_manager_close_finish(OpaquePointer(source), result, nil)

                Runtime.scheduleOnMainThread {
                    operation.completionHandler()
                }
            }, Unmanaged.passRetained(AsyncOperation<CloseComplete>(completionHandler)).toOpaque())
        }
    }
    
    @objc
    public func enumerateDevicesAsync(completionHandler: @escaping ([Device]?, NSError?) -> Void) {
        enumerateDevices { resultCallback in
            do {
                completionHandler(try resultCallback(), nil)
            } catch {
                completionHandler(nil, error as NSError)
            }
        }
    }

    public func enumerateDevices(_ completionHandler: @escaping EnumerateDevicesComplete) {
        Runtime.scheduleOnFridaThread {
            frida_device_manager_enumerate_devices(self.handle, nil, { source, result, data in
                let operation = Unmanaged<AsyncOperation<EnumerateDevicesComplete>>.fromOpaque(data!).takeRetainedValue()

                var rawError: UnsafeMutablePointer<GError>? = nil
                let rawDevices = frida_device_manager_enumerate_devices_finish(OpaquePointer(source), result, &rawError)
                if let rawError = rawError {
                    let error = Marshal.takeNativeError(rawError)
                    Runtime.scheduleOnMainThread {
                        operation.completionHandler { throw error }
                    }
                    return
                }

                var devices: [Device] = []
                let n = frida_device_list_size(rawDevices)
                for i in 0..<n {
                    let device = Device(handle: frida_device_list_get(rawDevices, i))
                    devices.append(device)
                }
                g_object_unref(gpointer(rawDevices))

                Runtime.scheduleOnMainThread {
                    operation.completionHandler { devices }
                }
            }, Unmanaged.passRetained(AsyncOperation<EnumerateDevicesComplete>(completionHandler)).toOpaque())
        }
    }
    
    @objc
    public func addRemoteDeviceAsync(address: String, certificate: String? = nil, origin: String? = nil, token: String? = nil,
                                     keepaliveInterval: Int, completionHandler: @escaping (Device?, NSError?) -> Void) {
        addRemoteDevice(address: address, certificate: certificate, origin: origin, token: token, keepaliveInterval: keepaliveInterval) { resultCallback in
            do {
                completionHandler(try resultCallback(), nil)
            } catch {
                completionHandler(nil, error as NSError)
            }
        }
    }

    public func addRemoteDevice(address: String, certificate: String? = nil, origin: String? = nil, token: String? = nil,
                                keepaliveInterval: Int? = nil, completionHandler: @escaping AddRemoteDeviceComplete = { _ in }) {
        Runtime.scheduleOnFridaThread {
            let options = frida_remote_device_options_new()
            defer {
                g_object_unref(gpointer(options))
            }

            if let certificate = certificate {
                do {
                    let rawCertificate = try Marshal.certificateFromString(certificate)
                    frida_remote_device_options_set_certificate(options, rawCertificate)
                    g_object_unref(rawCertificate)
                } catch let error {
                    Runtime.scheduleOnMainThread {
                        completionHandler { throw error }
                    }
                    return
                }
            }

            if let origin = origin {
                frida_remote_device_options_set_origin(options, origin)
            }

            if let token = token {
                frida_remote_device_options_set_token(options, token)
            }

            if let keepaliveInterval = keepaliveInterval {
                frida_remote_device_options_set_keepalive_interval(options, gint(keepaliveInterval))
            }

            frida_device_manager_add_remote_device(self.handle, address, options, nil, { source, result, data in
                let operation = Unmanaged<AsyncOperation<AddRemoteDeviceComplete>>.fromOpaque(data!).takeRetainedValue()

                var rawError: UnsafeMutablePointer<GError>? = nil
                let rawDevice = frida_device_manager_add_remote_device_finish(OpaquePointer(source), result, &rawError)
                if let rawError = rawError {
                    let error = Marshal.takeNativeError(rawError)
                    Runtime.scheduleOnMainThread {
                        operation.completionHandler { throw error }
                    }
                    return
                }

                let device = Device(handle: rawDevice!)

                Runtime.scheduleOnMainThread {
                    operation.completionHandler { device }
                }
            }, Unmanaged.passRetained(AsyncOperation<AddRemoteDeviceComplete>(completionHandler)).toOpaque())
        }
    }
    
    @objc
    public func removeRemoteDeviceAsync(address: String, completionHandler: @escaping (Bool, NSError?) -> Void) {
        removeRemoteDevice(address: address) { resultCallback in
            do {
                completionHandler(try resultCallback(), nil)
            } catch {
                completionHandler(false, error as NSError)
            }
        }
    }

    public func removeRemoteDevice(address: String, completionHandler: @escaping RemoveRemoteDeviceComplete = { _ in }) {
        Runtime.scheduleOnFridaThread {
            frida_device_manager_remove_remote_device(self.handle, address, nil, { source, result, data in
                let operation = Unmanaged<AsyncOperation<RemoveRemoteDeviceComplete>>.fromOpaque(data!).takeRetainedValue()

                var rawError: UnsafeMutablePointer<GError>? = nil
                frida_device_manager_remove_remote_device_finish(OpaquePointer(source), result, &rawError)
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
            }, Unmanaged.passRetained(AsyncOperation<RemoveRemoteDeviceComplete>(completionHandler)).toOpaque())
        }
    }

    private let onAdded: AddedHandler = { _, rawDevice, userData in
        let connection = Unmanaged<SignalConnection<DeviceManager>>.fromOpaque(userData).takeUnretainedValue()

        g_object_ref(gpointer(rawDevice))
        let device = Device(handle: rawDevice)

        if let manager = connection.instance {
            Runtime.scheduleOnMainThread {
                manager.delegate?.deviceManager?(manager, didAddDevice: device)
            }
        }
    }

    private let onRemoved: RemovedHandler = { _, rawDevice, userData in
        let connection = Unmanaged<SignalConnection<DeviceManager>>.fromOpaque(userData).takeUnretainedValue()

        g_object_ref(gpointer(rawDevice))
        let device = Device(handle: rawDevice)

        if let manager = connection.instance {
            Runtime.scheduleOnMainThread {
                manager.delegate?.deviceManager?(manager, didRemoveDevice: device)
            }
        }
    }

    private let onChanged: ChangedHandler = { _, userData in
        let connection = Unmanaged<SignalConnection<DeviceManager>>.fromOpaque(userData).takeUnretainedValue()

        if let manager = connection.instance {
            Runtime.scheduleOnMainThread {
                manager.delegate?.deviceManagerDidChangeDevices?(manager)
            }
        }
    }

    private let releaseConnection: GClosureNotify = { data, _ in
        Unmanaged<SignalConnection<DeviceManager>>.fromOpaque(data!).release()
    }
}
