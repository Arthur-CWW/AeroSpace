import Darwin
import Foundation

// Read the owning process, not the app's bundle ID: shared apps must never be
// classified just because a different instance was launched by an agent.
func isAgentProcess(_ pid: pid_t) -> Bool {
    var current = pid
    var visited = Set<pid_t>()
    while current > 1, visited.insert(current).inserted {
        guard let environment = readProcessEnvironment(current) else { return false }
        if environment.contains("AEROSPACE_AGENT=1") { return true }
        // SAFETY: Initialize the Darwin struct and use its exact ABI size for
        // the synchronous sysctl write; no pointer escapes the call.
        var info = unsafe kinfo_proc()
        let infoSize = unsafe MemoryLayout<kinfo_proc>.stride
        var size = infoSize
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, current]
        guard unsafe sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0,
              size == infoSize else { return false }
        // SAFETY: The successful sysctl filled the entire initialized struct.
        current = unsafe info.kp_eproc.e_ppid
    }
    return false
}

private func readProcessEnvironment(_ pid: pid_t) -> [String]? {
    var limitMib: [Int32] = [CTL_KERN, KERN_ARGMAX]
    var limit: Int32 = 0
    var limitSize = MemoryLayout<Int32>.size
    // SAFETY: Both output scalars have the sizes supplied to synchronous
    // sysctl, and the MIB count matches its array. No pointers escape.
    guard unsafe sysctl(&limitMib, UInt32(limitMib.count), &limit, &limitSize, nil, 0) == 0,
          limit >= Int32(MemoryLayout<Int32>.size) else { return nil }
    var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
    var size = Int(limit)
    var bytes = [UInt8](repeating: 0, count: size)
    let status = bytes.withUnsafeMutableBytes { buffer in
        // SAFETY: The allocated buffer is exactly the input byte capacity in
        // size, and its pointer remains valid for this synchronous call only.
        unsafe sysctl(&mib, UInt32(mib.count), buffer.baseAddress, &size, nil, 0)
    }
    guard status == 0 else { return nil }
    bytes.removeSubrange(size..<bytes.count)
    return agentEnvironmentFromProcArgs(bytes)
}

// KERN_PROCARGS2: argc, executable path, NUL padding, argc NUL-terminated
// arguments, then NUL-terminated environment entries. Reject truncated records.
func agentEnvironmentFromProcArgs(_ bytes: [UInt8]) -> [String]? {
    guard bytes.count >= MemoryLayout<Int32>.size else { return nil }
    // SAFETY: The preceding bound check guarantees a complete Int32; an
    // unaligned load is required because a byte array has no Int32 alignment.
    let argc = bytes.withUnsafeBytes { unsafe $0.loadUnaligned(as: Int32.self) }
    guard argc > 0 else { return nil }
    var cursor = MemoryLayout<Int32>.size
    func skipString() -> Bool {
        guard let end = bytes[cursor...].firstIndex(of: 0) else { return false }
        cursor = end + 1
        return true
    }
    guard skipString() else { return nil }
    while cursor < bytes.count, bytes[cursor] == 0 { cursor += 1 }
    for _ in 0..<argc {
        guard cursor < bytes.count, skipString() else { return nil }
    }
    var environment: [String] = []
    while cursor < bytes.count, bytes[cursor] != 0 {
        let start = cursor
        guard skipString(), let entry = String(bytes: bytes[start..<(cursor - 1)], encoding: .utf8) else { return nil }
        environment.append(entry)
    }
    return environment
}
