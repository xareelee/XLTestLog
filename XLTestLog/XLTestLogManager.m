// <XLTestLog>
// XLTestLogManager.m
//
// Copyright (c) 2015 Xaree Lee (Kang-Yu Lee)
// Released under the MIT license (see below)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


#import "XLTestLogManager.h"

#import <XCTest/XCTestLog.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wunused-macros"
#pragma clang diagnostic ignored "-Wformat-nonliteral"

// =============================================================================
// XcodeColor coloring macros
#define XCOLORS_ESCAPE @"\033["
#define XCOLORS_FG @"fg"
#define XCOLORS_BG @"bg"
#define XCOLORS_END @";"

#define XCOLORS_SET_FG(color_code) XCOLORS_ESCAPE XCOLORS_FG color_code XCOLORS_END
#define XCOLORS_SET_BG(color_code) XCOLORS_ESCAPE XCOLORS_BG color_code XCOLORS_END

#define XCOLORS_RESET_FG  XCOLORS_ESCAPE XCOLORS_FG XCOLORS_END // Clear any foreground color
#define XCOLORS_RESET_BG  XCOLORS_ESCAPE XCOLORS_BG XCOLORS_END // Clear any background color
#define XCOLORS_RESET     XCOLORS_ESCAPE XCOLORS_END // Clear any foreground or background color

// -----------------------------------------------------------------------------
// Coloring keywords
#define XLSTYLE_BG            XCOLORS_SET_BG(XCOLORS_NORMAL_BLACK)
#define XLSTYLE_SPECIAL_BG    XCOLORS_SET_BG(XCOLORS_BRIGHT_BLACK)

#define XLSTYLE_SUITE         XCOLORS_SET_FG(XCOLORS_BRIGHT_BLUE)
#define XLSTYLE_SUBJECT       XCOLORS_SET_FG(XCOLORS_NORMAL_BLUE)

#define XLSTYLE_CASE          XCOLORS_SET_FG(XCOLORS_BRIGHT_BLACK)
#define XLSTYLE_TIME          XCOLORS_SET_FG(XCOLORS_NORMAL_WHITE)

#define XLSTYLE_MEASURE       XCOLORS_SET_FG(XCOLORS_NORMAL_YELLOW)
#define XLSTYLE_WARNING       XCOLORS_SET_FG(XCOLORS_BRIGHT_YELLOW)

#define XLSTYLE_PASS          XCOLORS_SET_FG(XCOLORS_BRIGHT_GREEN)
#define XLSTYLE_FAIL          XCOLORS_SET_FG(XCOLORS_BRIGHT_RED)
#define XLSTYLE_PASS_STATS    XCOLORS_SET_FG(XCOLORS_BRIGHT_GREEN)
#define XLSTYLE_FAIL_STATS    XCOLORS_SET_FG(XCOLORS_BRIGHT_RED)

// -----------------------------------------------------------------------------
// Defined colors (R,G,B)
#define XCOLORS_NORMAL_BLACK   @"0,0,0"
#define XCOLORS_BRIGHT_BLACK   @"102,102,102"
#define XCOLORS_NORMAL_RED     @"155,15,31"
#define XCOLORS_BRIGHT_RED     @"228,129,129"
#define XCOLORS_NORMAL_GREEN   @"77,159,21"
#define XCOLORS_BRIGHT_GREEN   @"131,192,87"
#define XCOLORS_NORMAL_YELLOW  @"204,204,51"
#define XCOLORS_BRIGHT_YELLOW  @"255,255,0"
#define XCOLORS_NORMAL_BLUE    @"0,153,204"
#define XCOLORS_BRIGHT_BLUE    @"115,177,209"
#define XCOLORS_NORMAL_MAGENTA @"204,0,153"
#define XCOLORS_BRIGHT_MAGENTA @"255,102,204"
#define XCOLORS_NORMAL_CYAN    @"0,153,153"
#define XCOLORS_BRIGHT_CYAN    @"102,255,255"
#define XCOLORS_NORMAL_WHITE   @"191,191,191"
#define XCOLORS_BRIGHT_WHITE   @"229,229,299"


