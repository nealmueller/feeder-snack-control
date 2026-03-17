import Foundation

struct FeederOption: Decodable, Identifiable, Hashable {
    var id: String { serial }
    let serial: String
    let name: String
}
