//
//  STCObfuscator.h
//  STCObfuscator
//
//  Created by chenxiancai on 21/09/2017.
//  Copyright © 2017 stevchen. All rights reserved.
//

#import <Foundation/Foundation.h>

#if (DEBUG == 1)
@interface STCObfuscator : NSObject

+ (instancetype)obfuscatorManager;

- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong) NSArray *unConfuseClassNames;
@property (nonatomic, copy) NSString *md5Salt;

- (void)confuseWithRootPath:(NSString *)rootPath
             resultFilePath:(NSString *)filePath
                linkmapPath:(NSString *)linkmapPath;

@end
#endif
