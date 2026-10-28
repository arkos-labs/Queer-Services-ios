import Foundation

/// Référentiel des catégories et sous-catégories, embarqué dans l'app (reference.json).
/// Sert de secours quand Supabase refuse la lecture, par exemple sans connexion.
enum ReferenceCatalog {
    private struct File: Decodable {
        struct Cat: Decodable {
            let id: String
            let label: String
            let slug: String
            let icon: String?
            let sortOrder: Int?
        }

        struct Sub: Decodable {
            let id: String
            let categorySlug: String
            let label: String
            let slug: String
            let sortOrder: Int?
        }

        let categories: [Cat]
        let subcategories: [Sub]
    }

    static func load() -> (categories: [Category], subcategories: [Subcategory]) {
        guard
            let url = Bundle.main.url(forResource: "reference", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else { return ([], []) }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let file = try? decoder.decode(File.self, from: data) else { return ([], []) }

        let categories = file.categories.map {
            Category(id: $0.id, label: $0.label, slug: $0.slug, icon: $0.icon, sortOrder: $0.sortOrder)
        }
        let categoryIdBySlug = Dictionary(uniqueKeysWithValues: categories.map { ($0.slug, $0.id) })
        let subcategories = file.subcategories.compactMap { sub -> Subcategory? in
            guard let categoryId = categoryIdBySlug[sub.categorySlug] else { return nil }
            return Subcategory(id: sub.id, categoryId: categoryId, label: sub.label, slug: sub.slug, sortOrder: sub.sortOrder)
        }
        return (categories, subcategories)
    }
}
