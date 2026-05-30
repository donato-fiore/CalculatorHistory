import Foundation

@_cdecl("writeSwiftString")
func writeSwiftString(nsString: NSString, ptr: UnsafeMutableRawPointer) {
    ptr.assumingMemoryBound(to: String.self).pointee = String(nsString)
}

@_cdecl("swiftStringToNSString")
func swiftStringToNSString(ptr: UnsafeRawPointer) -> NSString {
    let swiftString = ptr.assumingMemoryBound(to: String.self).pointee
    return NSString(string: swiftString)
}
