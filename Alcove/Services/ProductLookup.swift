import Foundation

struct ProductInfo: Sendable {
    var name: String
    var brand: String?
    var packageSize: String?
    var imageURL: String?
}

/// Looks up barcodes in Open Food Facts (free, community-run, good coverage
/// of packaged food worldwide including many Indian brands).
enum ProductLookup {
    static func lookup(barcode: String) async -> ProductInfo? {
        let fields = "product_name,product_name_en,brands,quantity,image_front_small_url"
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=\(fields)") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("Alcove-iOS/0.1", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(OFFResponse.self, from: data)
            guard decoded.status == 1, let product = decoded.product else { return nil }
            let name = [product.product_name_en, product.product_name]
                .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty }
            guard let name else { return nil }
            let brand = product.brands?
                .split(separator: ",").first
                .map { $0.trimmingCharacters(in: .whitespaces) }
            return ProductInfo(
                name: name,
                brand: brand?.isEmpty == true ? nil : brand,
                packageSize: cleanSize(product.quantity),
                imageURL: product.image_front_small_url
            )
        } catch {
            return nil
        }
    }
}

extension ProductLookup {
    /// "400 g e" / "400 g ℮" → "400 g" (℮ is the EU "estimated quantity" mark).
    static func cleanSize(_ raw: String?) -> String? {
        guard var size = raw?.trimmingCharacters(in: .whitespaces), !size.isEmpty else { return nil }
        for mark in [" ℮", "℮", " e"] where size.hasSuffix(mark) {
            size = String(size.dropLast(mark.count)).trimmingCharacters(in: .whitespaces)
        }
        return size.isEmpty ? nil : size
    }
}

nonisolated private struct OFFResponse: Decodable {
    let status: Int?
    let product: OFFProduct?
}

nonisolated private struct OFFProduct: Decodable {
    let product_name: String?
    let product_name_en: String?
    let brands: String?
    let quantity: String?
    let image_front_small_url: String?
}
