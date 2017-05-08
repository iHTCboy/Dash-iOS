//
//  Copyright (C) 2016  Kapeli
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "DHAppDelegate.h"
#import "DHDocsetDownloader.h"
#import "DHUserRepo.h"
#import "DHCheatRepo.h"
#import "DHDocsetTransferrer.h"
#import "DHDocsetManager.h"
#import "DHTarixProtocol.h"
#import "DHBlockProtocol.h"
#import "DHCSS.h"
#import "DHWebViewController.h"
#import "DHAppUpdateChecker.h"
#import "DHDocsetBrowser.h"
//#import <HockeySDK/HockeySDK.h>
#import "DHRemoteServer.h"
#import "DHRemoteProtocol.h"
#import "BaiduMobStat.h"
#import "DHDeviceUtil.h"
#import "DHSpotlightUtil.h"

@implementation DHAppDelegate

+ (DHAppDelegate *)sharedDelegate
{
    return (id)[[UIApplication sharedApplication] delegate];
}

+ (UIStoryboard *)mainStoryboard
{
    return [self sharedDelegate].window.rootViewController.storyboard;
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self setDoNotBackUp]; // this needs to be first because it deletes the preferences after a backup restore
    NSLog(@"Home Path: %@", homePath);
    [self.window makeKeyAndVisible];
    
    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    if(cacheDir)
    {
        [[NSFileManager defaultManager] removeItemAtPath:[cacheDir stringByAppendingPathComponent:@"com.apple.nsurlsessiond/Downloads"] error:nil];
    }
    
    
//#ifndef DEBUG
//    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"3b2036819813be1b22bb086f00eea499"];
//    [[BITHockeyManager sharedHockeyManager].crashManager setCrashManagerStatus:BITCrashManagerStatusAutoSend];
//    [[BITHockeyManager sharedHockeyManager] startManager];
//    [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];
//#endif
    
#ifdef DEBUG
    [self checkCommitHashes];
#else
    [self startBaiduMobStat];
#endif
//    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:@"Mozilla/5.0 (iPhone; CPU iPhone OS 10_10 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12B411 Xcode/6.1.0", @"UserAgent", nil];
//    [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
    
//    NSLog(@"%@", [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]);

    NSURLCache *sharedCache = [[NSURLCache alloc] initWithMemoryCapacity:4*1024*1024 diskCapacity:32*1024*1024 diskPath:@"dh_nsurlcache"];
    [sharedCache removeAllCachedResponses];
    [NSURLCache setSharedURLCache:sharedCache];
    [NSURLProtocol registerClass:[DHTarixProtocol class]];
    [NSURLProtocol registerClass:[DHRemoteProtocol class]];
    [NSURLProtocol registerClass:[DHBlockProtocol class]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]]];
    [DHDocset stepLock];
    [DHDocsetManager sharedManager];
    [DHCSS sharedCSS];
    [DHDBResultSorter sharedSorter];
    [DHDBNestedResultSorter sharedSorter];
//    self.window.tintColor = [UIColor purpleColor];
    [DHDocsetDownloader sharedDownloader];
    [DHDocsetTransferrer sharedTransferrer];
    [DHUserRepo sharedUserRepo];
    [DHCheatRepo sharedCheatRepo];
    [DHRemoteServer sharedServer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clipboardChanged:) name:UIPasteboardChangedNotification object:nil];
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    UITextField *lagFreeField = [[UITextField alloc] init];
    [self.window addSubview:lagFreeField];
    [lagFreeField becomeFirstResponder];
    [lagFreeField resignFirstResponder];
    [lagFreeField setHidden:YES];
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)actualURL sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if([[actualURL absoluteString] hasCaseInsensitivePrefix:@"dash://"] || [[actualURL absoluteString] hasCaseInsensitivePrefix:@"dash-plugin://"])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:DHPrepareForURLSearch object:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DHPerformURLSearch object:[actualURL absoluteString]];
        });
    }
    else
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            NSError *regexError;
            NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"Inbox/.+[\\.docset]$" options:0 error:&regexError];
            NSArray *matches;
            if (regexError) {
                NSLog(@"%@", regexError.localizedDescription);
            }else{
                matches = [regex matchesInString:[actualURL absoluteString] options:0 range:NSMakeRange(0, [actualURL absoluteString].length)];
            }
            if (matches.count) {
                [self moveInboxContentsToDocuments];
            }
        });
    }
    return YES;
}