// =============================================================================
@interface XLTestLogManager()

@end

@implementation XLTestLogManager

+ (void)load
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
  Method testLogWithFormat = class_getInstanceMethod([XCTestLog class], @selector(testLogWithFormat:arguments:));
  method_setImplementation(testLogWithFormat, imp_implementationWithBlock(^(XCTestLog *testLog, NSString *format, va_list arguments) {
    NSString *message = [[XLTestLogManager sharedManager] testLogWithFormat:format arguments:arguments];
    [testLog.logFileHandle writeData:[message dataUsingEncoding:NSUTF8StringEncoding]];
  }));
#pragma clang diagnostic pop
}

+ (instancetype)sharedManager
{
  static XLTestLogManager *sharedManager;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedManager = [XLTestLogManager new];
  });
  return sharedManager;
}

// Analyze the format and the arguments to return a new format for `-[XCTestLog
// testLogWithFormat:arguments:]`.
- (NSString *)testLogWithFormat:(NSString *)format arguments:(va_list)arguments
{
  if ([format isEqualToString:@"Test Suite '%@' started at %@\n"])
  {
    // Test suite started
    return [self testSuiteStartedLogWithFormat:format arguments:arguments];
  }
  else if ([format isEqualToString:@"Test Suite '%@' %s at %@.\n\t Executed %lu test%s, with %lu failure%s (%lu unexpected) in %.3f (%.3f) seconds\n"])
  {
    // Test suite ended
    return [self testSuiteEndedLogWithFormat:format arguments:arguments];
  }
  else if ([format isEqualToString:@"Test Case '%@' started.\n"])
  {
    // Test case started
    return [self testCaseStartedLogWithFormat:format arguments:arguments];
  }
  else if ([format isEqualToString:@"Test Case '%@' %s (%.3f seconds).\n"])
  {
    // Test case ended
    return [self testCaseEndedLogWithFormat:format arguments:arguments];
  }
  else if ([format isEqualToString:@"%@:%lu: error: %@ : %@\n"])
  {
    // Find error
    return [self testErrorLogWithFormat:format arguments:arguments];
  }
  else if ([self isMeasurementLogWithFormat:format arguments:arguments])
  {
    // Measurement log
    return [self measurementLogWithFormat:format arguments:arguments];
  }
  
  // Undetermined messages
  return [self undeterminedTestLogWithFormat:format arguments:arguments];
}

#pragma mark - Serial Number Recorder

// Find the serial number for the identifier (test case method signature).
// This serial number will make logs more readable.
- (NSNumber *)testCaseNumberForIdentifier:(NSString *)identifier
{
  // Use the test case method signature (the identifier) as the keys to record
  // the serial numbers (the value).
  static NSMutableDictionary *dict;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    dict = [NSMutableDictionary dictionary];
  });

  NSNumber *testCaseNumber;
  
  @synchronized(dict)
  {
    testCaseNumber = dict[identifier];
    if (!testCaseNumber)
    {
      static NSUInteger counter = 0;
      testCaseNumber = @(++counter);
      dict[identifier] = testCaseNumber;
    }
  }
  
  return testCaseNumber;
}


#pragma mark - Log Message Implementation

- (NSString *)testSuiteStartedLogWithFormat:(NSString *)format arguments:(va_list)arguments
{
  static NSString *newFormat =
  (XLSTYLE_BG      @"👤 "
   XLSTYLE_SUITE   @"Test Suite "
   XLSTYLE_SUBJECT @"'%@'"   // test suite target
   XLSTYLE_SUITE   @" started at "
   XLSTYLE_TIME    @"%@\n"   // timestamp
   XCOLORS_RESET);
  
  return [[NSString alloc] initWithFormat:newFormat arguments:arguments];
}

