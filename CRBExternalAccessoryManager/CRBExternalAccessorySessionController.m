//
//  CRBExternalAccessorySessionController.m
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


#import "CRBExternalAccessorySessionController.h"

NSString *CRBExternalAccessorySessionDataReceivedNotification = @"CRBExternalAccessorySessionDataReceivedNotification";

@interface CRBExternalAccessorySessionController()
- (void)_writeData;
- (void)_readData;
@end

@implementation CRBExternalAccessorySessionController

#define OUTPUT_DATA_TO_LOG  // ストリームへのread,writeするデータをログに出力する場合は有効にする
#define EAD_INPUT_BUFFER_SIZE 128 // read用のバッファサイズ

#pragma mark Private Methods
- (void)_writeData {
  @synchronized(self) {
    while (([_outputStream hasSpaceAvailable]) && ([_writeDataBuffer length] > 0)) {
      NSInteger bytesWritten = [_outputStream write:[_writeDataBuffer bytes]
                                          maxLength:[_writeDataBuffer length]];
      
#ifdef OUTPUT_DATA_TO_LOG
      NSLog(@"Write Data (%d byte) -> %@", bytesWritten, [_writeDataBuffer description]);
#endif
      
      if (bytesWritten > 0) {
        [_writeDataBuffer replaceBytesInRange:NSMakeRange(0,bytesWritten)
                                    withBytes:NULL
                                       length:0];
      } else if (bytesWritten == -1) {
        NSLog(@"write error");
        break;
      }
    }
  }
}

- (void)_readData {
  @synchronized(self) {
    uint8_t buf[EAD_INPUT_BUFFER_SIZE];
    while ([_inputStream hasBytesAvailable]) {
      NSInteger bytesRead = [_inputStream read:buf
                                     maxLength:EAD_INPUT_BUFFER_SIZE];
      
      if (_readDataBuffer == nil) {
        _readDataBuffer = [[NSMutableData alloc] init];
      }
      
      [_readDataBuffer appendBytes:(void *)buf length:bytesRead];
      
#ifdef OUTPUT_DATA_TO_LOG
      // _readDataでも良いが_readDataはバッファなので連続で送ってこられたら
      // 過去に受け取って破棄がまだなデータもログに出してしまう可能性がある。
      // なので「NSData *readData = [NSData dataWithBytes:buf length:bytesRead]」で
      // この1回分のみのNSDataを作ってログに出力する
      NSData *readData = [NSData dataWithBytes:buf length:bytesRead];
      NSLog(@"Read Data (%d byte) -> %@", bytesRead, [readData description]);
#endif
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:CRBExternalAccessorySessionDataReceivedNotification
                                                        object:self
                                                      userInfo:nil];
  }
}

- (void)dealloc {
  [self closeSession];
  [self setupControllerForAccessory:nil withProtocolString:nil];
}

#pragma mark Public Methods
+ (CRBExternalAccessorySessionController *)sharedController {
  static CRBExternalAccessorySessionController *_sessionController = nil;
  static dispatch_once_t onceToken;
  
  dispatch_once(&onceToken, ^{
    _sessionController = [[CRBExternalAccessorySessionController alloc] init];
  });
  
  return _sessionController;
}

- (void)setupControllerForAccessory:(EAAccessory *)accessory
                 withProtocolString:(NSString *)protocolString {
  NSLog(@"%s Protocol String -> %@", __PRETTY_FUNCTION__, protocolString);
  _accessory = accessory;
  _protocolString = [protocolString copy];
}

- (BOOL)openSession {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  
  [_accessory setDelegate:self];
  _session = [[EASession alloc] initWithAccessory:_accessory
                                      forProtocol:_protocolString];
  
  if (!_session) {
    NSLog(@"Error! Creating session failed");
    NSLog(@"Protocol String -> %@", _protocolString);
    return NO;
  }
  
  self.inputStream = [_session inputStream];
  [_inputStream setDelegate:self];
  [_inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                          forMode:NSDefaultRunLoopMode];
  [_inputStream open];
  
  self.outputStream = [_session outputStream];
  [_outputStream setDelegate:self];
  [_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                           forMode:NSDefaultRunLoopMode];
  [_outputStream open];
  
  return YES;
}

- (void)closeSession {
  NSLog(@"%s", __PRETTY_FUNCTION__);
  
  [_inputStream close];
  [_inputStream removeFromRunLoop:[NSRunLoop currentRunLoop]
                          forMode:NSDefaultRunLoopMode];
  [_inputStream setDelegate:nil];
  self.inputStream = nil;
  
  [_outputStream close];
  [_outputStream removeFromRunLoop:[NSRunLoop currentRunLoop]
                           forMode:NSDefaultRunLoopMode];
  [_outputStream setDelegate:nil];
  self.outputStream = nil;
  
  _session = nil;
  
  _writeDataBuffer = nil;
  _readDataBuffer = nil;
}

// ストリームに書き込むデータは一度バッファに積まれる。
// ストリームの状況によってはすぐに書き込まれるとは限らない
- (void)writeData:(NSData *)data {
  @synchronized(self) {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if (_writeDataBuffer == nil) {
      _writeDataBuffer = [[NSMutableData alloc] init];
    }
    
    [_writeDataBuffer appendData:data];
    [self _writeData];
  }
}

- (NSData *)readData:(NSUInteger)bytesToRead {
  @synchronized(self) {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    NSData *data = nil;
    if ([_readDataBuffer length] >= bytesToRead) {
      NSRange range = NSMakeRange(0, bytesToRead);
      data = [_readDataBuffer subdataWithRange:range];
      [_readDataBuffer replaceBytesInRange:range withBytes:NULL length:0];
    }
    return data;
  }
}

- (NSUInteger)readBytesAvailable {
  @synchronized(self) {
    return [_readDataBuffer length];
  }
}

#pragma mark EAAccessoryDelegate Method
- (void)accessoryDidDisconnect:(EAAccessory *)accessory {
}

#pragma mark NSStreamDelegate Method
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
  switch (eventCode) {
    case NSStreamEventNone:
      break;
    case NSStreamEventOpenCompleted:
      break;
    case NSStreamEventHasBytesAvailable:
      [self _readData];
      break;
    case NSStreamEventHasSpaceAvailable:
      [self _writeData];
      break;
    case NSStreamEventErrorOccurred:
      break;
    case NSStreamEventEndEncountered:
      break;
    default:
      break;
  }
}

@end
