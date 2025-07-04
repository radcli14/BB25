//
//  Entity+Extensions.swift
//  BB25
//
//  Created by Eliott Radcliffe on 7/4/25.
//

import Foundation
import RealityKit

extension Entity {
    var rightWheel: HasPhysicsBody? {
        findEntity(named: "RightHub") as? HasPhysicsBody
    }
    
    var leftWheel: HasPhysicsBody? {
        findEntity(named: "LeftHub") as? HasPhysicsBody
    }
}
