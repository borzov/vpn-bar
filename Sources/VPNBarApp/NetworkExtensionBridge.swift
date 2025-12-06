import Foundation
import SystemConfiguration

/// Обертка для приватных C API из `libsystem_networkextension.dylib`.
typealias ne_session_t = OpaquePointer
typealias ne_session_status_t = Int32
typealias ne_session_event_t = Int32

let NESessionTypeVPN: Int32 = 1

@_silgen_name("ne_session_create")
func ne_session_create(_ serviceID: UnsafePointer<uuid_t>, _ sessionConfigType: Int32) -> ne_session_t?

@_silgen_name("ne_session_release")
func ne_session_release(_ session: ne_session_t)

@_silgen_name("ne_session_start")
func ne_session_start(_ session: ne_session_t)

@_silgen_name("ne_session_stop")
func ne_session_stop(_ session: ne_session_t)

@_silgen_name("ne_session_cancel")
func ne_session_cancel(_ session: ne_session_t)

typealias ne_session_set_event_handler_block = @convention(block) (ne_session_event_t, UnsafeMutableRawPointer?) -> Void

@_silgen_name("ne_session_set_event_handler")
func ne_session_set_event_handler(_ session: ne_session_t, _ queue: DispatchQueue, _ block: @escaping ne_session_set_event_handler_block)

typealias ne_session_get_status_block = @convention(block) (ne_session_status_t) -> Void

@_silgen_name("ne_session_get_status")
func ne_session_get_status(_ session: ne_session_t, _ queue: DispatchQueue, _ block: @escaping ne_session_get_status_block)

@_silgen_name("SCNetworkConnectionGetStatusFromNEStatus")
func SCNetworkConnectionGetStatusFromNEStatus(_ status: ne_session_status_t) -> SCNetworkConnectionStatus