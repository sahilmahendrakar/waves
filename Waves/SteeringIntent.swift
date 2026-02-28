import Foundation

enum SteeringIntent {
    case steerMusic(prompt: String)
    case block(domain: String, appName: String)
    case unblock(domain: String, appName: String)
}

enum SteeringStatus: Equatable {
    case idle
    case classifying
    case success(String)
    case error(String)
}
