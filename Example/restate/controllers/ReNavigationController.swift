//
//  ReNavigationController.swift
//  restate_Tests
//
//  Created by Gabriel Mori Baleta on 7/28/21.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import Foundation
import AsyncDisplayKit
import RxSwift
import libsuture

public protocol ReNavigationDelegate : class {
    func reNavigationDidPush(navigation: ReNavigationController)
    func reNavigationDidPop(navigation: ReNavigationController)
}

public struct ReNavigationEntry {
    public var id : Stringable
    public var vc : UIViewController?
}

/**
    uiview controller that implements ui navigation controller and reactive protocol
    ATTENTION:
        - use reBind before viewDidLoad on parent or add it to loadView
 */
open class ReNavigationController : UINavigationController, ReProtocol {
    
    public typealias StateType  = StatePropertyList<Stringable>
    
    public var reDisposedBag    = DisposeBag()
    
    public var transitionType   : ReNavigationTransitionType = .normal
    
    ///used for returning the specific view controller used based on the routename
    public var routesView : ((Stringable) -> UIViewController)?
    
    var emitBack = PublishSubject<Void>()
    
    ///observable that resolves void for subscribing to on back action
    public var rxBack  : Observable<Void>{
        return self.emitBack
    }
    
    public var id : String = ResizeableNode.randomString(length: 3) +  "--NavigationController"
    
    ///back button
    open var backButton = UIBarButtonItem()
    
    ///contains all the current vc inside the stack
    public var vc_ids = [ReNavigationEntry]()
    
    ///top most vc inside the stack
    public var vc_top : ReNavigationEntry?
    
    public var vc_modals = [ReNavigationEntry]()
    
    ///used to detemine if the navigation will retain the vc push and popped
    public var automatically_create_new_vc = true
    
    open weak var reNavigationDelegate : ReNavigationDelegate?
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setBackButton()
        
