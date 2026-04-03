import Foundation
@testable import Flume

enum FlexFactory {

    static func detectionResponse(
        totalFlex: Decimal = 800,
        transactionCount: Int = 120
    ) -> FlexDetectionResponse {
        FlexDetectionResponse(
            totalFlex: totalFlex,
            transactionCount: transactionCount
        )
    }
}
