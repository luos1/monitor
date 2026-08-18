import XCTest
@testable import iPadMirrorMac
import iPadMirrorShared

final class IAPProductsTests: XCTestCase {
    func testProductIDsMatchAppStoreConnect() {
        XCTAssertEqual(IAPProductID.lifetime.rawValue, "ipadmirror.lifetime")
        XCTAssertEqual(IAPProductID.donation.rawValue, "ipadmirror.donation")
        XCTAssertEqual(
            IAPProductID.allIDs,
            ["ipadmirror.lifetime", "ipadmirror.donation"]
        )
        XCTAssertTrue(IAPProductID.lifetime.grantsLifetimeUnlock)
        XCTAssertTrue(IAPProductID.donation.grantsLifetimeUnlock)
    }

    func testFallbackNamesAndPrices() {
        XCTAssertEqual(IAPProductID.lifetime.fallbackPriceLabel, "$4.99")
        XCTAssertEqual(IAPProductID.donation.fallbackPriceLabel, "$99.99")
        XCTAssertFalse(IAPProductID.lifetime.fallbackDisplayName.isEmpty)
        XCTAssertFalse(IAPProductID.donation.fallbackDisplayName.isEmpty)
    }

    func testStoreKitConfigurationMatchesProductIDs() throws {
        let storeKitURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Configuration/Products.storekit")

        let data = try Data(contentsOf: storeKitURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let products = try XCTUnwrap(json["products"] as? [[String: Any]])

        let ids = Set(products.compactMap { $0["productID"] as? String })
        XCTAssertEqual(ids, IAPProductID.allIDs)

        let byID = Dictionary(uniqueKeysWithValues: products.compactMap { product -> (String, [String: Any])? in
            guard let id = product["productID"] as? String else { return nil }
            return (id, product)
        })

        let lifetime = try XCTUnwrap(byID["ipadmirror.lifetime"])
        XCTAssertEqual(lifetime["type"] as? String, "NonConsumable")
        XCTAssertEqual(lifetime["displayPrice"] as? String, "4.99")
        assertDisplayNames(
            lifetime,
            english: "Lifetime Unlock",
            korean: "평생 사용"
        )

        let donation = try XCTUnwrap(byID["ipadmirror.donation"])
        XCTAssertEqual(donation["type"] as? String, "NonConsumable")
        XCTAssertEqual(donation["displayPrice"] as? String, "99.99")
        assertDisplayNames(
            donation,
            english: "Developer Support",
            korean: "개발자 응원"
        )
    }

    private func assertDisplayNames(
        _ product: [String: Any],
        english: String,
        korean: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let localizations = product["localizations"] as? [[String: Any]] ?? []
        let names = Dictionary(uniqueKeysWithValues: localizations.compactMap { localization -> (String, String)? in
            guard
                let locale = localization["locale"] as? String,
                let name = localization["displayName"] as? String
            else { return nil }
            return (locale, name)
        })
        XCTAssertEqual(names["en_US"], english, file: file, line: line)
        XCTAssertEqual(names["ko"], korean, file: file, line: line)
    }
}
