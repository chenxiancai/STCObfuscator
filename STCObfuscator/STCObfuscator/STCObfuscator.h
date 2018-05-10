//
//  STCObfuscator.h
//  STCObfuscator
//
//  Created by chenxiancai on 21/09/2017.
//  Copyright © 2017 stevchen. All rights reserved.
//

#import <Foundation/Foundation.h>

#define STRING(str) _STRING(str)
#define _STRING(str) #str

#if (DEBUG == 1)
@interface STCObfuscator : NSObject

+ (instancetype)obfuscatorManager;

- (instancetype)init NS_UNAVAILABLE;


/**
 不进行混淆的类
 */
@property (nonatomic, strong) NSArray *unConfuseClassNames;

/**
 不进行混淆的带特性前缀的类
 */
@property (nonatomic, strong) NSArray *unConfuseClassPrefix;

/**
 不进行混淆的带有特定前缀的符号名
 */
@property (nonatomic, strong) NSArray *unConfuseMethodPrefix;

/**
 hash加盐，方便每次混淆的符号的名称不一样
 */
@property (nonatomic, copy) NSString *md5Salt;

- (void)confuseWithRootPath:(NSString *)rootPath
             resultFilePath:(NSString *)filePath
                linkmapPath:(NSString *)linkmapPath;

@end
#endif
