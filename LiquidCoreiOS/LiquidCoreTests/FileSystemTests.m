//
//  FileSystemTests.m
//  LiquidCoreiOSTests
//
/*
 Copyright (c) 2018 Eric Lange. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 - Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <XCTest/XCTest.h>
#import "Process.h"
#import <JavaScriptCore/JavaScriptCore.h>

@interface FileSystemTests : XCTestCase
@end

@interface Script : XCTestCase <ProcessDelegate>
@property (atomic, assign) bool done;
@end

typedef void (^OnDone)(JSContext *);

@implementation Script {
    NSString *script_;
    OnDone onDone_;
    JSContext* context_;
}
- (id) initWithScript:(NSString*)script onDone:(OnDone)onDone
{
    self = [super init];
    if (self) {
        script_ = script;
        onDone_ = onDone;
        _done = false;
        XCTAssertNotNil([[Process alloc] initWithDelegate:self id:@"_" mediaAccessMask:PermissionsRW]);
    }
    return self;
}
- (void) onProcessStart:(Process*)process context:(JSContext*)context
{
    context_ = context;
    [context evaluateScript:script_];
}
- (void) onProcessAboutToExit:(Process*)process exitCode:(int)code
{
    onDone_(context_);
}
- (void) onProcessExit:(Process*)process exitCode:(int)code
{
    self.done = true;
}
- (void) onProcessFailed:(Process*)process exception:(NSException*)exception
{
    XCTAssertTrue(false);
}
@end

@interface CwdTest : XCTestCase <ProcessDelegate>
@property (atomic, assign) bool done;
@property (atomic, assign) bool ready;
@property (atomic) Process *process;
@property (atomic) id<LoopPreserver> preserver;
@end

@implementation CwdTest
- (id) init
{
    self = [super init];
    if (self) {
        _done = false;
        _ready = false;
        _process = [[Process alloc] initWithDelegate:self id:@"_" mediaAccessMask:PermissionsRW];
        _preserver = nil;
    }
    return self;
}
- (void) onProcessStart:(Process*)process context:(JSContext*)context
{
    self.preserver = [process keepAlive];
    self.ready = true;
}
- (void) onProcessAboutToExit:(Process*)process exitCode:(int)code
{
}
- (void) onProcessExit:(Process*)process exitCode:(int)code
{
    self.done = true;
}
- (void) onProcessFailed:(Process*)process exception:(NSException*)exception
{
    XCTAssertTrue(false);
}
@end

@implementation FileSystemTests
- (void)testFileSystem
{
    NSString *script =
    @"var fs = require('fs');"
    @"process.chdir('./local');"
    @"fs.writeFile('test.txt', 'Hello, World!', function(err) {"
    @"   if(err) {"
    @"       return console.log(err);"
    @"   }"
    @"   console.log('The file was saved!');"
    @"   fs.readdir('.', function(err,files) {"
    @"       global.files = files;"
    @"   });"
    @"});"
    @"";
    
    Script *s = [[Script alloc] initWithScript:script onDone:^(JSContext* context) {
        NSArray *files = [context[@"files"] toArray];
        NSLog(@"files = %@", files);
        XCTAssertTrue([files containsObject:@"test.txt"]);
    }];
    volatile bool done = false; while (!done) { done = s.done; }

    NSString* homedir = NSHomeDirectory();
    NSString* path = [NSString stringWithFormat:@"%@/Library/__org.liquidplayer.node__/__/local/test.txt", homedir];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:path]);

    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    XCTAssertEqualObjects(content, @"Hello, World!");
    
    [Process uninstall:@"_" scope:LOCAL];
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:path]);
}

- (void)testLetsBeNaughty
{
    NSString *script =
    @"(function() {"
    @"    var fs = require('fs');"
    @""
    @"    console.log('Test stdout capture!');"
    @""
    @"    /* Test 1: Try to read the /data directory */"
    @"    global.a = null;"
    @"    try {"
    @"        global.a = fs.readdirSync('/data');"
    @"    } catch(e) {"
    @"        global.a = e;"
    @"    }"
    @""
    @"    /* Test 2: Try to use relative pathing to get there */"
    @"    global.b = null;"
    @"    try {"
    @"        global.b = fs.readdirSync('../data');"
    @"    } catch(e) {"
    @"        global.b = e;"
    @"    }"
    @""
    @"    /* Test 3: Try to chmod there */"
    @"    global.c = null;"
    @"    try {"
    @"        process.chdir('/data');"
    @"        global.c = fs.readdirSync('.');"
    @"    } catch(e) {"
    @"        global.c = e;"
    @"    }"
    @""
    @"    /* Test 4: Try to chmod there with relative pathing */"
    @"    global.d = null;"
    @"    try {"
    @"        process.chdir('../data');"
    @"        global.d = fs.readdirSync('.');"
    @"    } catch(e) {"
    @"        global.d = e;"
    @"    }"
    @""
    @"    /* Test 5: Try to create a symlink to do the nasty */"
    @"    global.e = null;"
    @"    try {"
    @"        fs.symlinkSync('/data', './naughty');"
    @"        global.e = fs.readdirSync('./naughty/');"
    @"    } catch (e) {"
    @"        global.e = e;"
    @"    }"
    @"})()";
    
    Script *s = [[Script alloc] initWithScript:script onDone:^(JSContext* context) {
        NSLog(@"testLetsBeNaughty: %@", [context[@"a"] toString]);
        XCTAssertTrue([[context[@"a"] toString] containsString:@"EACCES"]);

        NSLog(@"testLetsBeNaughty: %@", [context[@"b"] toString]);
        XCTAssertTrue([[context[@"b"] toString] containsString:@"EACCES"] ||
                      [[context[@"b"] toString] containsString:@"ENOENT"]);

        NSLog(@"testLetsBeNaughty: %@", [context[@"c"] toString]);
        XCTAssertTrue([[context[@"c"] toString] containsString:@"EACCES"]);

        NSLog(@"testLetsBeNaughty: %@", [context[@"d"] toString]);
        XCTAssertTrue([[context[@"d"] toString] containsString:@"EACCES"]);

        NSLog(@"testLetsBeNaughty: %@", [context[@"e"] toString]);
        XCTAssertTrue([[context[@"e"] toString] containsString:@"EACCES"]);
    }];
    volatile bool done = false; while (!done) { done = s.done; }

    [Process uninstall:@"_" scope:LOCAL];
}

