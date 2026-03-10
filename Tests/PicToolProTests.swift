import XCTest
@testable import PicToolPro

final class PicToolProTests: XCTestCase {
    
    func testImageFormatRawValue() throws {
        XCTAssertEqual(ImageFormat.png.rawValue, "png")
        XCTAssertEqual(ImageFormat.jpg.rawValue, "jpg")
        XCTAssertEqual(ImageFormat.heic.rawValue, "heic")
    }
    
    func testCornerRadiusPreset() throws {
        XCTAssertEqual(CornerRadiusPreset.px10.value, 10)
        XCTAssertEqual(CornerRadiusPreset.px20.value, 20)
        XCTAssertEqual(CornerRadiusPreset.custom.value, nil)
    }
}
