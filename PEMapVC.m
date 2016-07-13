//
//  PEMapVC.m
//
//  Created by Oleksiy Kovtun on 03.01.13.
//  Copyright (c) 2013 Yanpix. All rights reserved.
//

#import "PEMapVC.h"
#import "PESearchParameters.h"
#import "PERequestsSender.h"
#import "PERestaurantAnnotation.h"
#import "PERestaurant.h"

#import "PERestaurantsDownloader.h"
#import "PEMapHelper.h"
#import "PESearchParametersObserver.h"
#import "PEMapViewHelper.h"
#import "PEViewControllerHelper.h"
#import "PELocation.h"
#import "PELog.h"

#import "PEMapListNC.h"
#import "PERestaurantVC.h"

#import "NSDictionary+JSON.h"
#import "UIViewController+NavigationBarTitleViewWithLogoImage.h"
#import "MKMapView_ZoomLevel.h"
#import "UIViewController+Alert.h"

#import "PEMapView.h"
#import "AnnotationView.h"
#import "PESearchView.h"

static CGFloat _UserLocationButtonDefaultY = 19.0f;

typedef NS_ENUM(NSInteger, RestaurantsType) {
  RestaurantsTypeDefault,
  RestaurantsTypeSearchResults
};

@interface PEMapVC () <PERestaurantsDownloaderRecipient, PEMapViewDelegate, PESearchViewDelegate, PESearchParametersObserverDelegate> {
  NSMutableArray<PERestaurant *> *_restaurants;
  NSMutableArray<PERestaurant *> *_searchResultsRestaurants;
  PESearchView                   *_searchView;
  RestaurantsType                 _restaurantsType;
  NSString                      *_searchQuery;
  BOOL                           _searchVeganOnly;
}

@end

@implementation PEMapVC

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  
  if (self != nil) {
    _restaurants = [NSMutableArray array];
    _searchResultsRestaurants = [NSMutableArray array];
    _restaurantsType = RestaurantsTypeDefault;
    
    PERestaurantsDownloader *restaurantsDownloader = [PERestaurantsDownloader sharedInstance];
    
    [restaurantsDownloader addDownloadResultsRecipient:self];
    
    PESearchParametersObserver *searchParametersObserver = [PESearchParametersObserver
                                                            sharedInstance];
    
    [searchParametersObserver addObserver:self];
  }
  
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.edgesForExtendedLayout = UIRectEdgeNone;
  
  UIBarButtonItem *negativeSpacerBBI =
  [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                target:nil
                                                action:nil];
  
  negativeSpacerBBI.width = -5;
  
  UIImage *imageSearch = [UIImage imageNamed:@"navigation_bar_loupe"];
  UIBarButtonItem *searchBBI = [[UIBarButtonItem alloc] initWithImage:imageSearch
                                                                style:UIBarButtonItemStylePlain
                                                               target:self.navigationController
                                                               action:@selector(goToSearchScene)];
  
  self.navigationItem.leftBarButtonItems = @[negativeSpacerBBI, searchBBI];
  
  [self displayLogoImage];
  
  UIImage *imageListIcon = [UIImage imageNamed:@"list_button"];
  UIBarButtonItem *swapToListBBI = [[UIBarButtonItem alloc] initWithImage:imageListIcon
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self.navigationController
                                                                   action:@selector(showListScene)];
  
  self.navigationItem.rightBarButtonItems = @[negativeSpacerBBI, swapToListBBI];
  
  _mapView.mapViewDelegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self initSearchView];
  
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    PESearchParameters *searchParameters = [PESearchParameters sharedInstance];
    PERestaurantsDownloader *restaurantsDownloader = [PERestaurantsDownloader sharedInstance];
    
    [self setMapCenterLocation:searchParameters.location];
    [restaurantsDownloader downloadRestaurantsWithSearchParameters:searchParameters
                                      searchParametersErrorMessage:nil];
  });
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
}

#pragma mark -

