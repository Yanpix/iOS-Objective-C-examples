//
//  PERestaurantsDownloader.h
//
//  Created by Oleksiy Kovtun on 5/20/16.
//  Copyright © 2016 Yanpix. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
  StopReasonRequestFailed = 0,
  StopReasonServerResponseSerializationFailed,
  StopReasonWillStartNewDownload
} StopReason;

@protocol PERestaurantsDownloaderRecipient <NSObject>

- (void)willStartDownloadingRestaurants;
- (void)didDownloadRestaurants:(NSArray *)restaurants andWillDownloadMore:(BOOL)willDownloadMore;
- (void)didStopDownloadingRestaurants:(StopReason)stopReason error:(NSError *)error;

@end

@class PESearchParameters;

@interface PERestaurantsDownloader : UIView

@property (nonatomic, readonly) NSArray *restaurants;

+ (instancetype)sharedInstance;

/**
 */
- (void)addDownloadResultsRecipient:(id <PERestaurantsDownloaderRecipient>)recipient;
- (void)removeDownloadResultsRecipient:(id <PERestaurantsDownloaderRecipient>)recipient;

/**
 Downloads restaurants with given search parameters.
 @returns YES if search parameters are valid, otherwise returns NO and initializes an `errorMessage` variable
 */
- (BOOL)downloadRestaurantsWithSearchParameters:(PESearchParameters *)searchParameters
                   searchParametersErrorMessage:(NSString * __autoreleasing *)errorMessage;

@end
