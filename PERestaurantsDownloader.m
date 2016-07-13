//
//  PERestaurantsDownloader.m
//
//  Created by Oleksiy Kovtun on 5/20/16.
//  Copyright © 2016 Yanpix. All rights reserved.
//

#import "PERestaurantsDownloader.h"
#import "PESearchParameters.h"
#import "PERequestsSender.h"
#import "PESearchParametersObserver.h"

#import "PERestaurant.h"

#import "NSDictionary+JSON.h"

#import "ASIHTTPRequest.h"

const NSInteger ASIHTTPRequestErrorCodeCancelled = 4;

@interface PERestaurantsDownloader () <PESearchParametersObserverDelegate> {
  NSMutableArray     *_recipients;
  NSUInteger          _currentOffset;
  ASIHTTPRequest     *_currentRequest;
  PESearchParameters *_currentSearchParameters;
}

@end

@implementation PERestaurantsDownloader

#pragma mark - init

- (instancetype)init {
  self = [super init];
  
  if (self != nil) {
    _restaurants = @[];
    
    _currentOffset = 0;
    _recipients = [NSMutableArray array];
    _currentRequest = nil;
    
    PESearchParametersObserver *searchParametersObserver =
    [PESearchParametersObserver sharedInstance];
    
    [searchParametersObserver addObserver:self];
  }
  
  return self;
}

+ (instancetype)sharedInstance {
  static PERestaurantsDownloader *instance = nil;
  
  if (instance == nil) {
    instance = [[self alloc] init];
  }
  
  return instance;
}

- (void)addDownloadResultsRecipient:(id <PERestaurantsDownloaderRecipient>)recipient {
  [_recipients addObject:recipient];
}

- (void)removeDownloadResultsRecipient:(id <PERestaurantsDownloaderRecipient>)recipient {
  [_recipients removeObject:recipient];
}

#pragma mark -

- (BOOL)downloadRestaurantsWithSearchParameters:(PESearchParameters *)searchParameters
                   searchParametersErrorMessage:(NSString * __autoreleasing *)errorMessage {
  if (searchParameters.location == nil) {
    *errorMessage = @"Can't start to download information about restaurants because search location is not set.";
    
    return NO;
  }
  
  _currentSearchParameters = [searchParameters copy];
  _currentOffset = 0;
  _restaurants = @[];
  
  if (_currentRequest != nil) {
    [_currentRequest cancel];
    
    for (id <PERestaurantsDownloaderRecipient> recipient in _recipients) {
      if ([recipient respondsToSelector:@selector(didStopDownloadingRestaurants:error:)]) {
        [recipient didStopDownloadingRestaurants:StopReasonWillStartNewDownload error:nil];
      }
    }
  }
  
  for (id <PERestaurantsDownloaderRecipient> recipient in _recipients) {
    if ([recipient respondsToSelector:@selector(willStartDownloadingRestaurants)]) {
      [recipient willStartDownloadingRestaurants];
    }
  }
  
  [self downloadRestaurants];
  
  return YES;
}

#pragma mark - private methods

- (void)downloadRestaurants {
  _currentRequest =
  [PERequestsSender downloadRestaurants:_currentSearchParameters offset:_currentOffset completion:
   ^(BOOL success, int statusCode, NSError *error, NSData *responseData) {
     NSLog(@"\nsuccess = %d\nstatus code = %d\nerror = %@", success, statusCode, error);
     
     _currentRequest = nil;
     
     if (!success) {
       if (error.code == ASIHTTPRequestErrorCodeCancelled) {
         return;
       }
       
       for (id <PERestaurantsDownloaderRecipient> recipient in _recipients) {
         if ([recipient respondsToSelector:@selector(didStopDownloadingRestaurants:error:)]) {
           [recipient didStopDownloadingRestaurants:StopReasonRequestFailed error:error];
         }
       }
       
       return;
     }
     
     NSError *serializationError = nil;
     NSDictionary *response = [NSJSONSerialization JSONObjectWithData:responseData
                                                              options:NSJSONReadingMutableContainers
                                                                error:&serializationError];
     
     if (serializationError != nil) {
       for (id <PERestaurantsDownloaderRecipient> recipient in _recipients) {
         if ([recipient respondsToSelector:@selector(didStopDownloadingRestaurants:error:)]) {
           [recipient didStopDownloadingRestaurants:StopReasonServerResponseSerializationFailed
                                              error:serializationError];
         }
       }
       
       return;
     }
     
     NSDictionary *resultsDict = response[@"results"];
     NSArray *restaurantsDicts = resultsDict[@"restaurants"];
     int restaurantsFoundNumber = [resultsDict intFromObjectForKey:@"total_found"];
     NSMutableArray *restaurantsM = [NSMutableArray arrayWithCapacity:restaurantsDicts.count];
     
     for (NSDictionary *restaurantParameters in restaurantsDicts) {
       PERestaurant *restaurant = [[PERestaurant alloc] initFromJSON:restaurantParameters];
       
       [restaurantsM addObject:restaurant];
     }
     
     _restaurants = [_restaurants arrayByAddingObjectsFromArray:restaurantsM];
     
     _currentOffset += _currentSearchParameters.restaurantsPerRequestLimit;
     
     BOOL downloadMoreRestaurants = NO;
     
     if (_currentOffset < restaurantsFoundNumber) {
       downloadMoreRestaurants = YES;
     }
     
     NSArray *restaurants = [NSArray arrayWithArray:restaurantsM];
     
     for (id <PERestaurantsDownloaderRecipient> recipient in _recipients) {
       if ([recipient respondsToSelector:@selector(didDownloadRestaurants:andWillDownloadMore:)]) {
         [recipient didDownloadRestaurants:restaurants andWillDownloadMore:downloadMoreRestaurants];
       }
     }
     
     if (downloadMoreRestaurants) {
       [self downloadRestaurants];
     }
   }];
}

#pragma mark - <PESearchParametersObserverDelegate>

- (void)didUpdateSearchParameter:(SearchParameter)updatedSearchParameter {
  if (updatedSearchParameter == SearchParameterUnknown) {
    return;
  }
  
  PESearchParameters *searchParametes = [PESearchParameters sharedInstance];
  NSString *errorMessage = nil;
  
  if (![self downloadRestaurantsWithSearchParameters:searchParametes
                        searchParametersErrorMessage:&errorMessage]) {
    NSLog(@"%s. Error: %@", __PRETTY_FUNCTION__, errorMessage);
  }
}

@end
