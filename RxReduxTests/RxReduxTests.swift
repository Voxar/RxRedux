//
//  RxReduxTests.swift
//  RxReduxTests
//
//  Created by Patrik Sjöberg on 2018-03-15.
//  Copyright © 2018 Patrik Sjöberg. All rights reserved.
//

import XCTest
@testable import RxRedux
import RxSwift
import RxTest
import RxBlocking

class RxReduxTests: XCTestCase {
    var scheduler: TestScheduler!
    var disposeBag: DisposeBag!
    
    override func setUp() {
        super.setUp()
        scheduler = TestScheduler(initialClock: 0)
        disposeBag = DisposeBag()
    }
    
    func testExample() {
        XCTAssertEqual(
            Model.reduce(state: Model(counter: 0), action: .userAction(.increment)),
            Next(state: Model(counter: 1, flash: false), effects: []),
            "The counter value increments"
        )
        
        XCTAssertEqual(
            Model.reduce(state: Model(counter: 1), action: .userAction(.decrement)),
            Next(state: Model(counter: 0, flash: false), effects: []),
            "The counter value decrements"
        )
        
        XCTAssertEqual(
            Model.reduce(state: Model(counter: 0), action: .userAction(.decrement)),
            Next(state: nil, effects: [.flash]),
            "State is not affected and a flash effect is emitted"
        )
        
        XCTAssertEqual(
            Model.reduce(state: Model(flash: false), action: .setFlash(true)),
            Next(state: Model(flash: true), effects: [])
        )
        
        XCTAssertEqual(
            Model.reduce(state: Model(flash: true), action: .setFlash(false)),
            Next(state: Model(flash: false), effects: [])
        )
    }
    
    func testFlashEffect() {
        scheduler = TestScheduler(initialClock: 0, resolution: 100)
        let observer = scheduler.createObserver(Model.Action.self)
        
        Model.handle(effect: .flash, scheduler: scheduler)
            .bind(to: observer)
            .disposed(by: disposeBag)
        
        scheduler.start()
        
        XCTAssertEqual(observer.events, [
            .next(1, Model.Action.setFlash(true)),
            .next(2, Model.Action.setFlash(false)),
            .next(3, Model.Action.setFlash(true)),
            .next(4, Model.Action.setFlash(false)),
            .completed(4)
        ])
    }
    
}
