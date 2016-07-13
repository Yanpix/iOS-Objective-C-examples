//
//  PEMapVC.h
//
//  Created by Oleksiy Kovtun on 03.01.13.
//  Copyright (c) 2013 Yanpix. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

@class PEMapView;

@interface PEMapVC : UIViewController <MKMapViewDelegate> {
@private
  IBOutlet PEMapView *_mapView;
  IBOutlet UIButton  *_userLocationButton;
}

- (IBAction)centerMapWithUserLocation:(id)sender;

- (void)showRegion:(CLCircularRegion *)region;

@end