- (UINavigationController *)navigationController
{
    if([self.window.rootViewController isKindOfClass:[UINavigationController class]])
    {
        return (UINavigationController*)self.window.rootViewController;
    }
    return self.window.rootViewController.navigationController;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{

}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
//    // Dash check update
//    if(![[DHAppUpdateChecker sharedUpdateChecker] alertIfUpdatesAreScheduled])
//    {
//        [[DHAppUpdateChecker sharedUpdateChecker] backgroundCheckForUpdatesIfNeeded];
//        if(![[DHDocsetDownloader sharedDownloader] alertIfUpdatesAreScheduled])
//        {
//            [[DHDocsetDownloader sharedDownloader] backgroundCheckForUpdatesIfNeeded];
//            if(![[DHUserRepo sharedUserRepo] alertIfUpdatesAreScheduled])
//            {
//                [[DHUserRepo sharedUserRepo] backgroundCheckForUpdatesIfNeeded];
//                if(![[DHCheatRepo sharedCheatRepo] alertIfUpdatesAreScheduled])
//                {
//                    [[DHCheatRepo sharedCheatRepo] backgroundCheckForUpdatesIfNeeded];
//                }
//            }
//        }
//    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    NSLog(@"did receive memory warning");
}

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        completionHandler();
    }];
}


#pragma mark CoreSpotlight
- (BOOL)application:(nonnull UIApplication *)application continueUserActivity:(nonnull NSUserActivity *)userActivity restorationHandler:(nonnull void (^)(NSArray * _Nullable))restorationHandler {
    
    NSString *indentifier = userActivity.userInfo[@"kCSSearchableItemActivityIdentifier"];
    
    DHDBResult * result = [DHSpotlightUtil fetchDHDBReshultWithIdentifier:indentifier];

#ifdef DEBUG
    NSLog(@"%@",indentifier);
    NSLog(@"%@",result.name);
#endif
    
    if (!result) {
        return YES;
    }
    
    if(isRegularHorizontalClass)
    {
        [[DHWebViewController sharedWebViewController] loadResult:result];
    }
    else
    {
        [[DHWebViewController sharedWebViewController] loadResult:result];
        UINavigationController * naviVC = [UIApplication sharedApplication].keyWindow.rootViewController.childViewControllers.firstObject;
        UIViewController * childVC = naviVC.childViewControllers.lastObject;
        
        if (![[childVC class] isSubclassOfClass:[DHWebViewController class]]) {
            DHWebViewController *webViewController = [DHWebViewController sharedWebViewController];
            webViewController.result = result;
            [naviVC pushViewController:webViewController animated:YES];
        }

    }
    
    return YES;
}


#pragma mark - 3D Touch handle
- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void(^)(BOOL succeeded))completionHandler{
    
    if([shortcutItem.type isEqualToString:@"3dtouch.search"]){
        // search docset
        [[NSNotificationCenter defaultCenter] postNotificationName:DHPrepareForURLSearch object:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DHPerformURLSearch object:@"3dtouchSearch://"];
        });
    }
}


#pragma mark - UIStateRestoration

- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder {
    return YES;
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder {
    return YES;
}

#pragma mark - Method

- (void)setDoNotBackUp
{
    NSString *path = [homePath stringByAppendingPathComponent:@"Docsets"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if(![fileManager fileExistsAtPath:path])
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        for(NSString *key in @[@"DHDocsetDownloaderScheduledUpdate", @"DHDocsetDownloader", @"DHDocsetTransferrer", @"docsets"])
        {
            [defaults removeObjectForKey:key];
        }
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSURL *url = [NSURL fileURLWithPath:path];
    [url setResourceValue:@YES forKey: NSURLIsExcludedFromBackupKey error:nil];
}

- (void)clipboardChanged:(NSNotification*)notification
{
    NSString *string = [UIPasteboard generalPasteboard].string;
    if(string && string.length && [DHRemoteServer sharedServer].connectedRemote)
    {
        self.clipboardChangedTimer = [self.clipboardChangedTimer invalidateTimer];
        self.clipboardChangedTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 block:^{
            [[DHRemoteServer sharedServer] sendObject:@{@"string": string} forRequestName:@"syncClipboard" encrypted:YES toMacName:[DHRemoteServer sharedServer].connectedRemote.name];
        } repeats:NO];
    }
}

- (void)checkCommitHashes
{
    NSDictionary *hashes = @{@"DHDBSearcher": @"ea3cca9",
                             @"DHDBResult": @"e3c5910",
                             @"DHDBUnifiedResult": @"b332793",
                             @"DHQueuedDB": @"0199255",
                             @"DHUnifiedQueuedDB": @"dd42266",
                             @"DHDBUnifiedOperation": @"1671a90",
                             @"DHWebViewController": @"7704db9",
                             @"DHWebPreferences": @"8a62071",
                             @"DHDocsetDownloader": @"0863f2d",
                             @"PlatformIcons": @"006c55f",
                             @"DHTypes": @"db8874c",
                             @"Types": @"d567e07",
                             @"CSS": @"a43a406",
                             };
    [hashes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString *plistHash = [[NSBundle mainBundle] infoDictionary][[key stringByAppendingString:@"Commit"]];
        if(![plistHash isEqualToString:@"not set"] && ![plistHash isEqualToString:obj])
        {
            NSLog(@"Wrong git hash %@ for %@. Maybe you forgot to sync something or update this list?", plistHash, key);
        }
    }];
}

- (DHWindow *)window
{
    if(self._window)
    {
        return self._window;
    }
    self._window = [[DHWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    return self._window;
}

- (void)moveInboxContentsToDocuments {
    
    NSError *fileManagerError;
    
    NSString *inboxDirectory = [NSString stringWithFormat:@"%@/Inbox", transfersPath];
    NSArray *inboxContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:inboxDirectory error:&fileManagerError];
    
    //move all the files over
    for (int i = 0; i != [inboxContents count]; i++) {
        NSString *oldPath = [NSString stringWithFormat:@"%@/%@", inboxDirectory, [inboxContents objectAtIndex:i]];
        NSString *newPath = [NSString stringWithFormat:@"%@/%@", transfersPath, [inboxContents objectAtIndex:i]];
        [[NSFileManager defaultManager] moveItemAtPath:oldPath toPath:newPath error:&fileManagerError];
        if (fileManagerError) {
            NSLog(@"%@",fileManagerError.localizedDescription);
        }
    }
}


#pragma mark - Other Events

/**
 *  初始化百度统计SDK
 */
- (void)startBaiduMobStat {
    BaiduMobStat* statTracker = [BaiduMobStat defaultStat];
    // 此处(startWithAppId之前)可以设置初始化的可选参数，具体有哪些参数，可详见BaiduMobStat.h文件，例如：
    statTracker.shortAppVersion  = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    //    statTracker.enableDebugOn = YES;
    [statTracker startWithAppId:@"0bf01c1f11"]; // 设置您在mtj网站上添加的app的appkey,此处AppId即为应用的appKey
    // 其它事件
    [statTracker logEvent:@"usermodelName" eventLabel:[DHDeviceUtil deviceModelName]];
    [statTracker logEvent:@"systemVersion" eventLabel:[UIDevice currentDevice].systemVersion];
    
}


@end
