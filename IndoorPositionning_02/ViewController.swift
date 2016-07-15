//
//  ViewController.swift
//  IndoorPositionning_02
//
//  Created by Bitter Lukas on 02.07.16.
//  Copyright © 2016 Bitter Lukas. All rights reserved.
//

import UIKit
import MobileCoreServices
import CoreLocation
import Foundation

class ViewController: UIViewController, CLLocationManagerDelegate, EILIndoorLocationManagerDelegate {
    
    // Drawing and coordinates
    var opacity: CGFloat = 1.0
    var dRatio: CGFloat = 0.0
    var angleRad: Double = 0.0
    var xAxePoint1 = CGPoint()
    var xAxePoint2 = CGPoint()
    var xAxeDistance: CGFloat = 0.0
    var mapPath = [Int:CGPoint]()
    
    // Beacon management
    let locationManager = CLLocationManager()
    var region = CLBeaconRegion()
    var rangedBeaconsDic = [Int:Point]()
    var rangedPositions = [CGPoint]()
    
    // Kalman filter
    var kalmanFilter = KalmanFilter()
    var timestamp = 0.0
    var oldTimestamp = NSDate()
    var firstRanging = true
    var xPointer = Double()
    var yPointer = Double()
    
    @IBOutlet weak var mainImageView: UIImageView!
    
    @IBOutlet weak var positionImageView: UIImageView!
    
    
    /***********************************
     ***           Overrides
     ***********************************/
    
