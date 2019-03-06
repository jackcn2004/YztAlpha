//
//  UIApplication+Private.h
//  Alpha
//
//  Created by Dal Rupnik on 01/06/15.
//  Copyright © 2015 Unified Sense. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface UIApplication (Private)

@property (nonatomic, readonly) UIView* alpha_statusBar;
@property (nonatomic, readonly) UIWindow* alpha_statusWindow;

@end