- (NSString *)testSuiteEndedLogWithFormat:(NSString *)format arguments:(va_list)arguments
{
  // Get the string of the results
  va_list ap;
  va_copy(ap, arguments);
  __attribute__((unused)) id testSuiteTarget = va_arg(ap, id);
  const char *results                        = va_arg(ap, char*);
  va_end(ap);
  
  NSString *coloredFormat;
  if (strcasecmp(results, "passed") == 0)
  {
    coloredFormat =
    (XLSTYLE_BG         @"😀 "
     XLSTYLE_SUITE      @"Test Suite "
     XLSTYLE_SUBJECT    @"'%@'"   // test suite target
     XLSTYLE_PASS_STATS @" %s "   // `passed`
     XLSTYLE_SUITE      @"at "
     XLSTYLE_TIME       @"%@\n"   // timestamp
     XLSTYLE_SUITE      @"     Executed "
     XLSTYLE_SUBJECT    @"%lu test%s"  // total test counts
     XLSTYLE_SUITE      @", with "
     XLSTYLE_PASS_STATS @"%lu failure%s (%lu unexpected) "
     XLSTYLE_SUITE      @"in "
     XLSTYLE_TIME       @"%.3f (%.3f) seconds\n"
     XCOLORS_RESET);
  }
  else if (strcasecmp(results, "failed") == 0)
  {
    coloredFormat =
    (XLSTYLE_BG         @"😱 "
     XLSTYLE_SUITE      @"Test Suite "
     XLSTYLE_SUBJECT    @"'%@'"   // test suite target
     XLSTYLE_FAIL_STATS @" %s "   // `failed`
     XLSTYLE_SUITE      @"at "
     XLSTYLE_TIME       @"%@\n"   // timestamp
     XLSTYLE_SUITE      @"     Executed "
     XLSTYLE_SUBJECT    @"%lu test%s"  // total test counts
     XLSTYLE_SUITE      @", with "
     XLSTYLE_FAIL_STATS @"%lu failure%s (%lu unexpected) "
     XLSTYLE_SUITE      @"in "
     XLSTYLE_TIME       @"%.3f (%.3f) seconds\n"
     XCOLORS_RESET);
  }
  else
  {
    // unknown state format
    coloredFormat =
    (XLSTYLE_BG      @"❓ "
     XLSTYLE_SUITE   @"Test Suite "
     XLSTYLE_SUBJECT @"'%@'"   // test suite target
     XLSTYLE_WARNING @" %s "   // unknown value
     XLSTYLE_SUITE   @"at "
     XLSTYLE_TIME    @"%@\n"   // timestamp
     XLSTYLE_SUITE   @"     Executed "
     XLSTYLE_SUBJECT @"%lu test%s"  // total test counts
     XLSTYLE_SUITE   @", with "
     XLSTYLE_WARNING @"%lu failure%s (%lu unexpected) "
     XLSTYLE_SUITE   @"in "
     XLSTYLE_TIME    @"%.3f (%.3f) seconds\n"
     XCOLORS_RESET);
  }
  
  return [[NSString alloc] initWithFormat:coloredFormat
                                arguments:arguments];
}

- (NSString *)testCaseStartedLogWithFormat:(NSString *)format arguments:(va_list)arguments
{
  va_list ap;
  va_copy(ap, arguments);
  id testSuiteTarget = va_arg(ap, id);
  va_end(ap);
  
  NSNumber *testCaseNumber = [self testCaseNumberForIdentifier:testSuiteTarget];

  static NSString *coloredFormat =
  (XLSTYLE_BG    @"  🚀 "
   XLSTYLE_SUITE @"Test Case-%@ launched\n"
   XLSTYLE_CASE  @"      '%@'\n"
   XCOLORS_RESET);
  
  return [[NSString alloc] initWithFormat:coloredFormat, testCaseNumber, testSuiteTarget];
}