    override func viewDidLoad() {
        super.viewDidLoad()
        placeBeaconsAndMapPoints()
        
        // init log file headers
        appendLog(String("X, Y, Xk, Yk"), fileName: "logKalman.csv")
        
        locationManager.delegate = self;if (CLLocationManager.authorizationStatus() != CLAuthorizationStatus.AuthorizedWhenInUse) {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.startRangingBeaconsInRegion(region)
    }
    
    override func viewDidAppear(animated: Bool) {
        
        // Draw the map and the beacons
        mapDrawing()
        drawBeacons()
        
        kalmanFilter = alloc_filter_position2d(10)
        //runTests()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    /***********************************
     *** Delegate EstimoteIndoorLocation
     *** location manager functions
     ***********************************/
    
    /**
     Called when error occurs when updating the position.
     */
    func indoorLocationManager(manager: EILIndoorLocationManager,
                               didFailToUpdatePositionWithError error: NSError) {
        print("failed to update position: \(error)")
    }
    
    
    /**
     Tells the delegate that one or more beacons are in range.
    */
    func locationManager(manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], inRegion region: CLBeaconRegion) {
        // Manage timestamp
        let newTimeStamp = NSDate()
        let timestamp = newTimeStamp.timeIntervalSinceDate(oldTimestamp)
        oldTimestamp = newTimeStamp
        
        // Store ranged beacons
        print("new ranging")
        for b in beacons {
            rangedBeaconsDic[Int(b.minor)]?.distance = b.accuracy
        }
        
        // Define current location with trilateration
        if rangedBeaconsDic.count > 2 {
            let pRes: CGPoint = trilateration(rangedBeaconsDic)
            
            update_position(kalmanFilter, Double(pRes.y), Double(pRes.x), timestamp)
            if(!firstRanging) {
                get_position(kalmanFilter, &yPointer, &xPointer)
            }
            else {
                firstRanging = false
            }
            
            // Debug
            print("x: \(pRes.x),y:  \(pRes.y)")
            print("Xk: \(xPointer), Yk: \(yPointer)")
            appendLog(String("\(pRes.x), \(pRes.y), \(xPointer), \(yPointer)"), fileName: "logKalman.csv")
            
            // TODO: keep only last ranged positions and clear the other ones from screen
            rangedPositions.append(pRes)
            drawPosition(pRes, pointOpacity: opacity)
        }
    }
    
    /***********************************
     **** Map and coordinates functions
     ***********************************/
    
    func placeBeaconsAndMapPoints() {
        createMapPoints()
        kontaktBeacons()
        //estimoteBeacons()
    }
    
    /**
     It places the walls coordinates on the screen, in points
     */
    func createMapPoints(){
        // Points defining walls corners on map for a custom location
        mapPath[0] = CGPoint(x: 315, y: 180)
        mapPath[1] = CGPoint(x: 432, y: 360)
        mapPath[2] = CGPoint(x: 277, y: 456)
        mapPath[3] = CGPoint(x: 160.5, y: 284.5)
    }
    
    /**
     It defines custom beacon positions on map with local coordinates, in meter
     */
    func kontaktBeacons() {
        let b1 = Point(minor: 19753, position: (xCoord: 4.22, yCoord: 1.87, zCoord: 0), distance: 2.0)
        let b2 = Point(minor: 20414, position: (xCoord: 2.22, yCoord: 0, zCoord: 0), distance: 1.47)
        let b3 = Point(minor: 43690, position: (xCoord: 0, yCoord: 1.47, zCoord: 0), distance: 2.22)
        
        rangedBeaconsDic[b1.minor] = b1
        rangedBeaconsDic[b2.minor] = b2
        rangedBeaconsDic[b3.minor] = b3
        
        region = CLBeaconRegion(proximityUUID: NSUUID(UUIDString: "F7826DA6-4fA2-4E98-8024-BC5B71E0893E")!, identifier: "Kontakt")
    }
    
    /**
     It defines custom beacon positions on map with local coordinates, in meter
     */
    func estimoteBeacons() {
        let b1 = Point(minor: 28621, position: (xCoord: 4.22, yCoord: 1.87, zCoord: 0), distance: 2.0) // Mint
        let b2 = Point(minor: 55797, position: (xCoord: 3.7, yCoord: 0, zCoord: 0), distance: 1.47) // Blueberry
        let b3 = Point(minor: 13820, position: (xCoord: 2.8, yCoord: 3.65, zCoord: 0), distance: 2.22) // Ice
        
        rangedBeaconsDic[b1.minor] = b1
        rangedBeaconsDic[b2.minor] = b2
        rangedBeaconsDic[b3.minor] = b3
        
        region = CLBeaconRegion(proximityUUID: NSUUID(UUIDString: "B9407F30-F5F8-466E-AFF9-25556B57FE6D")!, identifier: "Estimotes")
    }
    
    /**
     Get the screen coordinates out of local coordinates
     
     Give a point with local coordinates and get the scrren coordinates as result.
     
     NB: the function had to be split in several steps due to lack of mempry of the used computer. I.e c_1, c_2 and c_3 could have been calculated in one line.
     
     :param: posLocal CGPoint with local coordinates
     
     :return: CGPoint with screen coordinates
     */
    func getViewPos(posLocal: CGPoint) -> CGPoint {
        
        let xCoord = posLocal.x * self.dRatio
        let yCoord = posLocal.y * self.dRatio
        
        var viewPos = CGPoint()
        let c_1 = cos(angleRad)*Double(xCoord)
        let c_2 = sin(angleRad)*Double(yCoord)
        let c_3 = Double(mapPath[0]!.x)
        viewPos.x = CGFloat(c_1 + c_2 + c_3)
        
        let c_4 = -sin(angleRad)*Double(xCoord)
        let c_5 = cos(angleRad)*Double(yCoord)
        let c_6 = Double(mapPath[0]!.y)
        viewPos.y = CGFloat(c_4 + c_5 + c_6)
        
        return viewPos
    }
    
    
    /***********************************
     ****     Kalman test functions
     ***********************************/
    
    /**
     It run tests for Kalman filter
     
     First it runs a test in C code, from the original library, then it runs the same test, 
     but translated in Swift language. So one can compare the outputs and be sure they do match.
     */
    func runTests() {
        print("*************")
        print("C test")
        print("*************")
        test_train()
        print("*************")
        print("Swift test")
        print("*************")
        test_train_swift()
    }
    
    /**
     Test for kalman filter, rewritten in Swift from it's original library
     
     The result should be close to (10, 1)
    */
    func test_train_swift() {
        let f: KalmanFilter = alloc_filter(2, 1);
        
        /* The train state is a 2d vector containing position and velocity.
         Velocity is measured in position units per timestep units. */
        // State transition matrix
        let initialArray1 = [1.0, 1.0, 0.0, 1.0]
        set_matrix_array(f.state_transition, initialArray1)
        
        /* We only observe position */
        let initialArray2 = [1.0, 0.0]
        set_matrix_array(f.observation_model, initialArray2)
        
        /* The covariance matrices are blind guesses */
        set_identity_matrix(f.process_noise_covariance);
        set_identity_matrix(f.observation_noise_covariance);
        
        /* Our knowledge of the start position is incorrect and unconfident */
        let deviation = 1000.0;
        let initialArray3 = [10 * deviation]
        set_matrix_array(f.state_estimate, initialArray3)
        
        set_identity_matrix(f.estimate_covariance);
        scale_matrix(f.estimate_covariance, deviation * deviation);
        
        print("estimated position: \(f.state_estimate.data[0][0])")
        print("estimated velocity: \(f.state_estimate.data[1][0])")
        
        /* Test with time steps of the position gradually increasing */
        for i in 0..<10 {
            let initialArray4 = [Double(i)]
            set_matrix_array(f.observation, initialArray4)
            update(f);
        }
        
        /* Our prediction should be close to (10, 1) */
        print("estimated position: \(f.state_estimate.data[0][0])")
        print("estimated velocity: \(f.state_estimate.data[1][0])")
        
        free_filter(f);
    }
    
    /**
     Test for kalman filter with gps model. 
     Rewritten in Swift from it's original library and adapted for the purpose of this program
     */
    func gps_test() {
        kalmanFilter = alloc_filter(4, 1);
        
        /* The train state is a 2d vector containing position and velocity.
         Velocity is measured in position units per timestep units. */
        // State transition matrix
        let initialArray1 = [1.0, 0.0, 1.0, 0.0,
                             0.0, 1.0, 0.0, 1.0,
                             0.0, 0.0, 1.0, 0.0,
                             0.0, 0.0, 0.0, 1.0]
        set_matrix_array(kalmanFilter.state_transition, initialArray1)
        
        /* We only observe position */
        let initialArray2 = [1.0, 0.0, 1.0, 0.0]
        set_matrix_array(kalmanFilter.observation_model, initialArray2)
        
        /* The covariance matrices are blind guesses */
        set_identity_matrix(kalmanFilter.process_noise_covariance);
        set_identity_matrix(kalmanFilter.observation_noise_covariance);
        
        /* Our knowledge of the start position is incorrect and unconfident */
        let deviation = 1000.0;
        let initialArray3 = [10 * deviation]
        set_matrix_array(kalmanFilter.state_estimate, initialArray3)
        
        set_identity_matrix(kalmanFilter.estimate_covariance);
        scale_matrix(kalmanFilter.estimate_covariance, deviation * deviation);
        
        print("estimated position: \(kalmanFilter.state_estimate.data[0][0])")
        print("estimated velocity: \(kalmanFilter.state_estimate.data[1][0])")
    }
    
    
    /***********************************
    ****     Drawing functions
    ***********************************/
    
    /**
     Draws the map and sets some attributes to draw further elements, e.g: positions and beacons
    */
    func mapDrawing() {
        // Define X axe, by setting two points with Y coordinate = 0, in local coordinates
        xAxePoint1 = mapPath[0]!
        xAxePoint2 = mapPath[1]!
        // Real distance between these points in meters
        xAxeDistance = 16
        
        // Define ratio between local coordinates and screen coordinates
        let dX = xAxePoint2.x - xAxePoint1.x
        let dY = xAxePoint2.y - xAxePoint1.y
        let distanceOnPlan = sqrt(dX*dX + dY*dY)
        dRatio = distanceOnPlan/xAxeDistance
        // Define angle between local X-axe and Northpole axe
        angleRad = -Double(atan2(dY,dX)) + 360.0 * M_PI / 180.0
        
        UIGraphicsBeginImageContext(view.frame.size)
        let context = UIGraphicsGetCurrentContext()
        
        mainImageView.image?.drawInRect(CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height))
        
        CGContextSetLineWidth(context, 2.0)
        CGContextSetStrokeColorWithColor(context,
                                         UIColor.redColor().CGColor)

        CGContextMoveToPoint(context, mapPath[0]!.x, mapPath[0]!.y)
        for i in 1...mapPath.count-1 {
            CGContextAddLineToPoint(context, mapPath[i]!.x, mapPath[i]!.y)
        }
        CGContextAddLineToPoint(context, mapPath[0]!.x, mapPath[0]!.y)
        CGContextStrokePath(context)
        
        mainImageView.image = UIGraphicsGetImageFromCurrentImageContext()
        mainImageView.alpha = opacity
        UIGraphicsEndImageContext()
    }
    
