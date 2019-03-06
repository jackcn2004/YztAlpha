//
//  NSScanner+Bonjour.h
//  Alpha
//
//  Created by Dal Rupnik on 12/12/2016.
//  Copyright © 2016 Unified Sense. All rights reserved.
//

//
// This file is ported from DTBonjour library, by Oliver Drobnik
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/**
 Category extension for `NSScanner` to deal with scanning the headers used by ALPHABonjour
 */

@interface NSScanner (Bonjour)

/**
 The receiver scans for DTBonjour headers.
 @param headers The output dictionary with the scanned headers
 @returns `YES` if successfully scanned the headers
 */
- (BOOL)alpha_scanBonjourConnectionHeaders:(NSDictionary **)headers;

@end
