//
//  PESearchParametersObserver.m
//
//  Created by Oleksiy Kovtun on 5/30/16.
//  Copyright © 2016 Yanpix. All rights reserved.
//

#import "PESearchParametersObserver.h"

#import "PESearchParameters.h"

@interface PESearchParametersObserver () {
  NSMutableArray<id <PESearchParametersObserverDelegate>> *_observers;
  NSString                                                *_searchParameterQuery;
  CLLocation                                              *_searchParameterLocation;
  NSUInteger                                               _searchParameterRadius;
  BOOL                                                     _searchParameterVeganOnly;
}

@end

@implementation PESearchParametersObserver

+ (instancetype)sharedInstance {
  static PESearchParametersObserver *instance = nil;
  
  if (instance == nil) {
    instance = [[PESearchParametersObserver alloc] init];
  }
  
  return instance;
}

- (instancetype)init {
  self = [super init];
  
  if (self != nil) {
    _observers = [NSMutableArray array];
    
    NSArray<NSString *> *keyPaths = @[ @"query",
                                       @"location",
                                       @"radius",
                                       @"veganOnly",
                                       @"restaurantsPerRequestLimit" ];
    PESearchParameters *searchParameters = [PESearchParameters sharedInstance];
    
    _searchParameterQuery     = [searchParameters.query copy];
    _searchParameterLocation  = [searchParameters.location copy];
    _searchParameterRadius    = searchParameters.radius;
    _searchParameterVeganOnly = searchParameters.veganOnly;
    
    [self observeNewValuesForKeysPaths:keyPaths ofObject:searchParameters];
  }
  
  return self;
}

- (void)addObserver:(id <PESearchParametersObserverDelegate>)observer {
  [_observers addObject:observer];
}

- (void)removeObserver:(id <PESearchParametersObserverDelegate>)observer {
  [_observers removeObject:observer];
}

#pragma mark -

- (void)observeNewValuesForKeysPaths:(NSArray<NSString *> *)keyPaths ofObject:(id)object {
  for (NSString *keyPath in keyPaths) {
    [object addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew context:NULL];
  }
}

- (SearchParameter)searchParameterWithKeyPath:(NSString *)keyPath {
  if ([keyPath isEqualToString:@"query"]) {
    return SearchParameterQuery;
  }
  
  if ([keyPath isEqualToString:@"location"]) {
    return SearchParameterLocation;
  }
  
  if ([keyPath isEqualToString:@"radius"]) {
    return SearchParameterRadius;
  }
  
  if ([keyPath isEqualToString:@"veganOnly"]) {
    return SearchParameterVeganOnly;
  }
  
  if ([keyPath isEqualToString:@"restaurantsPerRequestLimit"]) {
    return SearchParameterRestaurantsPerRequestLimit;
  }
  
  return SearchParameterUnknown;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  SearchParameter searchParameter = [self searchParameterWithKeyPath:keyPath];
  BOOL searchParameterValueChanged = NO;
  PESearchParameters *searchParameters = [PESearchParameters sharedInstance];
  
  switch (searchParameter) {
    case SearchParameterQuery:
      if (![searchParameters.query isEqualToString:_searchParameterQuery]) {
        searchParameterValueChanged = YES;
        
        _searchParameterQuery = [searchParameters.query copy];
      }
      
      break;
    case SearchParameterLocation: {
      CGFloat newLatitude = searchParameters.location.coordinate.latitude;
      CGFloat newLongitude = searchParameters.location.coordinate.longitude;
      CGFloat oldLatitude = _searchParameterLocation.coordinate.latitude;
      CGFloat oldLongitude = _searchParameterLocation.coordinate.longitude;
      
      if (newLatitude != oldLatitude || newLongitude != oldLongitude) {
        searchParameterValueChanged = YES;
        
        _searchParameterLocation = [searchParameters.location copy];
      }
    }
      
      break;
    case SearchParameterRadius:
      if (searchParameters.radius != _searchParameterRadius) {
        searchParameterValueChanged = YES;
        
        _searchParameterRadius = searchParameters.radius;
      }
      
      break;
    case SearchParameterVeganOnly:
      if (searchParameters.veganOnly != _searchParameterVeganOnly) {
        searchParameterValueChanged = YES;
        
        _searchParameterVeganOnly = searchParameters.veganOnly;
      }
      
      break;
    default:
      break;
  }
  
  if (!searchParameterValueChanged) {
    return;
  }
  
  NSLog(@"keyPath = %@, object = %@, change = %@", keyPath, object, change);
  
  for (id <PESearchParametersObserverDelegate> observer in _observers) {
    if ([observer respondsToSelector:@selector(didUpdateSearchParameter:)]) {
      [observer didUpdateSearchParameter:searchParameter];
    }
  }
}

@end
