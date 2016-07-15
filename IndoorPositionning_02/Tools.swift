//
//  Tools.swift
//  IndoorPositionning_02
//
//  Created by Bitter Lukas on 14.07.16.
//  Copyright © 2016 Bitter Lukas. All rights reserved.
//

import Foundation


/***********************************
 ****     Log functions
 ***********************************/
// code inspired from https://forums.developer.apple.com/thread/23656

/**
 Appends a string to a logfile.
 
 To use it, simply call appendLog("my text", "logfile.csv")
 
 :param: s The input value containing the text to append to the file.
 :param: fileName The file name to which the drting will be appended.
 
 */
func appendLog(s: String, fileName: String){
    let path = getDocumentsDirectory()
    let fileNameAndPath = path.stringByAppendingPathComponent(fileName)
    let fileAndPath = NSURL(fileURLWithPath: fileNameAndPath as String)
    
    var text = NSString()
    
    //reading
    do {
        text = try NSString(contentsOfURL: fileAndPath, encoding: NSUTF8StringEncoding)
    }
    catch { print("logfile read failed") }
    
    text = (text as String) + "\n" + s
    
    //writing
    do {
        try text.writeToFile(fileNameAndPath, atomically: true, encoding: NSUTF8StringEncoding)
    }
    catch { print("logfile write failed") }
}

func quoteColumn(column: String) -> String {
    if column.containsString(",") || column.containsString("\"") {
        return "\"" + column.stringByReplacingOccurrencesOfString("\"", withString: "\"\"") + "\""
    } else {
        return column
    }
}

func commaSeparatedValueStringForColumns(columns: [String]) -> String {
    return columns.map {column in
        quoteColumn(column)
        }.joinWithSeparator(",")
}

func commaSeparatedValueDataForLines(lines: [[String]]) -> NSData {
    return lines.map { column in
        commaSeparatedValueStringForColumns(column)
        }.joinWithSeparator("\r\n").dataUsingEncoding(NSUTF8StringEncoding)!
}

func getDocumentsDirectory() -> NSString {
    let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
    let documentsDirectory = paths[0]
    return documentsDirectory
}


/***********************************
 ****     Coordinate functions
 ***********************************/


/**
 Calculates coordinates using trilateration between trhee points
 
 To use it, simply call it with a dictionary containing at least three Points.
 It will take the three first ones and calculate an estimated position based on their coordinates 
 and the distances to them
 
 Adapted code for the purpose of this program form original repository: 
 https://gist.github.com/AngeloGiurano/7a6ee79535b835aa1791
 
 :param: _rangedBeaconsDic The input value containing the text to append to the file.
 
 :return: CGPoint The estimated intersection point coordinate
 
 */
func trilateration(rangedBeaconsDic: [Int:Point]) -> CGPoint {
    
    // Get the three first ranged beacons
    var intIndex = 0 // where intIndex < myDictionary.count
    var index = rangedBeaconsDic.startIndex.advancedBy(intIndex) // index 1
    let point1 = rangedBeaconsDic[index].1
    
    intIndex = 1
    index = rangedBeaconsDic.startIndex.advancedBy(intIndex) // index 2
    let point2 = rangedBeaconsDic[index].1
    
    intIndex = 2
    index = rangedBeaconsDic.startIndex.advancedBy(intIndex) // index 3
    let point3 = rangedBeaconsDic[index].1
    
    
    let x1 = point1.position.xCoord
    let y1 = point1.position.yCoord
    
    let x2 = point2.position.xCoord
    let y2 = point2.position.yCoord
    
    let x3 = point3.position.xCoord
    let y3 = point3.position.yCoord
    
    
    var P1 = [x1, y1]
    var P2 = [x2, y2]
    var P3 = [x3, y3]
    
    if let z1 = point1.position.zCoord {
        P1.append(z1)
    }
    
    if let z2 = point2.position.zCoord {
        P2.append(z2)
    }
    
    if let z3 = point3.position.zCoord {
        P3.append(z3)
    }
    let DistA = point1.distance
    let DistB = point2.distance
    let DistC = point3.distance
    
    var ex: [Double] = []
    var tmp: Double = 0
    var P3P1: [Double] = []
    var ival: Double = 0
    var ey: [Double] = []
    var P3P1i: Double = 0
    var ez: [Double] = []
    var ezx: Double = 0
    var ezy: Double = 0
    var ezz: Double = 0
    
    // ex = (P2 - P1)/||P2-P1||
    for i in 0 ..< P1.count {
        let t1 = P2[i]
        let t2 = P1[i]
        let t:Double = t1-t2
        tmp += (t*t)
    }
    
    for i in 0 ..< P1.count {
        let t1 = P2[i]
        let t2 = P1[i]
        let exx: Double = (t1-t2)/sqrt(tmp)
        ex.append(exx)
    }
    
    // i = ex(P3 - P1)
    for i in 0 ..< P3.count {
        let t1 = P3[i]
        let t2 = P1[i]
        let t3 = t1-t2
        P3P1.append(t3)
    }
    
    for i in 0 ..< ex.count {
        let t1 = ex[i]
        let t2 = P3P1[i]
        ival += (t1*t2)
    }
    //ey = (P3 - P1 - i · ex) / ‖P3 - P1 - i · ex‖
    for i in 0 ..< P3.count {
        let t1 = P3[i]
        let t2 = P1[i]
        let t3 = ex[i] * ival
        let t = t1 - t2 - t3
        P3P1i += (t*t)
    }
    
    
    for i in 0 ..< P3.count {
        let t1 = P3[i]
        let t2 = P1[i]
        let t3 = ex[i] * ival
        let eyy = (t1 - t2 - t3)/sqrt(P3P1i)
        ey.append(eyy)
    }
    
    if P1.count == 3 {
        ezx = ex[1]*ey[2] - ex[2]*ey[1]
        ezy = ex[2]*ey[0] - ex[0]*ey[2]
        ezz = ex[0]*ey[1] - ex[1]*ey[0]
    }
    
    ez.append(ezx)
    ez.append(ezy)
    ez.append(ezz)
    
    //d = ‖P2 - P1‖
    let d:Double = sqrt(tmp)
    var j:Double = 0
    
    //j = ey(P3 - P1)
    for i in 0 ..< ey.count {
        let t1 = ey[i]
        let t2 = P3P1[i]
        j += (t1*t2)
    }
    //x = (r12 - r22 + d2) / 2d
    let x = (pow(DistA,2) - pow(DistB,2) + pow(d,2))/(2*d)
    //y = (r12 - r32 + i2 + j2) / 2j - ix / j
    let y = ((pow(DistA,2) - pow(DistC,2) + pow(ival,2) + pow(j,2))/(2*j)) - ((ival/j)*x)
    
    var z: Double = 0
    let res = CGPoint(x: x, y: y)
    //print(x)
    //print(y)
    if P1.count == 3 {
        z = sqrt(pow(DistA,2) - pow(x,2) - pow(y,2))
    }
    
    var unknowPoint:[Double] = []
    
    for i in 0 ..< P1.count {
        let t1 = P1[i]
        let t2 = ex[i] * x
        let t3 = ey[i] * y
        let t4 = ez[i] * z
        let unknownPointCoord = t1 + t2 + t3 + t4
        unknowPoint.append(unknownPointCoord)
    }
    
    return res
    
}


