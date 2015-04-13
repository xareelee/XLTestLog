//
//  XLTestLogDevTests.m
//  XLTestLogDevTests
//
//  Created by Xaree on 4/14/15.
//  Copyright (c) 2015 Xaree Lee. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

@interface XLTestLogDevTests : XCTestCase

@end

@implementation XLTestLogDevTests

- (void)testPassedCase {
  XCTAssert(YES, @"Pass");
  NSLog(@"This is a message from `NSLog()`.");
}

- (void)testFailureCase {
  XCTAssert(NO, @"Fail");
}

- (void)testPerformanceExample {
  // This is an example of a performance test case.
  [self measureBlock:^{
    int j = 0;
    for (int i = 0; i < 1000000; i++) {
      j += i;
    }
  }];
}

@end