- (void)initSearchView {
  PESearchParameters *searchParameters = [PESearchParameters sharedInstance];
  
  [_searchView removeFromSuperview];
  
  CGRect frame = _userLocationButton.frame;
  frame.origin.y = _UserLocationButtonDefaultY;
  _userLocationButton.frame = frame;
  
  if (searchParameters.query.length > 0 || searchParameters.veganOnly) {
    _searchView = [[PESearchView alloc] init];
    
    _searchView.delegate = self;
    
    [_searchView showQuery:searchParameters.query andVeganLabel:searchParameters.veganOnly];
    [_mapView addSubview:_searchView];
    
    CGRect frame = _userLocationButton.frame;
    frame.origin.y = _UserLocationButtonDefaultY + CGRectGetHeight(_searchView.frame);
    _userLocationButton.frame = frame;
  }
}

#pragma mark - IBActions

- (IBAction)centerMapWithUserLocation:(id)sender {
  [ApplicationDelegate googleAnalyticsSendEventWithAction:@"Current Loc" andCategory:@"Map"];
  
  float systemVersion = [UIDevice currentDevice].systemVersion.floatValue;
  
  if (systemVersion < 7.0f) {
    UIButton *locationButton = (UIButton *)sender;
    locationButton.backgroundColor = NAV_BAR_DEFAULT_BUTTON_COLOR;
  }
  
  if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusDenied) {
    PELocation *location = [PELocation sharedInstance];
    
    if (location != nil) {
      [self setMapCenterLocation:location.currentLocation];
    }
  } else {
    NSString *message =
    @"To find meals more quickly, enable Location Services for PlantEaters in your "
    @"iPhone Settings, or tap the search icon to set your location manually";
    
    [[[UIAlertView alloc] initWithTitle:@"Location Services Disabled"
                                message:message
                               delegate:nil
                      cancelButtonTitle:@"Ok"
                      otherButtonTitles:nil] show];
  }
}

#pragma mark - public

- (void)showRegion:(CLCircularRegion *)region {
  MKCoordinateRegion coordinateRegion =
  MKCoordinateRegionMakeWithDistance(region.center, region.radius, region.radius);
  
  _mapView.region = coordinateRegion;
}

#pragma mark - <PESearchViewDelegate>

- (void)goToSearchScene {
  PEMapListNC *mapListNC = (PEMapListNC *)self.navigationController;
  
  [mapListNC goToSearchScene];
}

- (void)clearSearch {
  PESearchParameters *searchParameters = [PESearchParameters sharedInstance];
  
  searchParameters.query = @"";
  searchParameters.veganOnly = NO;
  
  [UIView animateWithDuration:0.3 animations:^{
    CGRect frame = _searchView.frame;
    frame.origin.x = -CGRectGetWidth(_searchView.frame);
    _searchView.frame = frame;
  } completion:^(BOOL finished) {
    CGRect frame = _userLocationButton.frame;
    frame.origin.y = _UserLocationButtonDefaultY;
    _userLocationButton.frame = frame;
  }];
}

#pragma mark - <PEMapViewDelegate>

- (void)calloutHasBeenTouched:(PERestaurant *)restaurant {
  if (restaurant == nil) {
    return;
  }
  
  if (![ApplicationDelegate internetConnectionIsReachable]) {
    [ApplicationDelegate showLostConnectionAlertView];
    
    return;
  }
  
  _mapView.mapViewDelegate = nil;
  
  [PERequestsSender downloadMealsForRestaurantWithID:restaurant.ID
                                              offset:0
                                               limit:[PERestaurantVC mealsLimit]
                                          completion:
   ^(BOOL success, int statusCode, NSError *error, NSData *responseData) {
     if (success) {
       NSError *error = nil;
       NSDictionary *mealsJSON =
       [NSJSONSerialization JSONObjectWithData:responseData
                                       options:NSJSONReadingMutableContainers
                                         error:&error];
       if (error != nil) {
         
       } else {
         PERestaurantVC *restaurantVC = [[PERestaurantVC alloc] initWithRestaurant:restaurant
                                                                         mealsJSON:mealsJSON];
         
         [self.navigationController pushViewController:restaurantVC animated:YES];
       }
     } else {
       [self showAlertViewWithMessage:error.localizedDescription];
     }
     
     _mapView.mapViewDelegate = self;
   }];
}

