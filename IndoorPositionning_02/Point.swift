//
//  Point.swift
//  IndoorPositionning_02
//
//  Created by Bitter Lukas on 04.07.16.
//  Copyright © 2016 Bitter Lukas. All rights reserved.
//

import Foundation

/**
 Class allowing to store a point with beacon charateristics, 
 including its coordinates, its minor id and a distance
 */
class Point{
    let minor: Int
    let position: (xCoord: Double, yCoord: Double, zCoord: Double?)
    var distance: Double
    
    init(minor: Int, position: (xCoord: Double, yCoord: Double, zCoord: Double?),  distance: Double) {
        self.position = position
        self.distance = distance
        self.minor = minor
    }
    
}