        self.navigationBar.backgroundColor = UIColor.white
        self.navigationBar.setValue(true, forKey: "hidesShadow")
        self.navigationBar.isTranslucent = false
    }
    
    public func setCloseButton() {
        let uiback = UIButton()
        uiback.setAttributedTitle(NSAttributedString(asIcon: .actionClose), for: .normal)
        uiback.addTarget(self, action: #selector(self.onBack), for: .touchUpInside)
        backButton = UIBarButtonItem(customView: uiback)
    }
    
    public func setBackButton() {
        let uiback = UIButton()
        uiback.setAttributedTitle(NSAttributedString(asIcon: .arrowLeft), for: .normal)
        uiback.addTarget(self, action: #selector(self.onBack), for: .touchUpInside)
        backButton = UIBarButtonItem(customView: uiback)
    }
    
    @objc func onBack(){
        self.emitBack.onNext(())
    }
    
    deinit {
        /*
        self.vc_top = nil
        self.vc_ids = []
        self.vc_modals = []
        /*
        self.children.forEach({$0.removeFromParent()})
        self.viewControllers.removeAll()
        */
        */
        self.dispose()
    }
    
    public func dispose(){
        self.viewControllers.forEach {$0.removeFromParent()}
        self.children.forEach({$0.removeFromParent()})
        //self.viewControllers.forEach({$0.removeFromParent()})
        //self.children.fo
        self.vc_top = nil
        self.vc_ids = []
        self.vc_modals = []
        self.reDisposedBag = .init()
        self.emitBack.dispose()
        self.routesView = nil
        self.reNavigationDelegate = nil
    }
    
    open override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if self.viewControllers.count > 1 {
            viewController.navigationItem.leftBarButtonItem = backButton
        } else {
            viewController.navigationItem.leftBarButtonItem = nil
        }
        
        if let nodeController = viewController as? ASDKViewController,
            let navigable = nodeController.node as? Navigable {
            
            if viewControllers.count > 0 {
                navigable.navBar.setBack()
            } else {
                navigable.navBar.setClose()
            }
        }
        
        super.pushViewController(viewController, animated: animated)
    }
    
    public func reBind(obx: Observable<StatePropertyList<Stringable>>) {
        self.reDisposedBag = DisposeBag()
        
        obx.take(1).subscribe(onNext: {
            [weak self] value in
                self?.renderState(value: value)
            })
            .disposed(by: self.reDisposedBag)
        
        obx.skip(1)
            //DONT ADD MAINSCHEDULER causes weird navigation issue
            //.observeOn(MainScheduler.instance)
            .subscribe(onNext: {
            [weak self] value in
                
                self?.reUpdate(value: value)
            }).disposed(by: self.reDisposedBag)
    }
    
    public func reUpdate(value: StatePropertyList<Stringable>) {
        if self.automatically_create_new_vc {
            self.resolveRoute(route: value)
        } else {
            self.resolveRetainRoute(route: value)
            
        }
        
    }
    
    /*
    deinit {
        self.viewControllers.removeAll()
        self.vc_ids.forEach { (entry) in
            entry.vc?.removeFromParent()
        }
    }
    */
    
    public func renderState(value: StatePropertyList<Stringable>) {
        // load all view
        /*
        self.viewControllers.removeAll()
        let vcs = value.map {
            [unowned self] name -> UIViewController in
            return self.routesView?(name) ?? VCComingSoon()
        }
        self.viewControllers = vcs
        */
        if self.automatically_create_new_vc {
            self.viewControllers.removeAll()
            let vcs = value.map { name -> UIViewController in
                let vc = self.routesView?(name) ?? VCComingSoon()
                return vc
            }
            self.viewControllers = vcs
        } else {
            self.viewControllers.removeAll()
            self.vc_ids = []
            
            let vcs = value.map { name -> UIViewController in
                let vc = self.routesView?(name) ?? VCComingSoon()
                vc_ids.append(.init(id: name, vc: vc))
                return vc
            }
            
            vc_top = vc_ids.last
            self.viewControllers = vcs
        }
        
    }
    
    ///dont delet for reference
    ///resolves route changes on StatePropertyList
    func resolveRetainRoute(route: StatePropertyList<Stringable>) {
        if route.isDirty {
            // load all view
            self.renderState(value: route)

        } else if route.hasChanges {
            for (i, change) in route.changes.enumerated() {
                
                let animated = i == route.changes.count - 1
                
                if change.type == .add {
                    
                    if let routename = change.value, route.last?.string != vc_top?.id.string {
                        if  let prev_vc = self.vc_ids.first(where: {$0.id.string == routename.string}), let vc = prev_vc.vc {
                            vc_top = prev_vc
                            self.pushView(vc: vc, type: self.transitionType, animated: animated)
                        } else if let vc = routesView?(routename) {
                            self.pushView(vc: vc, type: self.transitionType, animated: animated)
                            let entry = ReNavigationEntry(id: routename, vc: vc) //init(id: routename , vc: vc)
                            self.vc_ids.append(entry)
                            self.vc_top = entry
                        }
                    }
                    
                } else if change.type == .remove {
                    
                    if  let value = change.value {
                        
                        var prevVC : UIViewController?
                        
                        if let index = self.vc_modals.firstIndex(where: {$0.id.string == value.string}),
                            let vc = vc_modals[index].vc { //, let vc = routesView?(value) {
                            let vc = self.popView(vc: vc, type: self.transitionType, animated: animated )
                            
                            prevVC = vc
                            vc_modals.remove(at: index)
                        }
                        else {
                            prevVC = self.popView(type: self.transitionType, animated: animated )
                        }
                        
                        //update vc_ids that was popped
                        if let index = self.vc_ids.firstIndex(where: {$0.id.string == value.string}) {
                            self.vc_ids[index] = .init(id: value, vc: prevVC)
                        }
                        
                        //update vc_top to the top most stack
                        if let top_route = route.last, let prev_vc = self.vc_ids.first(where: {$0.id.string == top_route.string}) {
                            vc_top = prev_vc
                        } else {
                            vc_top = nil
                        }
                        
                    } else {
                        fatalError("routname not given")
                    }
                    
                    
                    /*
                     if let value = change.value, let vc = routesView?(value) {
                     let prevVc = self.popView(vc: vc, type: self.transitionType, animated: animated )
                     
                     //update vc_ids that was popped
                     if let index = self.vc_ids.firstIndex(where: {$0.id.string == value.string}) {
                     self.vc_ids[index] = .init(id: value, vc: prevVc)
                     }
                     
                     //update vc_top to the top most stack
                     if let top_route = route.last, let prev_vc = self.vc_ids.first(where: {$0.id.string == top_route.string}) {
                     vc_top = prev_vc
                     } else {
                            vc_top = nil
                        }
                        
                    } else {
                        fatalError("routname not given")
                    }
                    */
                }
                
                
            }
        }//resolveRoute
        
        if route.count > 1 {
            viewControllers.last?.navigationItem.leftBarButtonItem = backButton
        } else {
            viewControllers.last?.navigationItem.leftBarButtonItem = nil
        }

    }
    
    
    func resolveRoute(route: StatePropertyList<Stringable>) {
        if route.isDirty {
            // load all view
            /*
            self.viewControllers.removeAll()
            let vcs = route.map { name -> UIViewController in
                return self.routesView?(name) ?? VCComingSoon()
            }
            self.viewControllers = vcs
            */
            self.renderState(value: route)

        } else if route.hasChanges {
            for (i, change) in route.changes.enumerated() {
                
                let animated = i == route.changes.count - 1
                if change.type == .add {
                    if let value = change.value, let vc = routesView?(value) {
                        self.pushView(vc: vc, type: self.transitionType, animated: animated)
                        
                        if vc as? SULSpongeCake != nil || vc as? SULPageSheet != nil || vc as? SULFloatSheet != nil {
                            self.vc_modals.append(.init(id: value, vc: vc))
                        }
                    }
                } else if change.type == .remove {
                    
                    if  let value = change.value,
                        let index = self.vc_modals.firstIndex(where: {$0.id.string == value.string}),
                        let vc = vc_modals[index].vc { //, let vc = routesView?(value) {
                            let vc = self.popView(vc: vc, type: self.transitionType, animated: animated )
                            vc?.willMove(toParent: nil)
                            //vc?.view.removeFromSuperview()
                            vc?.removeFromParent()
                            vc_modals.remove(at: index)
                    } else {
                        let vc = self.popView(type: self.transitionType, animated: animated )
                        vc?.willMove(toParent: nil)
                        //vc?.view.removeFromSuperview()
                        vc?.removeFromParent()
                    }
                }
            }
        }//resolveRoute
        
        if route.count > 1 {
            viewControllers.last?.navigationItem.leftBarButtonItem = backButton
        } else {
            viewControllers.last?.navigationItem.leftBarButtonItem = nil
        }
    }
    
    private func pushView(vc: UIViewController, type: ReNavigationTransitionType, animated: Bool = true) {
        if vc as? SULSpongeCake != nil || vc as? SULPageSheet != nil || vc as? SULFloatSheet != nil {
            self.present(vc, animated: animated, completion: nil)
        } else if type == .normal {
            self.pushViewController(vc, animated: animated)
        } else {
            let transition:CATransition = CATransition()
            transition.duration = 0.3
            transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
            transition.type = CATransitionType.push
            transition.subtype = CATransitionSubtype.fromTop
            self.view.layer.add(transition, forKey: kCATransition)
            self.pushViewController(vc, animated: false)
        }
        
        self.reNavigationDelegate?.reNavigationDidPush(navigation: self)
    }
    
    private func popView(vc: UIViewController? = nil, type: ReNavigationTransitionType, animated: Bool = true) -> UIViewController? {
        if let vc = vc, vc as? SULSpongeCake != nil || vc as? SULPageSheet != nil || vc as? SULFloatSheet != nil { //this doesnt pops the view controller from a modal because routesView is for Push view controller only
            vc.dismiss(animated: true, completion: nil)
            self.reNavigationDelegate?.reNavigationDidPop(navigation: self)
            return vc
        } else if type == .normal {
            self.reNavigationDelegate?.reNavigationDidPop(navigation: self)
            return self.popViewController(animated: animated)
            
        }else {
            let transition:CATransition = CATransition()
            transition.duration = 0.3
            transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
            transition.type = CATransitionType.push
            transition.subtype = CATransitionSubtype.fromBottom
            self.view.layer.add(transition, forKey: kCATransition)
            let vc = self.popViewController(animated: false)
            super.viewWillDisappear(true)
            self.reNavigationDelegate?.reNavigationDidPop(navigation: self)
            return vc
        }
        
        
    }

}//VCNavigation

public enum ReNavigationTransitionType {
    case normal
    case pushup
}

