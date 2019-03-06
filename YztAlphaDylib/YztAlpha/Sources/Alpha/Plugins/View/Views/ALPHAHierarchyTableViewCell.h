//
//  ALPHAHierarchyTableViewCell.h
//  Alpha
//
//  Created by Dal Rupnik on 16/06/15.
//  Copyright © 2015 Unified Sense. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface ALPHAHierarchyTableViewCell : UITableViewCell

@property (nonatomic, assign) NSInteger viewDepth;
@property (nonatomic, strong) UIColor *viewColor;

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;

@end
