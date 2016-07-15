//
//  iBeacon.h
//  IndoorPositionning_02
//
//  Created by Bitter Lukas on 14.07.16.
//  Copyright © 2016 Bitter Lukas. All rights reserved.
//
//  Code and comments adapted from https://github.com/lacker/ikalman
//

#ifndef iBeacon_h
#define iBeacon_h

#include <stdio.h>
#include "kalman.h"

/* To use these functions:
 
 1. Start with a KalmanFilter created by alloc_filter_position2d.
 2. At fixed intervals, call update_position2d with the lat/long.
 3. At any time, to get an estimate for the current position use the function:
 get_position
 */

/* Create a GPS filter that only tracks two dimensions of position and
 velocity.
 The inherent assumption is that changes in velocity are randomly
 distributed around 0.
 Noise is a parameter you can use to alter the expected noise.
 1.0 is the original, and the higher it is, the more a path will be
 "smoothed".
 Free with free_filter after using. */
KalmanFilter alloc_filter_position2d(double noise);

/* Set the seconds per timestep in the velocity2d model. */
void set_seconds_per_timestep_position(KalmanFilter f,
                              double seconds_per_timestep);

/* Update the velocity2d model with new gps data. */
void update_position(KalmanFilter f, double yPos, double xPos,
                       double seconds_since_last_update);

/* Extract a lat long from a velocity2d Kalman filter. */
void get_position(KalmanFilter f, double* yPos, double* xPos);


#endif /* iBeacon_h */
