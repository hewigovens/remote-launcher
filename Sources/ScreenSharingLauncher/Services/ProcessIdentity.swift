import Darwin
import Foundation

struct ProcessIdentity: Equatable, Sendable {
    var processIdentifier: Int32
    var launchDate: Date
    var executablePath: String

    static func read(_ pid: Int32) -> ProcessIdentity? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size,
              info.pbi_status != SZOMB else { return nil }
        var path = [UInt8](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &path, UInt32(path.count)) > 0 else { return nil }
        let date = Date(timeIntervalSince1970: Double(info.pbi_start_tvsec) + Double(info.pbi_start_tvusec) / 1_000_000)
        return ProcessIdentity(processIdentifier: pid, launchDate: date,
                               executablePath: String(decoding: path.prefix { $0 != 0 }, as: UTF8.self))
    }

    func matches(_ session: SessionRecord, executable: URL) -> Bool {
        processIdentifier == session.processIdentifier
            && abs(launchDate.timeIntervalSince(session.launchDate)) < 0.01
            && URL(fileURLWithPath: executablePath).standardizedFileURL == executable.standardizedFileURL
    }

    static func hasTCPConnection(_ pid: Int32, port: UInt16) -> Bool? {
        let needed = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard needed > 0 else { return nil }
        let stride = MemoryLayout<proc_fdinfo>.stride
        var descriptors = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(needed) / stride + 16)
        let read = descriptors.withUnsafeMutableBytes {
            proc_pidinfo(pid, PROC_PIDLISTFDS, 0, $0.baseAddress, Int32($0.count))
        }
        guard read > 0 else { return nil }
        for descriptor in descriptors.prefix(Int(read) / stride) where descriptor.proc_fdtype == PROX_FDTYPE_SOCKET {
            var socket = socket_fdinfo()
            let size = Int32(MemoryLayout<socket_fdinfo>.size)
            guard proc_pidfdinfo(pid, descriptor.proc_fd, PROC_PIDFDSOCKETINFO, &socket, size) == size else {
                if errno == EPERM || errno == EACCES { return nil }
                continue // A file descriptor may close between the two reads.
            }
            guard socket.psi.soi_kind == SOCKINFO_TCP else { continue }
            let tcp = socket.psi.soi_proto.pri_tcp
            let remotePort = UInt16(bigEndian: UInt16(truncatingIfNeeded: tcp.tcpsi_ini.insi_fport))
            if remotePort == port && [TSI_S_SYN_SENT, TSI_S_ESTABLISHED].contains(tcp.tcpsi_state) { return true }
        }
        return false
    }
}
