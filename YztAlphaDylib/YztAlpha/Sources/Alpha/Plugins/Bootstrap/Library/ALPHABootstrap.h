//
//  ALPHABootstrap.h
//  Alpha
//
//  Created by Dal Rupnik on 10/11/14.
//  Copyright © 2014 Unified Sense. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface ALPHABootstrap : NSObject

/*!
 *  Returns YES if KZBootstrap environments are available.
 *
 *  @return YES if KZBEnvironments.plist is available
 */
+ (BOOL)hasEnvironments;

@end
