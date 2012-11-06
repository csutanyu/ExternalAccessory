//
//  CRBExternalAccesaryManager.m
//  CRBExternalAccesaryManager.m
//
//  Created by kkato on 2012/11/01.
//  Copyright (c) 2012 CrossBridge. All rights reserved.
//  Licensed under the Apache License, Version 2.0;
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "CRBExternalAccessoryManager.h"
#import "CRBExternalAccessorySessionController.h"

NSString *CRBExternalAccessoryManagerDidConnectNotification = @"CRBExternalAccessoryManagerDidConnectNotification";
NSString *CRBExternalAccessoryManagerDidDisconnectNotification = @"CRBExternalAccessoryManagerDidDisconnectNotification";
NSString *CRBExternalAccessoryManagerDataReceivedNotification = @"CRBExternalAccessoryManagerDataReceivedNotification";
NSString *CRBExternalAccessoryManagerReceiveData = @"CRBExternalAccessoryManagerReceiveData";

@interface EAAccessory (CustomEAAccessory)
- (BOOL)isSupportedProtcol:(NSString *)targetProtocolString;
@end

@implementation EAAccessory (CustomEAAccessory)
- (BOOL)isSupportedProtcol:(NSString *)targetProtocolString {
  NSArray *protocolStrings = [self protocolStrings];
  
  for (NSString *protocolString in protocolStrings) {
    if ([protocolString isEqualToString:targetProtocolString]) {
      return YES;
    }
  }
  
  return NO;
}
@end

@interface CRBExternalAccessoryManager()
@property (assign, nonatomic) CRBExternalAccessorySessionController *sessionController;
@property (strong, nonatomic) EAAccessory *accessory;
@property (copy, nonatomic) NSString *protocolString;
@end

@implementation CRBExternalAccessoryManager

#pragma mark Private Methods
- (id)init {
	self = [super init];
	if (self != nil) {
    self.sessionController = [CRBExternalAccessorySessionController sharedController];
	}
  
	return self;
}

- (void)accessoryDidConnect:(NSNotification *)notification {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  
  EAAccessory *connectedAccessory = [[notification userInfo] objectForKey:EAAccessoryKey];
  if ([self setAccessoryToSuportedProtocol:connectedAccessory
                            targetProtocol:self.protocolString]) {
    [self sendDidConnectNotification];
  }
}

- (void)accessoryDidDisconnect:(NSNotification *)notification {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  
  EAAccessory *disconnectedAccessory = [[notification userInfo] objectForKey:EAAccessoryKey];
  if ([disconnectedAccessory connectionID] == [_accessory connectionID]) {
    [self sendDidDisconnectNotification];
  }
}

- (void)receivedSessionData:(NSNotification *)notification {
  CRBExternalAccessorySessionController *sessionController = (CRBExternalAccessorySessionController *)[notification object];
  uint32_t bytesAvailable = 0;
  
  NSMutableData *receiveData = [[NSMutableData alloc] initWithCapacity:0];
  while ((bytesAvailable = [sessionController readBytesAvailable]) > 0) {
    [receiveData appendData:[sessionController readData:bytesAvailable]];
  }
  
  NSDictionary *dictionary = [NSDictionary dictionaryWithObject:receiveData
                                                         forKey:CRBExternalAccessoryManagerReceiveData];
  NSNotification *sendNotification;
  sendNotification = [NSNotification notificationWithName:CRBExternalAccessoryManagerDataReceivedNotification
                                                   object:self
                                                 userInfo:dictionary];
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center performSelectorOnMainThread:@selector(sendNotification:)
                           withObject:notification
                        waitUntilDone:NO];
}

- (void)sendDidConnectNotification {
  NSNotification *notification = [NSNotification notificationWithName:CRBExternalAccessoryManagerDidConnectNotification
                                                               object:self
                                                             userInfo:nil];
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center performSelectorOnMainThread:@selector(postNotification:)
                           withObject:notification
                        waitUntilDone:NO];
}

- (void)sendDidDisconnectNotification {
  NSNotification *notification = [NSNotification notificationWithName:CRBExternalAccessoryManagerDidDisconnectNotification
                                                               object:self
                                                             userInfo:nil];
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center performSelectorOnMainThread:@selector(postNotification:)
                           withObject:notification
                        waitUntilDone:NO];
}

- (BOOL)setAccessoryToSuportedProtocolFromAccesoryList:(NSArray *)accessoryList
                                        targetProtocol:(NSString *)targetProtocol {
  for (EAAccessory *accessory in accessoryList) {
    if ([self setAccessoryToSuportedProtocol:accessory
                              targetProtocol:targetProtocol]) {
      return YES;
    }
  }
  
  return NO;
}

- (BOOL)setAccessoryToSuportedProtocol:(EAAccessory *)accessory
                        targetProtocol:(NSString *)targetProtocol {
  if ([accessory isSupportedProtcol:targetProtocol]) {
    self.accessory = accessory;
    return YES;
  } else {
    return NO;
  }
}

#pragma mark Public Methods
+ (CRBExternalAccessoryManager *)sharedManager {
  static CRBExternalAccessoryManager *_manager = nil;
  static dispatch_once_t onceToken;
  
  dispatch_once(&onceToken, ^{
    _manager = [[CRBExternalAccessoryManager alloc] init];
  });
  
  return _manager;
}

// プロトコルを指定して、接続、切断のモニタリングを開始する
- (BOOL)startMonitor:(NSString*)protocolString {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  
  // 初期化
  self.protocolString = protocolString;
  self.accessory = nil;
  
  // 既に接続されている可能性があるのでチェック
  if ([self setAccessoryToSuportedProtocolFromAccesoryList:[[EAAccessoryManager sharedAccessoryManager] connectedAccessories]
                                            targetProtocol:protocolString]) {
    [self sendDidConnectNotification];
  }
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(accessoryDidConnect:)
                                               name:EAAccessoryDidConnectNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(accessoryDidDisconnect:)
                                               name:EAAccessoryDidDisconnectNotification
                                             object:nil];
  
  [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
  
  return YES;
}

// 接続、切断のモニタリングを停止する
- (BOOL)stopMonitor {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  
  self.protocolString = nil;
  self.accessory = nil;
  
  [[EAAccessoryManager sharedAccessoryManager] unregisterForLocalNotifications];
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:EAAccessoryDidConnectNotification
                                                object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:EAAccessoryDidDisconnectNotification
                                                object:nil];
  
  return YES;
}

- (BOOL)openSession {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  
  if (!_accessory || !_protocolString) {
    return NO;
  }
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(receivedSessionData:)
                                               name:CRBExternalAccessorySessionDataReceivedNotification
                                             object:nil];
  [_sessionController setupControllerForAccessory:_accessory
                               withProtocolString:_protocolString];
  [_sessionController openSession];
  
  return YES;
}

- (BOOL)closeSession {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:CRBExternalAccessorySessionDataReceivedNotification
                                                object:nil];
  [_sessionController closeSession];
  
  return NO;
}

- (BOOL)writeData:(NSData *)data {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  if (!_accessory || !_protocolString) {
    return NO;
  }
  
  [_sessionController writeData:data];
  
  return YES;
}

@end
