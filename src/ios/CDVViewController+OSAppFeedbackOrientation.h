#import <Cordova/CDVViewController.h>

@interface CDVViewController (OSAppFeedbackOrientation)

- (NSArray *)supportedOrientations;
- (void)setSupportedOrientations:(NSArray *)supportedOrientations;

@end