#pragma mark - <MKMapViewDelegate>

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
  static BOOL mapViewShowsDefaultLocation = YES;
  
  if (mapViewShowsDefaultLocation) {
    mapViewShowsDefaultLocation = NO;
    
    return;
  }
  
  BOOL viewControllerIsVisible = [PEViewControllerHelper isViewControllerVisible:self];
  
  if (!viewControllerIsVisible) {
    return;
  }
  
  PESearchParameters *searchParameters = [PESearchParameters sharedInstance];
  
  if (searchParameters.location == nil) {
    return;
  }
  
  CLLocationDistance visibleHorizontalDistance =
  [PEMapHelper visibleHorizontalDistanceInMapView:_mapView];
  
  CLLocationCoordinate2D center = mapView.region.center;
  CLLocation *location = [[CLLocation alloc] initWithLatitude:center.latitude
                                                    longitude:center.longitude];
  
  searchParameters.location = location;
  searchParameters.radius = visibleHorizontalDistance * 2.25;
  
  [_mapView removeOverlays:_mapView.overlays];
  
  PERestaurantsDownloader *restaurantsDownloader = [PERestaurantsDownloader sharedInstance];
  NSString *errorMessage = nil;
  
  if (![restaurantsDownloader downloadRestaurantsWithSearchParameters:searchParameters
                                         searchParametersErrorMessage:&errorMessage]) {
    NSLog(@"%s. Error: %@", __PRETTY_FUNCTION__, errorMessage);
  }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation {
  MKAnnotationView *annotationView = [PEMapViewHelper viewForAnnotation:annotation
                                                                mapView:mapView];
  
  return annotationView;
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
  [ApplicationDelegate googleAnalyticsSendEventWithAction:@"Pin Tap" andCategory:@"Map"];
  
  if ([view.annotation isKindOfClass:[MKUserLocation class]]) {
    return;
  }
  
  if (![ApplicationDelegate internetConnectionIsReachable]) {
    [ApplicationDelegate showLostConnectionAlertView];
    
    return;
  }
  
  PERestaurantAnnotation *restaurantAnnotation = (PERestaurantAnnotation *)view.annotation;
  PERestaurant *restaurant = restaurantAnnotation.restaurant;
  
  [PERequestsSender downloadAdditionalInformationAboutRestaurantWithID:restaurant.ID completion:
   ^(BOOL success, int statusCode, NSError *error, NSData *responseData) {
     if (statusCode == 404) {
       [_restaurants removeObject:restaurantAnnotation.restaurant];
       [_mapView removeAnnotation:restaurantAnnotation];
       
       return;
     }
     
     NSError *serializationError = nil;
     NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:responseData
                                                          options:0
                                                            error:&serializationError];
     NSString *status = JSON[@"status"];
     
     if (![status isEqualToString:@"OK"]) {
       return;
     }
     
     NSDictionary *additionalInfoJSON = JSON[@"results"];
     
     [restaurant initAdditionalInformationFromJSON:additionalInfoJSON];
     
     PESearchParameters *searchParameters = [PESearchParameters sharedInstance];
     NSString *searchQuery = searchParameters.query;
     BOOL veganOnly = searchParameters.veganOnly;
     
     [PERequestsSender downloadTopRatedMealsForRestaurantWithID:restaurant.ID
                                                 andSearchQuery:searchQuery
                                                      veganOnly:veganOnly
                                                     completion:
      ^(BOOL success, int statusCode, NSError *error, NSData *responseData) {
        NSError *JSONSerializationOptionError = nil;
        
        NSDictionary *topRatedMealsJSON =
        [NSJSONSerialization JSONObjectWithData:responseData
                                        options:kNilOptions
                                          error:&JSONSerializationOptionError];
        
        if (error != nil) {
          return;
        }
        
        [restaurant.additionalInfo initTopRatedMealsFromJSON:topRatedMealsJSON];
        
        if (view.subviews.count > 0) {
          return;
        }
        
        PERestaurant *restaurant = restaurantAnnotation.restaurant;
        AnnotationView *annotationView = (AnnotationView *)view;
        
        [_mapView showCalloutViewForRestaurant:restaurant addedToAnnotationView:annotationView];
        
        CGFloat searchBarHeight = 0.0f;
        
        if (!_searchView.hidden) {
          searchBarHeight = CGRectGetHeight(_searchView.frame);
        }
        
        CLLocationCoordinate2D centerCoordinate =
        [PEMapHelper centerCoordinateForMapView:_mapView
                      withRestaurantCalloutView:annotationView.calloutView
                          addedToAnnotationView:annotationView
                                searchBarHeight:searchBarHeight];
        
        [_mapView setCenterCoordinate:centerCoordinate animated:YES];
      }];
   }];
}

