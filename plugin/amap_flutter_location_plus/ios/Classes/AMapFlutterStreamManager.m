//
//  AMapFlutterStreamManager.m
//  amap_location_flutter_plugin
//
//  Created by ldj on 2018/10/30.
//

#import "AMapFlutterStreamManager.h"

@implementation AMapFlutterStreamManager

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static AMapFlutterStreamManager *manager = nil;
    dispatch_once(&onceToken, ^{
        manager = [[AMapFlutterStreamManager alloc] init];
        AMapFlutterStreamHandler * streamHandler = [[AMapFlutterStreamHandler alloc] init];
        manager.streamHandler = streamHandler;
    });
    
    return manager;
}

@end


@implementation AMapFlutterStreamHandler

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
    self.eventSink = eventSink;
    return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    self.eventSink = nil;
    return nil;
}

@end