- (NSString *)testCaseEndedLogWithFormat:(NSString *)format arguments:(va_list)arguments
{
  va_list ap;
  va_copy(ap, arguments);
  id testCaseTarget           = va_arg(ap, id);
  const char *results         = va_arg(ap, char *);
  NSTimeInterval timeInterval = va_arg(ap, NSTimeInterval);
  va_end(ap);
  
  NSNumber *testCaseNumber = [self testCaseNumberForIdentifier:testCaseTarget];

  NSString *coloredFormat;
  if (strcasecmp(results, "passed") == 0)
  {
    coloredFormat =
    (XLSTYLE_BG    @"    ✅ "
     XLSTYLE_SUITE @"Test Case-%@"
     XLSTYLE_PASS  @" %s "
     XLSTYLE_TIME  @"(%.3f seconds)\n"
     XCOLORS_RESET);
  }
  else if (strcasecmp(results, "failed") == 0)
  {
    coloredFormat =
    (XLSTYLE_BG    @"    💥 "
     XLSTYLE_SUITE @"Test Case-%@"
     XLSTYLE_FAIL  @" %s "
     XLSTYLE_TIME  @"(%.3f seconds)\n"
     XCOLORS_RESET);
  }
  else
  {
    // unknown format
    coloredFormat =
    (XLSTYLE_BG      @"    ❓ "
     XLSTYLE_SUITE   @"Test Case-%@"
     XLSTYLE_WARNING @" %s "
     XLSTYLE_TIME    @"(%.3f seconds)\n"
     XCOLORS_RESET);
  }
  
  return [[NSString alloc] initWithFormat:coloredFormat, testCaseNumber, results, timeInterval];
}

- (NSString *)testErrorLogWithFormat:(NSString *)format arguments:(va_list)arguments
{
  va_list ap;
  va_copy(ap, arguments);
  NSString *file           = va_arg(ap, NSString *);
  unsigned long line       = va_arg(ap, unsigned long);
  NSString *testCaseTarget = va_arg(ap, NSString *);
  NSString *reason         = va_arg(ap, NSString *);
  va_end(ap);
  
  NSNumber *testCaseNumber = [self testCaseNumberForIdentifier:testCaseTarget];
  
  static NSString *coloredFormat =
  (XLSTYLE_SPECIAL_BG @"    🐞 "
   XLSTYLE_WARNING    @"Test Case-%@ Failure Report\n"
   XLSTYLE_WARNING    @"     ⚠️ %@\n"
   XLSTYLE_WARNING    @"     ⚠️ %@:%lu\n"
   XCOLORS_RESET);
  
  return [[NSString alloc] initWithFormat:coloredFormat, testCaseNumber, reason, file, line];
}

