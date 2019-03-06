//
//  NSObject+Property.h
//  Alpha
//
//  Created by Dal Rupnik on 29/11/2016.
//  Copyright © 2016 Unified Sense. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface NSObject (Property)

/*!
 *  Returns key value pair of property strings, where the key is property alpha_name,
 *  and value is the type of key.
 *
 *  @return dictionary of key-value mapped object properties
 */
- (NSDictionary *)alpha_properties;

+ (NSDictionary *)alpha_properties;

@end
