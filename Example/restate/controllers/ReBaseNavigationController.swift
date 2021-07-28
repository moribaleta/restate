//
//  ReBaseNavigationController.swift
//  restate_Tests
//
//  Created by Gabriel Mori Baleta on 7/28/21.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import Foundation
import AsyncDisplayKit
import RxSwift
import ReSwift





@available(*, deprecated, message: "Uses old implementation of navigation controller on the viewcontroller, please use ReactiveBaseNavigationControllerEditable implements the navigation to flex")
open class ReactiveBaseNavigationController<E,T, V> : ReBaseController<E,T,V> where E : StateType {
 
    public var navigation = ReNavigationController()
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.onLayoutNavigation()
    }
    
    open override func loadView() {
        super.loadView()
        self.onInitNavigation()
    }
    
    open func onInitNavigation() {
        addChild(self.navigation)
        self.node.view.addSubview(self.navigation.view)
        
        self.navigation.routesView = {
            [unowned self] arg in
            self.setRoute(navigation: self.navigation, routeName: arg)
        }
        
        self.navigation.reBind(obx: self.reBindRoutes())
    }
    
    open func onLayoutNavigation() {
        print("nav bounds \(self.view.bounds) | nav frame \(self.view.frame)")
        self.navigation.view.bounds = .init(origin: .init(x: 0, y: 0), size: self.view.frame.size)//self.view.bounds
        self.navigation.view.frame = .init(origin: .init(x: 0, y: 0), size: self.view.frame.size)//self.view.bounds
    }
    
    /**
        insert all your navigation tree here
        ```
            if routeName == "search" {
                return self.searchTable!
            } else if routeName == "editor" {
                return self.editor!
            }
            return VCComingSoon()
        ```
     */
    open func setRoute(navigation: ReNavigationController, routeName: Stringable) -> UIViewController {
        return VCComingSoon()
    }
    
    open func reBindRoutes() -> Observable<StatePropertyList<Stringable>> {
        if T.self as? NavigationStateProtocol.Type != nil {
            return self.statePublisher.map({ ($0 as! NavigationStateProtocol).routes })
        }
        
        return Observable.just(StatePropertyList<Stringable>())
    }
    
}

/**
 * ReBaseNavigation Controller uses a single specific statetype
 */
open class ReactiveSingleStateNavigationController<E,V> : ReactiveBaseNavigationController<E,E,V> where E : StateType {
    
    ///override this function to listen to state changes
    open override func onStateUpdate(state: E){
        super.onStateUpdate(state: state)
    }
    
    open override func onInitNavigation() {
        super.onInitNavigation()
    }
    
    
    open override func setRoute(navigation: ReNavigationController, routeName: Stringable) -> UIViewController {
        return VCComingSoon()
    }
}

/**
 * ReBaseController implements ReNavigationController
 */
open class ReactiveBaseNavigationControllerEditable<E,T,V> : ReactiveBaseNavigationController<E,T,V> where E: StateType, V: UIReBaseNavigationEditable<T> {
    
    open override func onLayoutNavigation() {
        //empty to overrider layout navigation
    }
    
    open override func onInitNavigation() {
        addChild(self.navigation)
        self.reNode?.navView = self.navigation.view
        
        self.navigation.routesView = {
            [unowned self] arg in
            self.setRoute(navigation: self.navigation, routeName: arg)
        }
        
        self.navigation.reBind(obx: self.reBindRoutes())
    }
    
}

open class UIReBaseNavigationEditable<E> : ShadowedSheetEditable<E> where E : StateType {
    
    var navView = UIView()
    public var navNode = ASDisplayNode()
    
    public override init() {
        super.init()
        self.style.width    = .init(unit: .fraction, value: 1)
        self.style.height   = .init(unit: .fraction, value: 1)
        
        self.navNode.setViewBlock {
            [unowned self] () -> UIView in
            return self.navView
        }
    }
    
    open override func didLoad() {
        super.didLoad()
        self.set(self.navNode)
    }
}
