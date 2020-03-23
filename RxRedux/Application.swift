//
//  Application.swift
//  RxRedux
//
//  Created by Patrik Sjöberg on 2018-03-15.
//  Copyright © 2018 Patrik Sjöberg. All rights reserved.
//

import Foundation
import RxSwift

struct Next<State: Equatable, Effect: Equatable>: Equatable {
    var state: State? = nil
    var effects: [Effect] = []
    
    static func next(_ state: State, effects: [Effect]) -> Next {
        return Next(state: state, effects: effects)
    }
    
    static func effect(_ effect: Effect) -> Next {
        return Next(state: nil, effects: [effect])
    }
}

func build<State, Action>(
    initialState: State? = nil,
    reducer: @escaping (State?, Action) -> State,
    scheduler: SchedulerType = MainScheduler.asyncInstance
) -> (Observable<State>, AnyObserver<Action>) {
    
    let dispatch = PublishSubject<Observable<Action>>()
    
    let state: Observable<State> = dispatch
        .observeOn(scheduler)
        .flatMap { $0 }
        .scan(nil) { (state, action) -> State? in
            reducer(state, action)
        }
        .startWith(initialState)
        .compactMap { $0 }
        
    return (
        state,
        dispatch.mapObserver({ .just($0) })
    )
}


func build<State, Action, Effect>(
    initialState: State? = nil,
    reducer: @escaping (State?, Action) -> Next<State, Effect>,
    handler: @escaping (Effect, SchedulerType) -> (Observable<Action>),
    scheduler: SchedulerType = MainScheduler.asyncInstance
) -> (Observable<State>, AnyObserver<Action>) {
    
    let dispatch = PublishSubject<Observable<Action>>()
    
    let state: Observable<State> = dispatch
        .observeOn(scheduler)
        .flatMap { $0 }
        .scan(initialState) { (state, action) -> State? in
            let next = reducer(state, action)
            
            for effect in next.effects {
                dispatch.onNext(handler(effect, scheduler))
            }
            
            return next.state
        }
        .startWith(initialState)
        .compactMap { $0 }
        
    return (
        state,
        dispatch.mapObserver({ .just($0) })
    )
}




func test() {
    
    struct State: Equatable {
        var value = 0
    }
    
    enum Action {
        case increment
        case decrement
        case reset
    }
    
    enum Effect: Equatable {
        case playSound
    }

    func reduce(state: State?, action: Action) -> Next<State, Effect> {
        var state = state ?? State()
        switch action {
        case .increment:
            state.value += 1
        case .decrement where state.value == 0:
            return Next(effects: [.playSound])
        case .decrement:
            state.value -= 1
        case .reset:
            state.value = 1
        }
        return Next(state: state)
    }
    
    func handle(effect: Effect, scheduler: SchedulerType) -> Observable<Action> {
        switch effect {
        case .playSound:
            print("BEEP")
            return .just(.reset)
        }
    }
    
    let (state, dispatchSubject) = build(reducer: reduce, handler: handle, scheduler: MainScheduler.instance)
    let dispatch = dispatchSubject.onNext
    _ = state.debug().subscribe()
    
    dispatch(.increment)
    dispatch(.decrement)
    dispatch(.decrement)
    dispatch(.decrement)
    dispatch(.decrement)
    dispatch(.decrement)
}
