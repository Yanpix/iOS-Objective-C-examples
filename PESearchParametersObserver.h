//
//  PESearchParametersObserver.h
//
//  Created by Oleksiy Kovtun on 5/30/16.
//  Copyright © 2016 Yanpix. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SearchParameter) {
  SearchParameterQuery = 0,
  SearchParameterLocation,
  SearchParameterRadius,
  SearchParameterVeganOnly,
  SearchParameterRestaurantsPerRequestLimit,
  SearchParameterUnknown
};

@protocol PESearchParametersObserverDelegate <NSObject>

- (void)didUpdateSearchParameter:(SearchParameter)updatedSearchParameter;

@end

@interface PESearchParametersObserver : NSObject

+ (instancetype)sharedInstance;

- (void)addObserver:(id <PESearchParametersObserverDelegate>)observer;
- (void)removeObserver:(id <PESearchParametersObserverDelegate>)observer;

@end
