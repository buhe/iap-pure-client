//
//  Created by 顾艳华 on 2023/1/23.
//

import Foundation
import SwiftUI

public class IAPViewModel :ObservableObject {
    @Published public var loading = false
    
    public static let shared: IAPViewModel = IAPViewModel()
}
