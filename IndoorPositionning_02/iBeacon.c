//
//  iBeacon.c
//  IndoorPositionning_02
//
//  Created by Bitter Lukas on 14.07.16.
//  Copyright © 2016 Bitter Lukas. All rights reserved.
//

#include "iBeacon.h"

KalmanFilter alloc_filter_position2d(double noise) {
    /* The state model has four dimensions:
     x, y, x', y'
     Each time step we can only observe position, not velocity, so the
     observation vector has only two dimensions.
     */
    KalmanFilter f = alloc_filter(4, 2);
    
    /* Assuming the axes are rectilinear does not work well at the
     poles, but it has the bonus that we don't need to convert between
     lat/long and more rectangular coordinates. The slight inaccuracy
     of our physics model is not too important.
     */
    set_identity_matrix(f.state_transition);
    set_seconds_per_timestep_position(f, 1.0);
    
    /* We observe (x, y) in each time step */
    set_matrix(f.observation_model,
               1.0, 0.0, 0.0, 0.0,
               0.0, 1.0, 0.0, 0.0);    
    
    set_identity_matrix(f.process_noise_covariance);
    
    /* Noise in our observation */
    set_matrix(f.observation_noise_covariance,
               noise, 0.0,
               0.0, noise);
    
    /* The start position is totally unknown, so give a high variance */
    set_matrix(f.state_estimate, 0.0, 0.0, 0.0, 0.0);
    set_identity_matrix(f.estimate_covariance);
    
    return f;
}


/* The position units are in thousandths of latitude and longitude.
 The velocity units are in thousandths of position units per second.
 
 So if there is one second per timestep, a velocity of 1 will change
 the lat or long by 1 after a million timesteps.
 
 Thus a typical position is hundreds of thousands of units.
 A typical velocity is maybe ten.
 */
void set_seconds_per_timestep_position(KalmanFilter f,
                              double seconds_per_timestep) {
    /* unit_scaler accounts for the relation between position and
     velocity units */
    double unit_scaler = 0.001;
    f.state_transition.data[0][2] = unit_scaler * seconds_per_timestep;
    f.state_transition.data[1][3] = unit_scaler * seconds_per_timestep;
}

void update_position(KalmanFilter f, double yPos, double xPos,
                       double seconds_since_last_timestep) {
    set_seconds_per_timestep_position(f, seconds_since_last_timestep);
    set_matrix(f.observation, yPos, xPos);
    update(f);
}

void get_position(KalmanFilter f, double* yPos, double* xPos) {
    *yPos = f.state_estimate.data[0][0];
    *xPos = f.state_estimate.data[1][0];
}




