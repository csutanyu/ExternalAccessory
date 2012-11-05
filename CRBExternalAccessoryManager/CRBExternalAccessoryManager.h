//
//  CRBExternalAccesaryManager.h
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

#import <Foundation/Foundation.h>

extern NSString *CRBExternalAccessoryManagerDidConnectNotification;
extern NSString *CRBExternalAccessoryManagerDidDisconnectNotification;
extern NSString *CRBExternalAccessoryManagerDataReceivedNotification;
extern NSString *CRBExternalAccessoryManagerReceiveData;

@interface CRBExternalAccessoryManager : NSObject

+ (CRBExternalAccessoryManager *)sharedManager;

- (BOOL)startMonitor:(NSString*)protocolString;
- (BOOL)stopMonitor;
- (BOOL)openSession;
- (BOOL)closeSession;
- (BOOL)writeData:(NSData *)data;

@end
