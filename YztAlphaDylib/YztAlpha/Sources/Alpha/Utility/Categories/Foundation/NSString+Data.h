//
//  NSString+Data.h
//  Alpha
//
//  Created by Dal Rupnik on 19/06/15.
//  Copyright © 2015 Unified Sense. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface NSString (Data)

+ (NSString *)alpha_hexStringFromData:(NSData *)data;

@end
