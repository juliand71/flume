import Foundation

struct PlaidItem: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let plaidItemId: String
    let institutionName: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case plaidItemId = "plaid_item_id"
        case institutionName = "institution_name"
        case createdAt = "created_at"
    }
}
