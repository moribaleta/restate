//
//  ProgressiveViewProtocol.swift
//  restate_Tests
//
//  Created by Gabriel Mori Baleta on 7/28/21.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import Foundation
import RxSwift
import AsyncDisplayKit

public protocol ProgressiveViewProtocol {
    
    var isViewed        : Bool {get set}
    var loader          : ASDisplayNode? {get set}
    var interval_time   : RxTimeInterval {get set}
    
    
    func onDidViewVisible()
    func layoutContent(_ constrainedSize: ASSizeRange) -> ASLayoutSpec
}
