//
//  ALPHAToolbarItem.h
//  Alpha
//
//  Created by Ryan Olson on 4/4/14.
//  Copyright © 2014 Unified Sense. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface ALPHAToolbarItem : UIButton

+ (instancetype)toolbarItemWithTitle:(NSString *)title image:(UIImage *)image;

@end
