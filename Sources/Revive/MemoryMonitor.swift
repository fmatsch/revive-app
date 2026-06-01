import Foundation
import Darwin

struct MemoryStats {
    let totalGB: Double
    let usedGB: Double
    let freeGB: Double
    let cachedGB: Double
    let swapUsedGB: Double
    let swapTotalGB: Double

    var pressurePercent: Int { Int((usedGB / totalGB) * 100) }
    var swapPercent: Int {
        guard swapTotalGB > 0 else { return 0 }
        return Int((swapUsedGB / swapTotalGB) * 100)
    }

    var pressureEmoji: String {
        switch pressurePercent {
        case 0..<60: return "🟢"
        case 60..<80: return "🟡"
        default:      return "🔴"
        }
    }

    static func current() -> MemoryStats {
        let pageSize = Double(vm_page_size)
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPtr, &count)
            }
        }

        let totalBytes   = Double(ProcessInfo.processInfo.physicalMemory)
        let activeBytes  = Double(vmStats.active_count)   * pageSize
        let wiredBytes   = Double(vmStats.wire_count)      * pageSize
        let compBytes    = Double(vmStats.compressor_page_count) * pageSize
        let freeBytes    = Double(vmStats.free_count)      * pageSize
        let inactiveBytes = Double(vmStats.inactive_count) * pageSize

        let usedBytes    = activeBytes + wiredBytes + compBytes

        var xsw = xsw_usage()
        var xswSize = MemoryLayout<xsw_usage>.size
        sysctlbyname("vm.swapusage", &xsw, &xswSize, nil, 0)

        return MemoryStats(
            totalGB:     totalBytes        / 1_073_741_824,
            usedGB:      usedBytes         / 1_073_741_824,
            freeGB:      freeBytes         / 1_073_741_824,
            cachedGB:    inactiveBytes     / 1_073_741_824,
            swapUsedGB:  Double(xsw.xsu_used)  / 1_073_741_824,
            swapTotalGB: Double(xsw.xsu_total) / 1_073_741_824
        )
    }
}
