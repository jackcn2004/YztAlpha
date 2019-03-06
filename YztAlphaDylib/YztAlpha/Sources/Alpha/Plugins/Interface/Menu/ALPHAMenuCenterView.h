//
//  ALPHAMenuCenterView.h
//  Alpha
//
//  Created by Dal Rupnik on 19/11/14.
//  Copyright © 2014 Unified Sense. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/*!
 *  Usage: Private to explorer menu, a rendered circle view that displays an icon and is assigned a long pressure
 *  recognizer.
 */
@interface ALPHAMenuCenterView : UIView

@property (nonatomic, strong) UIImage* image;
@property (nonatomic, strong) UIColor* mainBackgroundColor;

@end
