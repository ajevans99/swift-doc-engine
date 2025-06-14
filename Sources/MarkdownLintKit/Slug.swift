import Foundation

enum Slug {
    static func slug(_ text: String) -> String {
        var slug = text.lowercased()
        slug = slug.replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        while slug.contains("--") { slug = slug.replacingOccurrences(of: "--", with: "-") }
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug
    }
}
