//
//  UIApplication+Delegate.h
//  Alpha
//
//  Created by Dal Rupnik on 01/06/15.
//  Copyright © 2015 Unified Sense. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface UIApplication (Delegate)

/*!
 *  Returns ALPHAApplicationDelegate injected object
 */
@property (nonatomic, strong) id alpha_injectedDelegate;

@end
