//
// Copyright 2013 Facebook
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "OCUnitIOSLogicTestRunner.h"

#import "TaskUtil.h"
#import "XCToolUtil.h"

@implementation OCUnitIOSLogicTestRunner

- (NSDictionary *)otestEnvironmentWithOverrides:(NSDictionary *)overrides
{
  NSString *version = [_buildSettings[@"SDK_NAME"] stringByReplacingOccurrencesOfString:@"iphonesimulator" withString:@""];
  NSString *simulatorHome = [NSString stringWithFormat:@"%@/Library/Application Support/iPhone Simulator/%@", NSHomeDirectory(), version];

  NSMutableDictionary *allOverrides =
  [[@{
    @"CFFIXED_USER_HOME" : simulatorHome,
    @"HOME" : simulatorHome,
    @"IPHONE_SHARED_RESOURCES_DIRECTORY" : simulatorHome,
    @"DYLD_FALLBACK_FRAMEWORK_PATH" : @"/Developer/Library/Frameworks",
    @"DYLD_FRAMEWORK_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
    @"DYLD_LIBRARY_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
    @"DYLD_ROOT_PATH" : _buildSettings[@"SDKROOT"],
    @"IPHONE_SIMULATOR_ROOT" : _buildSettings[@"SDKROOT"],
    @"IPHONE_SIMULATOR_VERSIONS" : @"iPhone Simulator (external launch) , iPhone OS 6.0 (unknown/10A403)",
    @"NSUnbufferedIO" : @"YES",
    } mutableCopy] autorelease];
  [allOverrides addEntriesFromDictionary:overrides];
  return [super otestEnvironmentWithOverrides:allOverrides];
}

- (NSTask *)otestTaskWithTestBundle:(NSString *)testBundlePath
{
  NSTask *task = [[[NSTask alloc] init] autorelease];
  [task setLaunchPath:[NSString stringWithFormat:@"%@/Developer/usr/bin/otest", _buildSettings[@"SDKROOT"]]];
  [task setArguments:[[self otestArguments] arrayByAddingObject:testBundlePath]];
  [task setEnvironment:[self otestEnvironmentWithOverrides:@{
                        @"DYLD_INSERT_LIBRARIES" : [PathToXCToolBinaries() stringByAppendingPathComponent:@"otest-shim-ios.dylib"],
                        }]];
  return task;
}

- (BOOL)runTestsAndFeedOutputTo:(void (^)(NSString *))outputLineBlock error:(NSString **)error
{
  NSString *sdkName = _buildSettings[@"SDK_NAME"];
  NSAssert([sdkName hasPrefix:@"iphonesimulator"], @"Unexpected SDK name: %@", sdkName);

  NSString *testBundlePath = [self testBundlePath];
  BOOL bundleExists = [[NSFileManager defaultManager] fileExistsAtPath:testBundlePath];

  if (IsRunningUnderTest()) {
    // If we're running under test, pretend the bundle exists even if it doesn't.
    bundleExists = YES;
  }

  if (bundleExists) {
    NSTask *task = [self otestTaskWithTestBundle:testBundlePath];

    LaunchTaskAndFeedOuputLinesToBlock(task, outputLineBlock);

    return [task terminationStatus] == 0 ? YES : NO;
  } else {
    *error = [NSString stringWithFormat:@"Test bundle not found at: %@", testBundlePath];
    return NO;
  }
}

- (NSArray *)runTestClassListQuery
{
  NSTask *task = [[[NSTask alloc] init] autorelease];
  [task setLaunchPath:[PathToXCToolBinaries() stringByAppendingPathComponent:@"otest-query-ios"]];
  [task setArguments:@[self.testBundlePath]];
  [task setEnvironment:[self otestEnvironmentWithOverrides:@{}]];
  NSDictionary *output = LaunchTaskAndCaptureOutput(task);
  NSData *outputData = [output[@"stdout"] dataUsingEncoding:NSUTF8StringEncoding];
  return [NSJSONSerialization JSONObjectWithData:outputData options:0 error:nil];
}

@end