- (void)testChdirCwdMultipleProcesses
{
    NSString* dir1 = @"/home/local";
    NSString* dir2 = @"/home/cache";
    
    NSString* proc1 = @"process.chdir('/home/local');";
    NSString* proc2 = @"process.chdir('/home/cache');";

    CwdTest *cwd1 = [[CwdTest alloc] init];
    CwdTest *cwd2 = [[CwdTest alloc] init];
    volatile bool ready = false; while (!ready) { ready = cwd1.ready && cwd2.ready; }

    [cwd1.process sync:^(JSContext *context) {
        [context evaluateScript:proc1];
        NSString* v = [[context evaluateScript:@"process.cwd()"] toString];
        XCTAssertEqualObjects(v, dir1);
    }];

    [cwd2.process sync:^(JSContext *context) {
        [context evaluateScript:proc2];
        NSString* v = [[context evaluateScript:@"process.cwd()"] toString];
        XCTAssertEqualObjects(v, dir2);
    }];

    [cwd1.process sync:^(JSContext *context) {
        NSString* v = [[context evaluateScript:@"process.cwd()"] toString];
        XCTAssertEqualObjects(v, dir1);
    }];
    
    [cwd1.preserver letDie];
    [cwd2.preserver letDie];
    volatile bool done = false; while (!done) { done = cwd1.done && cwd2.done; }
    
    [Process uninstall:@"_" scope:LOCAL];
}

@end
