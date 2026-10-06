import Foundation
import Darwin

// MARK: - CPU

struct CPUStats {
    let usagePercent: Int

    var emoji: String {
        switch usagePercent {
        case 0..<50: return "🟢"
        case 50..<80: return "🟡"
        default:      return "🔴"
        }
    }

    // Samples two snapshots ~200 ms apart for an accurate delta.
    static func current() -> CPUStats {
        func load() -> (user: UInt32, sys: UInt32, idle: UInt32) {
            var info = host_cpu_load_info()
            var count = mach_msg_type_number_t(
                MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
            )
            withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
                }
            }
            return (info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2)
        }

        let a = load()
        Thread.sleep(forTimeInterval: 0.2)
        let b = load()

        let user = Int(b.user) - Int(a.user)
        let sys  = Int(b.sys)  - Int(a.sys)
        let idle = Int(b.idle) - Int(a.idle)
        let total = user + sys + idle
        guard total > 0 else { return CPUStats(usagePercent: 0) }
        return CPUStats(usagePercent: Int(Double(user + sys) / Double(total) * 100))
    }
}

// MARK: - Disk

struct DiskStats {
    let totalGB: Double
    let usedGB: Double
    let freeGB: Double

    var usagePercent: Int { Int((usedGB / totalGB) * 100) }

    var emoji: String {
        switch usagePercent {
        case 0..<70: return "🟢"
        case 70..<90: return "🟡"
        default:      return "🔴"
        }
    }

    static func current() -> DiskStats {
        let attrs = (try? FileManager.default.attributesOfFileSystem(forPath: "/")) ?? [:]
        let total = (attrs[.systemSize] as? Int64) ?? 0
        let free  = (attrs[.systemFreeSize] as? Int64) ?? 0
        let used  = total - free
        let gb    = 1_073_741_824.0
        return DiskStats(
            totalGB: Double(total) / gb,
            usedGB:  Double(used)  / gb,
            freeGB:  Double(free)  / gb
        )
    }
}

// MARK: - Memory

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
