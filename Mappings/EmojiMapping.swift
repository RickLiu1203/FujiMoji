import Foundation

struct Emoji: Identifiable, Codable {
    let id = UUID()
    let name: String
    let symbol: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case symbol
    }
}