#pragma mark - <PERestaurantsDownloaderRecipient>

- (void)willStartDownloadingRestaurants {
  BOOL searching = [PESearchParameters searching];
  
  if (searching) {
    PESearchParameters *searchParameters = [PESearchParameters sharedInstance];
    
    if ([searchParameters.query isEqualToString:_searchQuery] &&
        searchParameters.veganOnly == _searchVeganOnly) {
      return;
    }
    
    [self removeAnnotationsForRestaurants:_searchResultsRestaurants];
    [_searchResultsRestaurants removeAllObjects];
  }
}

- (void)didDownloadRestaurants:(NSArray *)restaurants andWillDownloadMore:(BOOL)willDownloadMore {
  PESearchParameters *searchParameters = [PESearchParameters sharedInstance];
  
  _searchQuery = searchParameters.query;
  _searchVeganOnly = searchParameters.veganOnly;
  
  [self addRestaurants:restaurants toRestaurants:_restaurants];
  
  BOOL searching = [PESearchParameters searching];
  
  if (searching) {
    [self addRestaurants:restaurants toRestaurants:_searchResultsRestaurants];
  }
  
  switch (_restaurantsType) {
    case RestaurantsTypeDefault: {
      if (searching) {
        _restaurantsType = RestaurantsTypeSearchResults;
        
        [self showAnnotationsForRestaurants:_searchResultsRestaurants];
      } else {
        NSMutableArray *restaurantsM = [NSMutableArray arrayWithArray:restaurants];
        
        [self addAnnotationsForRestaurants:restaurantsM];
      }
    }
      break;
    case RestaurantsTypeSearchResults: {
      if (searching) {
        NSMutableArray *restaurantsM = [NSMutableArray arrayWithArray:restaurants];
        
        [self addAnnotationsForRestaurants:restaurantsM];
      } else {
        _restaurantsType = RestaurantsTypeDefault;
        
        [self showAnnotationsForRestaurants:_restaurants];
      }
    }
      break;
  }
}

