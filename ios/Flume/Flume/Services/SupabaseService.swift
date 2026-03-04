import Foundation
import Supabase

struct SupabaseService {
    static let shared: SupabaseClient = {
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              let url = URL(string: urlString),
              let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String else {
            fatalError("Missing SUPABASE_URL or SUPABASE_ANON_KEY in Info.plist")
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }()
}
