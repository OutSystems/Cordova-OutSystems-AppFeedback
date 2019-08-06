//
//  ECTProviderAPI.h
//  OutSystemsMobileECTStaticLib
//
//  Created by engineering on 06/02/2017.
//  Copyright © 2017 OutSystems. All rights reserved.
//

#ifndef OutsystemsMobileFrameworks_ECTProviderAPI_h
#define OutsystemsMobileFrameworks_ECTProviderAPI_h

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "OSECTAppInfo.h"

typedef void (^OSECTProviderAPIBlock)(BOOL result);

@interface OSECTProviderAPI : NSObject

-(id)initWithWebView:(UIView*)web forHostname:(NSString*)host;

-(OSECTAppInfo*)getECTAppInfo;

-(void)getApplicationInfo:(OSECTProviderAPIBlock)completionBlock;
-(void)getCurrentAPIVersion:(OSECTProviderAPIBlock)completionBlock;
-(void)isAppFeedbackAvailable:(OSECTProviderAPIBlock)completionBlock;
-(void)submitFeedback:(OSECTProviderAPIBlock)completionBlock;

@end

#endif
