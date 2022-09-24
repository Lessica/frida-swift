import Foundation

@objc(FridaSessionDelegate)
public protocol SessionDelegate {
    @objc func session(_ session: Session, didDetach reason: SessionDetachReason, crash: CrashDetails?)
}