- (NSString *)measurementLogWithFormat:(NSString *)format arguments:(va_list)arguments
{
  // Parse the measurement info values from arguments
  NSArray *constantKeywordsInMeasurementLog =
  @[@": Test Case '",
    @"' measured [Time, seconds] average: ",
    @", relative standard deviation: ",
    @", values: [",
    @", ",
    @", ",
    @", ",
    @", ",
    @", ",
    @", ",
    @", ",
    @", ",
    @", ",
    @"], performanceMetricID:",
    @", baselineName: ",
    @", baselineAverage: ",
    @", maxPercentRegression: ",
    @", maxPercentRelativeStandardDeviation: ",
    @", maxRegression: ",
    @", maxStandardDeviation: ",
    ];
  
  va_list ap;
  va_copy(ap, arguments);
  __block NSString *results = va_arg(ap, NSString *);
  va_end(ap);
  
  // Extract the measurement data from `arguments` into `infoInArguments`.
  __block NSMutableArray *infoInArguments = [NSMutableArray arrayWithCapacity:[constantKeywordsInMeasurementLog count]];
  
  [constantKeywordsInMeasurementLog enumerateObjectsUsingBlock:^(NSString *keyword, NSUInteger idx, BOOL *stop) {
    
    NSRange range = [results rangeOfString:keyword];
    
    [infoInArguments addObject:[results substringToIndex:range.location]];
    results = [results substringFromIndex:range.location + range.length];
  }];
  
  NSString *testLocation                        = infoInArguments[0];
  NSString *testCase                            = infoInArguments[1];
//NSString *averageTime                         = infoInArguments[2];
  NSString *relativeStandardDeviation           = infoInArguments[3];
  NSString *sample1                             = infoInArguments[4];
  NSString *sample2                             = infoInArguments[5];
  NSString *sample3                             = infoInArguments[6];
  NSString *sample4                             = infoInArguments[7];
  NSString *sample5                             = infoInArguments[8];
  NSString *sample6                             = infoInArguments[9];
  NSString *sample7                             = infoInArguments[10];
  NSString *sample8                             = infoInArguments[11];
  NSString *sample9                             = infoInArguments[12];
  NSString *sample10                            = infoInArguments[13];
//NSString *metricID                            = infoInArguments[14];
//NSString *baselineName                        = infoInArguments[15];
//NSString *baselineAverage                     = infoInArguments[16];
//NSString *maxPercentRegression                = infoInArguments[17];
//NSString *maxPercentRelativeStandardDeviation = infoInArguments[18];
//NSString *maxRegression                       = infoInArguments[19];
//NSString *maxStandardDeviation                = results;
  
  
  // Construct the new measurement log
  NSNumber *testCaseNumber = [self testCaseNumberForIdentifier:testCase];
  double preciseAverageTime = ([sample1 doubleValue] + [sample2 doubleValue] +
                               [sample3 doubleValue] + [sample4 doubleValue] +
                               [sample5 doubleValue] + [sample6 doubleValue] +
                               [sample7 doubleValue] + [sample8 doubleValue] +
                               [sample9 doubleValue] + [sample10 doubleValue]) * 0.1;
  double standardDeviation = preciseAverageTime * [relativeStandardDeviation doubleValue] * 0.01;
  
  NSString *newFormat =
  (XLSTYLE_BG       @"    🕑 "
   XLSTYLE_MEASURE  @"Test Case-%@ Performance Measurement\n"
   XLSTYLE_MEASURE  @"       Results: %.6f ±%.6f (±%@)\n"
   XLSTYLE_CASE     @"       Samples: %@, %@, %@, %@, %@,\n"
   XLSTYLE_CASE     @"                %@, %@, %@, %@, %@\n"
   XLSTYLE_CASE     @"       %@\n"
   XCOLORS_RESET);
  
  return [NSString stringWithFormat:newFormat, testCaseNumber, preciseAverageTime, standardDeviation, relativeStandardDeviation, sample1, sample2, sample3, sample4, sample5, sample6, sample7, sample8, sample9, sample10, testLocation];
}

- (NSString *)undeterminedTestLogWithFormat:(NSString *)format arguments:(va_list)arguments
{
  NSString *formatForUndeterminedTestLog = [NSString stringWithFormat:@"❓ %@", format];
  return [[NSString alloc] initWithFormat:formatForUndeterminedTestLog arguments:arguments];
}


#pragma mark - Measure Block

- (BOOL)isMeasurementLogWithFormat:(NSString *)format arguments:(va_list)arguments
{
  // The format for measurement results is `@"%@"`.
  if (![format isEqualToString:@"%@"]) {
    return NO;
  }
  
  // So we check whether the arguments contain keywords for the measure results.
  va_list ap;
  va_copy(ap, arguments);
  NSString *results = va_arg(ap, NSString *);
  va_end(ap);

  if (![results isKindOfClass:[NSString class]]) {
    return NO;
  }
  
  NSArray *keywordsInMeasurementLog =
  @[@": Test Case '",
    @"' measured [Time, seconds] average: ",
    @", relative standard deviation: ",
    @", values: ["];
  
  __block BOOL isMeasurementLog = YES;
  [keywordsInMeasurementLog enumerateObjectsUsingBlock:^(NSString *keyword, NSUInteger idx, BOOL *stop) {
    
    isMeasurementLog = [results containsString:keyword];
    
    if (!isMeasurementLog) {
      *stop = YES;
    }
  }];
  
  return isMeasurementLog;
}


@end
