//
//  ViewController.swift
//  RxRedux
//
//  Created by Patrik Sjöberg on 2018-03-15.
//  Copyright © 2018 Patrik Sjöberg. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

struct Model: Equatable {
    
    typealias UserAction = ViewController.UserAction
    
    enum Action: Equatable {
        case userAction(UserAction)
        case setFlash(Bool)
    }
    
    enum Effect: Equatable {
        case flash
    
        func handle(scheduler: SchedulerType) -> Observable<Action> {
            Observable<Int>
                .interval(.milliseconds(70), scheduler: scheduler)
                .map({ Action.setFlash(($0+1) % 2 != 0) })
                .take(4)
        }
    }
    
    var counter: Int = 0
    var flash: Bool = false
    
    static func reduce(state: Self?, action: Action) -> Next<Self, Effect> {
        var state = state ?? Model()
        
        switch action {
        case .userAction(.increment):
            state.counter += 1
        case .userAction(.decrement) where state.counter == 0:
            return .effect(.flash)
        case .userAction(.decrement):
            state.counter -= 1
        case .setFlash(let value):
            state.flash = value
        }
        
        return Next(state: state, effects: [])
    }
    
    static func handle(effect: Effect, scheduler: SchedulerType = MainScheduler.instance) -> Observable<Action> {
        return effect.handle(scheduler: scheduler)
    }
    
}


class ViewController: UIViewController {
    @IBOutlet var label: UILabel!
    @IBOutlet var messageLabel: UILabel!
    
    @IBOutlet weak var plussButton: UIButton!
    @IBOutlet weak var minusButton: UIButton!
    
    enum UserAction {
        case increment
        case decrement
    }
    
    struct Input {
        let counter: Driver<String>
        let flash: Driver<Bool>
        
        let userActionObserver: AnyObserver<UserAction>
    }
    
    enum Effect {
        case flash
    }
    
    private var disposeBag = DisposeBag()
    
    lazy var input: Input = {
        let model = Model()
        let result = build(
            initialState: Model(),
            reducer: Model.reduce,
            handler: Model.handle
        )
        
        let state = result.0.debug("State")
            .distinctUntilChanged()
            .share(replay: 1, scope: .whileConnected)
        
        let dispatch = result.1
       
        return Input(
            counter: state
                .map { String($0.counter) }
                .asDriver(onErrorJustReturn: "error"),
            flash: state
                .map { $0.flash }
                .asDriver(onErrorJustReturn: false),
            userActionObserver: dispatch
                .mapObserver(Model.Action.userAction)
        )
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        input.counter
            .drive(label.rx.text)
            .disposed(by: disposeBag)
        
        input.flash
            .map { $0 ? UIColor.systemPink : UIColor.clear }
            .drive(label.rx.backgroundColor)
            .disposed(by: disposeBag)
        
        minusButton.rx.controlEvent(.primaryActionTriggered)
            .map { _ in UserAction.decrement }
            .bind(to: input.userActionObserver)
            .disposed(by: disposeBag)
        
        plussButton.rx.controlEvent(.primaryActionTriggered)
            .map { UserAction.increment }
            .bind(to: input.userActionObserver)
            .disposed(by: disposeBag)
    }

}

