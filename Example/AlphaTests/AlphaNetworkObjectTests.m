//
//  AlphaNetworkObjectTests.m
//  Alpha
//
//  Created by Dal Rupnik on 17/06/15.
//  Copyright (c) 2015 Unified Sense. All rights reserved.
//


#import "ALPHASerialization.h"
#import "ALPHARequest.h"
#import "ALPHATestCase.h"
#import "ALPHANetworkObject.h"

#import <XCTest/XCTest.h>

@interface AlphaNetworkObjectTests : ALPHATestCase

@property (nonatomic, strong) id<ALPHASerializer> serializer;

@end

@implementation AlphaNetworkObjectTests

- (id<ALPHASerializer>)serializer
{
    if (!_serializer)
    {
        _serializer = [ALPHASerializerManager sharedManager];
    }
    
    return _serializer;
}

- (void)setUp
{
    [super setUp];
    
    
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testNetworkSerialization
{
    ALPHARequest* request = [ALPHARequest requestWithIdentifier:@"com.unifiedsense.test" parameters:@{ @"test" : @"parameter" }];
    
    ALPHANetworkObject *object = [[ALPHANetworkObject alloc] initWithObject:request];
    
    id serialized = [NSKeyedArchiver archivedDataWithRootObject:object];
    
    ALPHANetworkObject *deserialized = [NSKeyedUnarchiver unarchiveObjectWithData:serialized];
    
    ALPHARequest* deserializedRequest = (ALPHARequest *)[deserialized object];
    
    XCTAssert([request.identifier isEqualToString:deserializedRequest.identifier], @"Equal identifiers");
    ALPHAAssertEqualDictionaries(request.parameters, deserializedRequest.parameters);
}


@end