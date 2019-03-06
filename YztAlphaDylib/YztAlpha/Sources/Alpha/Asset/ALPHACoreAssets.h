//
//  ALPHACoreAssets.h
//  Alpha
//
//  Created by Dal Rupnik on 17/06/15.
//  Copyright © 2015 Unified Sense. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#import "ALPHAAsset.h"
#import "ALPHAAssetManager.h"

extern NSString *const ALPHAIconDragHandleIdentifier;

@interface ALPHADragHandleIcon : ALPHAAsset

@end

extern NSString *const ALPHAIconInfoIdentifier;

@interface ALPHAInfoIcon : ALPHAAsset

@end

extern NSString *const ALPHAIconCloseIdentifier;

@interface ALPHACloseIcon : ALPHAAsset

@end

extern NSString *const ALPHAIconMenuIdentifier;

@interface ALPHAMenuIcon : ALPHAAsset

@end

extern NSString *const ALPHAIconRemoteIdentifier;

@interface ALPHARemoteIcon : ALPHAAsset

@end

extern NSString *const ALPHALogoIdentifier;

@interface ALPHALogoAsset : ALPHAAsset

@end
