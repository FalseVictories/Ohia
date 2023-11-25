
import Dependencies
import XCTest
@testable import BCKit

final class BCKitTests: XCTestCase {
    var collectionLoader: CollectionLoader?
    
    override func setUp() async throws {
        collectionLoader = withDependencies{
            $0.downloadService = TestDownloadService()
        } operation: {
            CollectionLoader()
        }
    }
    
    func testCollectionLength() async throws {
        let model = await collectionLoader!.listCollectionFor(username: "test")
        XCTAssertEqual(model.items.count, 1440)
    }
    
    func testCollection() async throws {
        let model = await collectionLoader!.listCollectionFor(username: "test")
        let item = model.items[0]
        
        XCTAssertEqual(item.artist, "Matana Roberts")
        XCTAssertEqual(item.downloadUrl.absoluteString, "https://bandcamp.com/download?from=collection&payment_id=2497510170&sig=f63313d37b664ddadc47152d52cd9e92&sitem_id=261846347")
        XCTAssertEqual(item.name, "Coin Coin 5-Album Bundle")
    }
}