    /**
     Draws the beacons from rangedBeaconsDic
    */
    func drawBeacons()
    {
        for beacon in rangedBeaconsDic
        {
            drawPoint(beacon.1, color: UIColor.blackColor().CGColor, lineWidth: 4, size: 2, pointOpacity: opacity)
        }
    }
    
    /**
     Draws a point on the map
     
     :param: pointPosLocal Point with local coordinates
     :param: color The color of the point
     :param: lineWidth The width of the line drawing the point
     :param: size The size of the rectangle surrounding the point
     :param: pointOpacity The opacity of the points color
     */
    func drawPoint(pointPosLocal: Point, color: CGColor, lineWidth: CGFloat, size: CGFloat, pointOpacity: CGFloat){
        
        let pos = getViewPos(CGPoint(x: pointPosLocal.position.xCoord, y: pointPosLocal.position.yCoord))
        
        UIGraphicsBeginImageContext(view.frame.size)
        let context = UIGraphicsGetCurrentContext()
        
        mainImageView.image?.drawInRect(CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height))
        
        CGContextSetLineWidth(context, lineWidth)
        CGContextSetStrokeColorWithColor(context, color)//UIColor.blackColor().CGColor)
        let rectangle = CGRectMake(pos.x,pos.y, size, size)
        CGContextAddEllipseInRect(context, rectangle)
        CGContextStrokePath(context)
        
        mainImageView.image = UIGraphicsGetImageFromCurrentImageContext()
        mainImageView.alpha = pointOpacity
        UIGraphicsEndImageContext()
    }
    
    /**
     Draws the given position on the map
     
     :param: pos CGPoint with local coordinates
     :param: pointOpacity The opacity of the points color
    */
    func drawPosition(pos: CGPoint, pointOpacity: CGFloat) {
        
        UIGraphicsBeginImageContext(view.frame.size)
        let context = UIGraphicsGetCurrentContext()
        
        mainImageView.image?.drawInRect(CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height))
        
        let viewPos = getViewPos(pos)
        
        CGContextSetLineWidth(context, 4.0)
        CGContextSetStrokeColorWithColor(context,
                                         UIColor.blueColor().CGColor)
        let rectangle = CGRectMake(viewPos.x, viewPos.y, 5, 5)
        CGContextAddEllipseInRect(context, rectangle)
        CGContextStrokePath(context)
        
        mainImageView.image = UIGraphicsGetImageFromCurrentImageContext()
        mainImageView.alpha = 1.0
        UIGraphicsEndImageContext()
    }
}

