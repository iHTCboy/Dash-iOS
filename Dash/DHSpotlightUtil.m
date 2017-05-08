//
//  DHSpotlightUtil.m
//  Dash iOS
//
//  Created by HTC on 2017/5/7.
//  Copyright © 2017年 Kapeli. All rights reserved.
//

#import "DHSpotlightUtil.h"

#import "DHTypes.h"
#import "DHDBResult.h"
#import "DHDocsetManager.h"

@implementation DHSpotlightUtil

#pragma mark - Create Docset Spotlight

+ (void)sartCreateAllDocset:(NSArray<DHDocset *> *)docsets
{
    // support iOS9 later
    if ([UIDevice currentDevice].systemVersion.floatValue < 9.0) {
        return;
    }
    
    for (DHDocset * docset in docsets) {
        dispatch_queue_t queue = dispatch_queue_create([[NSString stringWithFormat:@"%u", arc4random() % 100000] UTF8String], 0);
        dispatch_async(queue, ^{
            [docset executeBlockWithinDocsetDBConnection:^(FMDatabase *db) {
                NSMutableArray *types = [NSMutableArray array];
                NSMutableDictionary *typesDict = [NSMutableDictionary dictionary];
                NSConditionLock *lock = [DHDocset stepLock];
                NSString *platform = docset.platform;
                [lock lockWhenCondition:DHLockAllAllowed];
                NSString *query = @"SELECT type, COUNT(rowid) FROM searchIndex GROUP BY type";
                if([docset.platform isEqualToString:@"apple"])
                {
                    if([DHAppleActiveLanguage currentLanguage] == DHNewActiveAppleLanguageSwift)
                    {
                        query = @"SELECT type, COUNT(rowid) FROM searchIndex WHERE path NOT LIKE '%<dash_entry_language=objc>%' AND path NOT LIKE '%<dash_entry_language=occ>%' GROUP BY type";
                    }
                    else
                    {
                        query = @"SELECT type, COUNT(rowid) FROM searchIndex WHERE path NOT LIKE '%<dash_entry_language=swift>%' GROUP BY type";
                    }
                }
                FMResultSet *rs = [db executeQuery:query];
                BOOL next = [rs next];
                [lock unlock];
                while(next)
                {
                    NSString *type = [rs stringForColumnIndex:0];
                    if(type && type.length)
                    {
                        NSInteger count = [rs intForColumnIndex:1];
                        NSString *pluralName = [DHTypes pluralFromEncoded:type];
                        if([pluralName isEqualToString:@"Categories"] && ([platform isEqualToString:@"python"] || [platform isEqualToString:@"flask"] || [platform isEqualToString:@"twisted"] || [platform isEqualToString:@"django"] || [platform isEqualToString:@"actionscript"] || [platform isEqualToString:@"nodejs"]))
                        {
                            pluralName = @"Modules";
                        }
                        
                        typesDict[type] = @{@"type": type, @"count": @(count), @"plural": pluralName};
                    }
                    [lock lockWhenCondition:DHLockAllAllowed];
                    next = [rs next];
                    [lock unlock];
                }
                NSMutableArray *typeOrder = [NSMutableArray arrayWithArray:[[DHTypes sharedTypes] orderedTypes]];
                [typeOrder removeObject:@"Guide"];
                [typeOrder removeObject:@"Section"];
                [typeOrder removeObject:@"Sample"];
                [typeOrder removeObject:@"File"];
                [typeOrder addObject:@"Guide"];
                [typeOrder addObject:@"Section"];
                [typeOrder addObject:@"Sample"];
                [typeOrder addObject:@"File"];
                if([platform isEqualToString:@"go"] || [platform isEqualToString:@"godoc"])
                {
                    [typeOrder removeObject:@"Type"];
                    [typeOrder insertObject:@"Type" atIndex:0];
                }
                if([platform isEqualToString:@"swift"])
                {
                    [typeOrder removeObject:@"Type"];
                    [typeOrder insertObject:@"Type" atIndex:0];
                }
                for(NSString *key in typeOrder)
                {
                    NSDictionary *type = typesDict[key];
                    if(type)
                    {
                        [types addObject:type];
                    }
                }
                
                // resuslt
                for ( NSDictionary * dic in types) {
                    NSString * type = [dic objectForKey:@"type"];
                    [docset executeBlockWithinDocsetDBConnection:^(FMDatabase *db2) {
                        NSMutableSet *duplicates = [NSMutableSet set];
                        NSMutableArray *entries = [NSMutableArray array];
                        NSConditionLock *lock2 = [DHDocset stepLock];
                        [lock2 lockWhenCondition:DHLockAllAllowed];
                        FMResultSet *rs2 = [db2 executeQuery:@"SELECT path, name, type FROM searchIndex WHERE type = ? ORDER BY LOWER(name)", type];
                        BOOL next2 = [rs2 next];
                        [lock2 unlock];
                        while(next2)
                        {
                            DHDBResult *result = [DHDBResult resultWithDocset:docset resultSet:rs2];
                            if(result)
                            {
                                NSString *duplicateHash = [result browserDuplicateHash];
                                if(!duplicateHash || ![duplicates containsObject:duplicateHash])
                                {
                                    if(duplicateHash)
                                    {
                                        [duplicates addObject:duplicateHash];
                                    }
                                    [entries addObject:result];
                                }
                            }
                            [lock2 lockWhenCondition:DHLockAllAllowed];
                            next2 = [rs2 next];
                            [lock2 unlock];
                        }
                        
                        NSMutableArray<CSSearchableItem *> *searchableItems = [NSMutableArray array];
                        for (DHDBResult *result in entries) {
                            
                            NSString * docsetRelativePath = docset.relativePath;
                            // identifier= docset + K_CS_SCHEMES + name
                            NSString * identifier = [NSString stringWithFormat:@"%@%@%@",docsetRelativePath,K_CS_SCHEMES,result.originalName];
                            NSString * title = result.originalName;
                            NSString * content = [NSString stringWithFormat:@"Platform:%@，Type:%@",result.platform,result.type];
                            
                            // spotlight item
                            CSSearchableItem *item = [self createCSSearchableItemWithUniqueIdentifier:identifier title:title content:content thumbnail:UIImagePNGRepresentation(result.platformImage) contentCreationDate:nil];
                            [searchableItems addObject:item];
                        }
                        [self indexSearchableItems:searchableItems completionHandler:^(NSError * _Nullable error) {
                            
                        }];
                        
                    } readOnly:YES lockCondition:DHLockAllAllowed optimisedIndex:YES];
                }
                
            } readOnly:YES lockCondition:DHLockAllAllowed optimisedIndex:YES];
        });
    }
}

