//
//  DHSpotlightUtil.h
//  Dash iOS
//
//  Created by HTC on 2017/5/7.
//  Copyright © 2017年 Kapeli. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CoreSpotlight/CoreSpotlight.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "DHDocset.h"

#define K_CS_SCHEMES   @"__K_CS_SCHEMES__"

@interface DHSpotlightUtil : NSObject

+ (void)sartCreateAllDocset:(NSArray<DHDocset *> *_Nullable)docsets;

+ (DHDBResult *_Nullable)fetchDHDBReshultWithIdentifier:(NSString *_Nonnull)identifier;

+ (CSSearchableItem *_Nullable)createCSSearchableItemWithUniqueIdentifier:(NSString * _Nullable)identifier title:(NSString * _Nullable)title content:(NSString *_Nullable)content thumbnail:(NSData * _Nullable)thumbnail contentCreationDate:(NSDate *_Nullable)contentCreationDate;

+ (CSSearchableItem *_Nullable)createCSSearchableItemWithUniqueIdentifier:(NSString * _Nullable)identifier title:(NSString * _Nullable)title content:(NSString *_Nullable)content thumbnail:(NSData * _Nullable)thumbnail rating:(NSNumber *_Nullable)rating ratingDescription:(NSString *_Nullable)ratingDescription;

+ (CSSearchableItem *_Nullable)createCSSearchableItemWithUniqueIdentifier:(NSString * _Nullable)identifier title:(NSString * _Nullable)title content:(NSString *_Nullable)content thumbnail:(NSData * _Nullable)thumbnail keywords:(NSArray<NSString *>* _Nullable)keywords contentType:(NSString *_Nullable)contentType contentCreationDate:(NSDate *_Nullable)contentCreationDate expirationDate:(NSDate *_Nullable)expirationDate rating:(NSNumber *_Nullable)rating ratingDescription:(NSString *_Nullable)ratingDescription;

+ (void)indexSearchableItems:(NSArray<CSSearchableItem *> * _Nullable)items completionHandler:(void (^ __nullable)(NSError * __nullable error))completionHandler;


@end
