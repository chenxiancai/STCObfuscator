//
//  AppDelegate.m
//  STCObfuscator
//
//  Created by chenxiancai on 21/09/2017.
//  Copyright © 2017 stevchen. All rights reserved.
//

#import "AppDelegate.h"
#import "DetailViewController.h"
#import "STCObfuscator.h"

//import <Weibo_SDK/WeiboSDK.h>
#import <AFNetworking.h>
#import <SDWebImage/SDWebImageManager.h>
#import "UnConfusedClass.h"
#import "InheritUnConfusedClass.h"

@interface AppDelegate () <UISplitViewControllerDelegate>

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
#if (DEBUG == 1)
    // 该类的类名、属性和方法都不混淆
    [STCObfuscator obfuscatorManager].unConfuseClassNames = @[@"UnConfusedClass"];
    // 以testStaticLib为前缀开头的方法符号不混淆
    [STCObfuscator obfuscatorManager].unConfuseMethodPrefix = @[@"testStaticLib"];
    // 以RAC为前缀开头的类的类名、属性和方法都不混淆
    [STCObfuscator obfuscatorManager].unConfuseClassPrefix = @[@"RAC"];
    // md5加盐
    [STCObfuscator obfuscatorManager].md5Salt = @"go die trump";
    [[STCObfuscator obfuscatorManager] confuseWithRootPath:[NSString stringWithFormat:@"%s", STRING(ROOT_PATH)] resultFilePath:[NSString stringWithFormat:@"%@/STCDefination.h", [NSString stringWithFormat:@"%s", STRING(ROOT_PATH)]] linkmapPath:[NSString stringWithFormat:@"%s", STRING(LINKMAP_FILE)]];
#endif
    
    [self testStaticLib];
    [self testSDWebImage];
    [self testAFNetworking];
    [self testUnConfusedClass];
    [self testInheritUnConfusedClass];
    
    // Override point for customization after application launch.
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    UINavigationController *navigationController = [splitViewController.viewControllers lastObject];
    navigationController.topViewController.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem;
    splitViewController.delegate = self;
    return YES;
}

- (void)testStaticLib
{
    //NSLog(@"%@", [WeiboSDK getSDKVersion]);
}

- (void)testAFNetworking
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"www.baidu.com"]];
    [[AFHTTPSessionManager manager] downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        return nil;
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
    }];
}

- (void)testSDWebImage
{
    NSURL *url = [NSURL URLWithString:@"https://www.baidu.com"];
    [[SDWebImageDownloader sharedDownloader] downloadImageWithURL:url options:SDWebImageDownloaderLowPriority progress:^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
    } completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
    }];
}

- (void)testUnConfusedClass
{
    UnConfusedClass *unConfusedClass = [[UnConfusedClass alloc] init];
    [unConfusedClass notConfused];
}

- (void)testInheritUnConfusedClass
{
    InheritUnConfusedClass *inheritUnConfusedClass = [[InheritUnConfusedClass alloc] init];
    [inheritUnConfusedClass inheritUnConfusedClass];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


#pragma mark - Split view

- (BOOL)splitViewController:(UISplitViewController *)splitViewController collapseSecondaryViewController:(UIViewController *)secondaryViewController ontoPrimaryViewController:(UIViewController *)primaryViewController {
    if ([secondaryViewController isKindOfClass:[UINavigationController class]] && [[(UINavigationController *)secondaryViewController topViewController] isKindOfClass:[DetailViewController class]] && ([(DetailViewController *)[(UINavigationController *)secondaryViewController topViewController] detailItem] == nil)) {
        // Return YES to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
        return YES;
    } else {
        return NO;
    }
}

@end
