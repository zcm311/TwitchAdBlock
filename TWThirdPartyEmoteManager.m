#import "TWThirdPartyEmoteManager.h"

@interface TWThirdPartyEmoteManager ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSURL *> *emoteURLs;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *animatedFlags;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIImage *> *emoteImages;
@end

@implementation TWThirdPartyEmoteManager
+ (instancetype)sharedManager {
  static dispatch_once_t onceToken;
  static TWThirdPartyEmoteManager *manager;
  dispatch_once(&onceToken, ^{
    manager = [TWThirdPartyEmoteManager new];
  });
  return manager;
}
- (instancetype)init {
  if ((self = [super init])) {
    _emoteURLs = [NSMutableDictionary dictionary];
    _animatedFlags = [NSMutableDictionary dictionary];
    _emoteImages = [NSMutableDictionary dictionary];
  }
  return self;
}
- (void)loadGlobalEmotes {
  [self fetch7TVSet:@"https://7tv.io/v3/emote-sets/global"];
  [self fetchBTTVGlobal];
}
- (void)loadChannelEmotesWithID:(NSString *)channelID {
  if (!channelID) return;
  NSString *sevenURL = [NSString stringWithFormat:@"https://7tv.io/v3/users/twitch/%@", channelID];
  [self fetch7TVUser:sevenURL];
  NSString *bttvURL = [NSString stringWithFormat:@"https://api.betterttv.net/3/cached/users/twitch/%@", channelID];
  [self fetchBTTVChannel:bttvURL];
}
- (UIImage *)imageForEmoteCode:(NSString *)code {
  UIImage *image = self.emoteImages[code];
  if (!image) {
    NSURL *url = self.emoteURLs[code];
    if (!url) return nil;
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data) return nil;
    image = [UIImage imageWithData:data];
    if (image) {
      @synchronized(self) {
        self.emoteImages[code] = image;
      }
    }
  }
  return image;
}
#pragma mark - Private
- (void)fetch7TVSet:(NSString *)urlString {
  NSURL *url = [NSURL URLWithString:urlString];
  [[[NSURLSession sharedSession] dataTaskWithURL:url
                               completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    if (!data || error) return;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSArray *emotes = json["emotes"];
    for (NSDictionary *emote in emotes) {
      NSString *code = emote[@"name"] ?: emote[@"data"][@"name"];
      NSDictionary *dataDict = emote[@"data"] ?: @{};
      BOOL animated = [dataDict[@"animated"] boolValue];
      NSString *host = dataDict[@"host"][@"url"];
      if (!code || !host) continue;
      NSString *path = animated ? @"3x.gif" : @"3x.webp";
      NSString *full = [NSString stringWithFormat:@"https:%@/%@", host, path];
      NSURL *emoteURL = [NSURL URLWithString:full];
      @synchronized(self) {
        self.emoteURLs[code] = emoteURL;
        self.animatedFlags[code] = @(animated);
      }
      [self cacheImageForCode:code url:emoteURL];
    }
  }] resume];
}

- (BOOL)isEmoteReady:(NSString *)code {
  return self.emoteImages[code] != nil;
}
- (void)fetch7TVUser:(NSString *)urlString {
  NSURL *url = [NSURL URLWithString:urlString];
  [[[NSURLSession sharedSession] dataTaskWithURL:url
                               completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    if (!data || error) return;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSString *setID = json[@"emote_set"][@"id"];
    if (setID) {
      NSString *setURL = [NSString stringWithFormat:@"https://7tv.io/v3/emote-sets/%@", setID];
      [self fetch7TVSet:setURL];
    }
  }] resume];
}
- (void)fetchBTTVGlobal {
  NSURL *url = [NSURL URLWithString:@"https://api.betterttv.net/3/cached/emotes/global"];
  [[[NSURLSession sharedSession] dataTaskWithURL:url
                               completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    if (!data || error) return;
    NSArray *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    for (NSDictionary *emote in json) {
      NSString *code = emote[@"code"];
      NSString *idStr = emote[@"id"];
      NSString *imageType = emote[@"imageType"];
      if (!code || !idStr || !imageType) continue;
      BOOL animated = [imageType.lowercaseString isEqualToString:@"gif"];
      NSString *full = [NSString stringWithFormat:@"https://cdn.betterttv.net/emote/%@/3x.%@", idStr, imageType];
      NSURL *emoteURL = [NSURL URLWithString:full];
      @synchronized(self) {
        self.emoteURLs[code] = emoteURL;
        self.animatedFlags[code] = @(animated);
      }
      [self cacheImageForCode:code url:emoteURL];
    }
  }] resume];
}
- (void)fetchBTTVChannel:(NSString *)urlString {
  NSURL *url = [NSURL URLWithString:urlString];
  [[[NSURLSession sharedSession] dataTaskWithURL:url
                               completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    if (!data || error) return;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSArray *emotes = json[@"shared"] ?: @[];
    emotes = [emotes arrayByAddingObjectsFromArray:(json[@"channel"] ?: @[])];
    for (NSDictionary *emote in emotes) {
      NSString *code = emote[@"code"];
      NSString *idStr = emote[@"id"];
      NSString *imageType = emote[@"imageType"];
      if (!code || !idStr || !imageType) continue;
      BOOL animated = [imageType.lowercaseString isEqualToString:@"gif"];
      NSString *full = [NSString stringWithFormat:@"https://cdn.betterttv.net/emote/%@/3x.%@", idStr, imageType];
      NSURL *emoteURL = [NSURL URLWithString:full];
      @synchronized(self) {
        self.emoteURLs[code] = emoteURL;
        self.animatedFlags[code] = @(animated);
      }
      [self cacheImageForCode:code url:emoteURL];
    }
  }] resume];
}

- (void)cacheImageForCode:(NSString *)code url:(NSURL *)url {
  [[[NSURLSession sharedSession] dataTaskWithURL:url
                               completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    if (!data || error) return;
    UIImage *img = [UIImage imageWithData:data];
    if (!img) return;
    @synchronized(self) {
      self.emoteImages[code] = img;
    }
  }] resume];
}
@end
