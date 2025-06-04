#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TWThirdPartyEmoteManager : NSObject
+ (instancetype)sharedManager;
- (void)loadGlobalEmotes;
- (void)loadChannelEmotesWithID:(NSString *)channelID;
- (UIImage *)imageForEmoteCode:(NSString *)code;

// Returns YES if the image has finished loading into memory
- (BOOL)isEmoteReady:(NSString *)code;
@end
