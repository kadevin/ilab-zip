import Foundation

/// XPC Service 实现
class ArchiveXPCService: NSObject, ArchiveXPCProtocol {
    
    private func getEnginePath() -> String? {
        // XPC Service 需要通过主应用 bundle 定位 7zz
        let mainBundleURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        let contentsURL = mainBundleURL
            .deletingLastPathComponent()  // 从 XPCServices/ 到 Contents/
            .deletingLastPathComponent()  // 从 Contents/ 到 .app/
            .appendingPathComponent("Contents/Resources/7zz")
        let enginePath = contentsURL.path
        return FileManager.default.fileExists(atPath: enginePath) ? enginePath : nil
    }
    
    private func runEngine(args: [String]) -> (success: Bool, output: String) {
        guard let enginePath = getEnginePath() else {
            return (false, "Engine not found")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: enginePath)
        process.arguments = args
        
        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let errOutput = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            
            return (process.terminationStatus == 0, process.terminationStatus == 0 ? output : errOutput)
        } catch {
            return (false, error.localizedDescription)
        }
    }
    
    func compressTo7z(files: [String], outputPath: String, withReply reply: @escaping (Bool, String?) -> Void) {
        var args = ["a", "-t7z", "-mx=5", outputPath]
        args.append(contentsOf: files)
        let result = runEngine(args: args)
        reply(result.success, result.success ? nil : result.output)
    }
    
    func compressToZip(files: [String], outputPath: String, withReply reply: @escaping (Bool, String?) -> Void) {
        var args = ["a", "-tzip", outputPath]
        args.append(contentsOf: files)
        let result = runEngine(args: args)
        reply(result.success, result.success ? nil : result.output)
    }
    
    func extractHere(archivePath: String, withReply reply: @escaping (Bool, String?) -> Void) {
        let directory = (archivePath as NSString).deletingLastPathComponent
        let args = ["x", archivePath, "-o\(directory)", "-y"]
        let result = runEngine(args: args)
        reply(result.success, result.success ? nil : result.output)
    }
    
    func extractTo(archivePath: String, destinationPath: String, withReply reply: @escaping (Bool, String?) -> Void) {
        let args = ["x", archivePath, "-o\(destinationPath)", "-y"]
        let result = runEngine(args: args)
        reply(result.success, result.success ? nil : result.output)
    }
}

// MARK: - XPC Service main

class XPCServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        let exportedInterface = NSXPCInterface(with: ArchiveXPCProtocol.self)
        newConnection.exportedInterface = exportedInterface
        newConnection.exportedObject = ArchiveXPCService()
        newConnection.resume()
        return true
    }
}
