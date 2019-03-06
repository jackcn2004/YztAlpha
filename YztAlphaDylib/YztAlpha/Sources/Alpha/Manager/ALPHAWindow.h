//
//  ALPHAWindow.h
//  Alpha
//
//  Created by Ryan Olson on 4/13/14.
//  Copyright © 2014 Unified Sense. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@protocol ALPHAWindowEventDelegate;

@interface ALPHAWindow : UIWindow

@property (nonatomic, weak) id <ALPHAWindowEventDelegate> eventDelegate;

@end

@protocol ALPHAWindowEventDelegate <NSObject>

- (BOOL)shouldHandleTouchAtPoint:(CGPoint)pointInWindow;

@end