- (void)didStopDownloadingRestaurants:(StopReason)stopReason error:(NSError *)error {
  if (error != nil) {
    [[[UIAlertView alloc] initWithTitle:nil
                                message:error.localizedDescription
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
  }
}

#pragma mark -

- (BOOL)restaurantsArray:(NSMutableArray<PERestaurant *> *)restaurants
containsRestaurantWithID:(int)restaurantID {
  for (PERestaurant *restaurant in restaurants) {
    if (restaurant.ID == restaurantID) {
      return YES;
    }
  }
  
  return NO;
}

- (void)addRestaurant:(PERestaurant *)restaurant {
  [_restaurants addObject:restaurant];
  
  if (_restaurantsType == RestaurantsTypeSearchResults) {
    [_searchResultsRestaurants addObject:restaurant];
  }
}

- (void)removeMappAnnotationForRestaurant:(PERestaurant *)restaurant {
  for (id <MKAnnotation> annotation in _mapView.annotations) {
    if ([annotation isKindOfClass:[PERestaurantAnnotation class]]) {
      PERestaurantAnnotation *restaurantAnnotation = (PERestaurantAnnotation *)annotation;
      
      if (restaurantAnnotation.restaurant.ID == restaurant.ID) {
        [_mapView removeAnnotation:restaurantAnnotation];
        
        break;
      }
    }
  }
}

- (NSMutableArray<PERestaurant *> *)restaurants {
  NSMutableArray<PERestaurant *> *restaurants;
  
  switch (_restaurantsType) {
    case RestaurantsTypeDefault:
      restaurants = _restaurants;
      
      break;
    case RestaurantsTypeSearchResults:
      restaurants = _searchResultsRestaurants;
      
      break;
  }
  
  return restaurants;
}

- (BOOL)restaurantHasAnnotation:(PERestaurant *)restaurant {
  for (id <MKAnnotation> annotation in _mapView.annotations) {
    if ([annotation isKindOfClass:[PERestaurantAnnotation class]]) {
      PERestaurantAnnotation *restaurantAnnotation = (PERestaurantAnnotation *)annotation;
      
      if (restaurantAnnotation.restaurant.ID == restaurant.ID) {
        return YES;
      }
    }
  }
  
  return NO;
}

- (void)showAnnotationsForRestaurants:(NSMutableArray<PERestaurant *> *)restaurants {
  [self removeAnnotationsForRestaurantsOutsideArray:restaurants];
  [self addAnnotationsForRestaurants:restaurants];
}

- (void)removeAnnotationsForRestaurantsOutsideArray:(NSMutableArray<PERestaurant *> *)restaurants {
  NSMutableArray<PERestaurantAnnotation *> *restaurantAnnotationsToRemove = [NSMutableArray array];
  
  for (id <MKAnnotation> annotation in _mapView.annotations) {
    if ([annotation isKindOfClass:[PERestaurantAnnotation class]]) {
      PERestaurantAnnotation *restaurantAnnotation = (PERestaurantAnnotation *)annotation;
      BOOL restaurantInAnnotationIsOutsideRestaurantsArray =
      ![self restaurantsArray:restaurants
     containsRestaurantWithID:restaurantAnnotation.restaurant.ID];
      
      if (restaurantInAnnotationIsOutsideRestaurantsArray) {
        [restaurantAnnotationsToRemove addObject:restaurantAnnotation];
      }
    }
  }
  
  [_mapView removeAnnotations:restaurantAnnotationsToRemove];
}

- (void)addAnnotationsForRestaurants:(NSMutableArray<PERestaurant *> *)restaurants {
  int addedAnnotations = 0;
  int skippedAnnotation = 0;
  
  for (PERestaurant *restaurant in restaurants) {
    PERestaurantAnnotation *restaurantAnnotation =
    [self restaurantAnnotationWithRestaurantID:restaurant.ID];
    
    if (restaurantAnnotation != nil) {
      ++skippedAnnotation;
      
      continue;
    }
    
    restaurantAnnotation = [[PERestaurantAnnotation alloc] initWithRestaurant:restaurant];
    
    [_mapView addAnnotation:restaurantAnnotation];
    
    ++addedAnnotations;
  }
}

- (PERestaurantAnnotation *)restaurantAnnotationWithRestaurantID:(int)restaurantID {
  for (id <MKAnnotation> annotation in _mapView.annotations) {
    if ([annotation isKindOfClass:[PERestaurantAnnotation class]]) {
      PERestaurantAnnotation *restaurantAnnotation = (PERestaurantAnnotation *)annotation;
      
      if (restaurantAnnotation.restaurant.ID == restaurantID) {
        return restaurantAnnotation;
      }
    }
  }
  
  return nil;
}

- (void)addRestaurants:(NSArray<PERestaurant *> *)restaurantsToAdd
         toRestaurants:(NSMutableArray<PERestaurant *> *)restaurantsToAddTo {
  for (PERestaurant *restaurant in restaurantsToAdd) {
    if ([self restaurantsArray:restaurantsToAddTo containsRestaurantWithID:restaurant.ID]) {
      continue;
    }
    
    [restaurantsToAddTo addObject:restaurant];
  }
}

- (void)removeAnnotationsForRestaurants:(NSMutableArray<PERestaurant *> *)restaurants {
  NSMutableArray<PERestaurantAnnotation *> *restaurantAnnotations = [NSMutableArray array];
  
  for (PERestaurant *restaurant in restaurants) {
    PERestaurantAnnotation *restaurantAnnotation =
    [self restaurantAnnotationWithRestaurantID:restaurant.ID];
    
    if (restaurantAnnotation == nil) {
      continue;
    }
    
    [restaurantAnnotations addObject:restaurantAnnotation];
  }
  
  [_mapView removeAnnotations:restaurantAnnotations];
}

#pragma mark - map regions

- (MKCoordinateRegion)regionWithNewLocation {
  PESearchParameters *searchParameters = [PESearchParameters sharedInstance];
  MKCoordinateRegion newRegion = MKCoordinateRegionMake(searchParameters.location.coordinate,
                                                        _mapView.region.span);
  
  return newRegion;
}

- (MKCoordinateRegion)regionWithNewRadius {
  PESearchParameters *searchParameters = [PESearchParameters sharedInstance];
  double radiusInMeters = (double)searchParameters.radius;
  double radiusInKilometers = radiusInMeters / 1000;
  double radiusInMiles = radiusInKilometers / 1.6;
  double miles = radiusInMiles;// 5.0;
  double scalingFactor = ABS((cos(2 * M_PI * _mapView.region.center.latitude / 360.0)));
  double milesPerDegree = 69.0;
  
  MKCoordinateSpan span;
  
  span.latitudeDelta = miles / milesPerDegree;
  span.longitudeDelta = miles / (scalingFactor * milesPerDegree);
  
  MKCoordinateRegion newRegion;
  
  newRegion.span = span;
  newRegion.center = _mapView.region.center;
  
  return newRegion;
}

#pragma mark - <PESearchParametersObserverDelegate>

- (void)didUpdateSearchParameter:(SearchParameter)updatedSearchParameter {
  BOOL viewControllerIsVisible = [PEViewControllerHelper isViewControllerVisible:self];
  
  if (viewControllerIsVisible) {
    if (updatedSearchParameter == SearchParameterLocation) {
      PESearchParameters *searchParameters = [PESearchParameters sharedInstance];
      PELocation *location = [PELocation sharedInstance];
      CLLocationDegrees searchLatitude = searchParameters.location.coordinate.latitude;
      CLLocationDegrees searchLongitude = searchParameters.location.coordinate.longitude;
      CLLocationDegrees currentLatitude = location.currentLocation.coordinate.latitude;
      CLLocationDegrees currentLongitude = location.currentLocation.coordinate.longitude;
      BOOL searchLocationIsCurrentLocation = (searchLatitude == currentLatitude &&
                                              searchLongitude == currentLongitude);
      
      if (searchLocationIsCurrentLocation) {
        [self setMapCenterLocation:searchParameters.location];
      }
    }
  } else {
    switch (updatedSearchParameter) {
      case SearchParameterLocation: {
        MKCoordinateRegion newRegion = [self regionWithNewLocation];
        CLLocationDistance distance = [self distanceWithSpan:newRegion.span];
        NSString *logMessage = [NSString stringWithFormat:
                                @"Search location changed. Will update map's region. "
                                @"New region: lat: %f, lon: %f, "
                                @"distance: %f (span.lat: %f, span.lon: %f)",
                                newRegion.center.latitude,
                                newRegion.center.longitude,
                                distance,
                                newRegion.span.latitudeDelta,
                                newRegion.span.longitudeDelta];
        
        [PELog logMessage:logMessage method:__PRETTY_FUNCTION__];
        
        _mapView.region = newRegion;
      }
        break;
      case SearchParameterRadius: {
        MKCoordinateRegion newRegion = [self regionWithNewRadius];
        CLLocationDistance distance = [self distanceWithSpan:newRegion.span];
        NSString *logMessage = [NSString stringWithFormat:
                                @"Search location changed. Will update map's region. "
                                @"New region: lat: %f, lon: %f, "
                                @"distance: %f (span.lat: %f, span.lon: %f)",
                                newRegion.center.latitude,
                                newRegion.center.longitude,
                                distance,
                                newRegion.span.latitudeDelta,
                                newRegion.span.longitudeDelta];
        
        [PELog logMessage:logMessage method:__PRETTY_FUNCTION__];
        
        _mapView.region = newRegion;
      }
        break;
      default:
        break;
    }
  }
}

- (CLLocationDistance)distanceWithSpan:(MKCoordinateSpan)span {
  CLLocationCoordinate2D centerCoordinate = _mapView.centerCoordinate;
  CLLocationDegrees newLat = centerCoordinate.latitude + span.latitudeDelta;
  CLLocationDegrees newLon = centerCoordinate.longitude + span.longitudeDelta;
  CLLocation *newLocation = [[CLLocation alloc] initWithLatitude:newLat longitude:newLon];
  CLLocation *centerLocation = [[CLLocation alloc] initWithLatitude:centerCoordinate.latitude
                                                           longitude:centerCoordinate.longitude];
  CLLocationDistance distance = [centerLocation distanceFromLocation:newLocation];
  
  return distance;
}

- (void)setMapCenterLocation:(CLLocation *)location {
  [_mapView setCenterCoordinate:location.coordinate zoomLevel:15 animated:NO];
}

@end