+ (DHDBResult *)fetchDHDBReshultWithIdentifier:(NSString *)identifier
{
    identifier = [identifier stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSArray * targetArray = [identifier componentsSeparatedByString:K_CS_SCHEMES];
    if (targetArray.count == 2) {
        NSString * docsetRelativePath = targetArray.firstObject;
        NSString * originalName = targetArray.lastObject;
        DHDocset *docset = [[DHDocsetManager sharedManager] docsetWithRelativePath:docsetRelativePath];
        NSString *docsetSQLPath = (docset.tempOptimisedIndexPath) ? docset.tempOptimisedIndexPath : docset.optimisedIndexPath;
        if(!docsetSQLPath)
        {
            return nil;
        }
        FMDatabase *db = [FMDatabase databaseWithPath:docsetSQLPath];
        [db openWithFlags:SQLITE_OPEN_READONLY];
        [db registerFTSExtensions];
        FMResultSet *rs = [db executeQuery:@"SELECT path, name, type FROM searchIndex WHERE name = ?", originalName];
        BOOL next = [rs next];
        DHDBResult * result = nil;
        if (next) {
            result = [DHDBResult resultWithDocset:docset resultSet:rs];
        }
        [db close];
        return result;
    }
    
    return nil;
}

#pragma mark - Create Spotlight Items

/**
 *  创建一般搜索
 *
 *  @return 一般搜索
 */
+ (CSSearchableItem *_Nullable)createCSSearchableItemWithUniqueIdentifier:(NSString * _Nullable)identifier title:(NSString * _Nullable)title content:(NSString *_Nullable)content thumbnail:(NSData * _Nullable)thumbnail contentCreationDate:(NSDate *_Nullable)contentCreationDate{
    return [self createCSSearchableItemWithUniqueIdentifier:identifier title:title content:content thumbnail:thumbnail keywords:nil contentType:contentCreationDate?(NSString*)kUTTypeMessage:nil contentCreationDate:contentCreationDate expirationDate:nil rating:nil ratingDescription:nil];
}

/**
 *  创建带星评搜索
 *
 *  @return 创建带星评搜索
 */
+ (CSSearchableItem *_Nullable)createCSSearchableItemWithUniqueIdentifier:(NSString * _Nullable)identifier title:(NSString * _Nullable)title content:(NSString *_Nullable)content thumbnail:(NSData * _Nullable)thumbnail rating:(NSNumber *_Nullable)rating ratingDescription:(NSString *_Nullable)ratingDescription{
    return [self createCSSearchableItemWithUniqueIdentifier:identifier title:title content:content thumbnail:thumbnail keywords:nil contentType:(NSString*)kUTTypeVideo contentCreationDate:nil expirationDate:nil rating:rating ratingDescription:ratingDescription];
}

/**
 * 创建自定义搜索
 */
+ (CSSearchableItem *)createCSSearchableItemWithUniqueIdentifier:(NSString * _Nullable)identifier title:(NSString * _Nullable)title content:(NSString *_Nullable)content thumbnail:(NSData * _Nullable)thumbnail keywords:(NSArray<NSString *>* _Nullable)keywords contentType:(NSString *_Nullable)contentType contentCreationDate:(NSDate *_Nullable)contentCreationDate expirationDate:(NSDate *_Nullable)expirationDate rating:(NSNumber *_Nullable)rating ratingDescription:(NSString *_Nullable)ratingDescription{
    NSString * bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    
    CSSearchableItemAttributeSet *attributedSet = [[CSSearchableItemAttributeSet alloc]initWithItemContentType:bundleIdentifier];
    
    if (title) {
        attributedSet.title = title;
    }
    if (content) {
        attributedSet.contentDescription = content;
    }
    if (thumbnail) {
        attributedSet.thumbnailData = thumbnail;
    }
    if (keywords) {
        attributedSet.keywords = keywords;
    }
    if(contentType){
        attributedSet.contentType = contentType;
    }
    if(contentCreationDate){
        attributedSet.contentCreationDate = contentCreationDate;
    }
    if (rating) {
        attributedSet.rating = rating;
    }
    if (ratingDescription) {
        attributedSet.ratingDescription = ratingDescription;
    }
    
    CSSearchableItem *item = [[CSSearchableItem alloc]initWithUniqueIdentifier:identifier domainIdentifier:bundleIdentifier attributeSet:attributedSet];
    if (expirationDate) {
        item.expirationDate = expirationDate;
    }
    return item;
}


+ (void)indexSearchableItems:(NSArray<CSSearchableItem *> * _Nullable)items completionHandler:(void (^ __nullable)(NSError * __nullable error))completionHandler{
    [[CSSearchableIndex defaultSearchableIndex] indexSearchableItems:items completionHandler:^(NSError * _Nullable error) {
        if (completionHandler) {
            completionHandler(error);
        }
#ifdef DEBUG
        if (error != nil) {
            NSLog(@"%@",error.localizedDescription);
        }else{
            NSLog(@"create Core Spotlight success");
        }
#endif
    }];
}

@end
