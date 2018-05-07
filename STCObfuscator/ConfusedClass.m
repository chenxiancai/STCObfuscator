//
//  ConfusedClass.m
//  STCObfuscator
//
//  Created by chenxiancai on 2018/3/6.
//  Copyright © 2018年 stevchen. All rights reserved.
//

#import "ConfusedClass.h"

@implementation ConfusedClass

- (BOOL)confusedMethod:(NSString *)method todoSomething:(NSString *)st
{
    BOOL doing = [self beginDoingSomething];
    return doing;
}

- (BOOL)beginDoingSomething
{
    return YES;
}

@end
