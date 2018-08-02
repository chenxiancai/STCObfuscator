//
//  STCObfuscator.m
//  STCObfuscator
//
//  Created by chenxiancai on 21/09/2017.
//  Copyright © 2017 stevchen. All rights reserved.
//


#import "STCObfuscator.h"
#import <objc/runtime.h>
#import <CommonCrypto/CommonDigest.h>
#include "ahocorasick.h"

@interface NSString (STCObfuscator)

- (NSString *)stcSubstringToIndex:(NSInteger)index;

- (NSString *)stcSubstringFromIndex:(NSInteger)index;

@end

@implementation NSString (STCObfuscator)
- (NSString *)stcSubstringToIndex:(NSInteger)index
{
    if ([self length] > index){
        return [self substringToIndex:index];
    }
    return self;
}

- (NSString *)stcSubstringFromIndex:(NSInteger)index
{
    if ([self length] > index){
        return [self substringFromIndex:index];
    }
    return self;
}

@end

#if (DEBUG == 1)
@implementation STCObfuscator

+ (instancetype)obfuscatorManager
{
    static STCObfuscator *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[[self class] alloc] init];
    });
    return manager;
}

#pragma mark - Public Methods
- (void)confuseWithRootPath:(NSString *)rootPath
             resultFilePath:(NSString *)filePath
                linkmapPath:(NSString *)linkmapPath
{
    if (!rootPath) {
        NSLog(@"😱rootPath is nil!");
        return;
    }
    
    if ([self checkExistConfusedResultInFile:filePath]) {
        NSLog(@"😱Confused File is not empty!");
        return;
    }
    
    NSString *linkmap = [self readDataFromPath:linkmapPath];
    if (!linkmap) {
        NSLog(@"😱Linkmap File is not exist!");
        return ;
    }
    
    NSMutableDictionary *unConfuseSymbolsDict = [NSMutableDictionary dictionary];
    [unConfuseSymbolsDict addEntriesFromDictionary:[self systemSymbolsDict]];
    [unConfuseSymbolsDict addEntriesFromDictionary:[self staticlibSymbolsWithRootPath:rootPath]];

    NSString *regex = nil;
    
    // filter objc symbols
    NSArray *objcSymbols = @[@"assign", @"copy", @"retain", @"atomic", @"nonatomic",
                             @"readwrite", @"readonly", @"strong", @"weak", @"setter",
                             @"getter",
                             @"class", @"defs", @"protocol", @"required", @"optional",
                             @"interface", @"public", @"package", @"protected", @"private",
                             @"property", @"end", @"implementation", @"synthesize", @"dynamic",
                             @"throw", @"try", @"catch", @"finally", @"synchronized",
                             @"autoreleasepool", @"selector", @"encode", @"compatibility_alias", @"string",
                             @"if", @"else", @"break", @"case", @"switch",
                             @"default", @"for", @"continue", @"do", @"while",
                             @"auto", @"char", @"const", @"double", @"enum",
                             @"extern", @"float", @"goto", @"int", @"long",
                             @"register", @"return", @"short", @"signed", @"sizeof",
                             @"static", @"struct", @"typedef", @"union", @"unsigned",
                             @"void", @"volatile", @"YES", @"NO", @"in",
                             @"self", @"super", @"NSUInteger", @"NSInteger", @"id",
                             @"SEL", @"IMP", @"block", @"NULL", @"null",
                             @"nil", @"instancetype", @"NS_ENUM", @"bridge",@"inline"
                             ];
    
    [objcSymbols enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [unConfuseSymbolsDict addEntriesFromDictionary:@{obj : @(YES)}];
    }];
    
    // filter protocol
    NSMutableSet *unConfuseProtocolSet = [NSMutableSet set];
    regex = @"PROTOCOL_\\$_.*?\\n";
    [self regularExpressionWithPattern:regex text:linkmap block:^(id obj, BOOL *stop) {
        NSString *name = (NSString *)obj;
        name = [name stringByReplacingOccurrencesOfString:@"PROTOCOL_$_" withString:@""];
        name = [name stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        if (name.length > 0) {
            [unConfuseProtocolSet addObject:name];
        }
    }];

    // filter protocol of protocol
    [unConfuseProtocolSet enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *protocolName = (NSString *)obj;
        Protocol *protocol = NSProtocolFromString(protocolName);
        NSArray *methods = [self allProtocolMethodsWithProtocal:protocol];
        for (NSString *methodName in methods) {
            NSArray *methodSections = [methodName componentsSeparatedByString:@":"];
            for (NSString *sectionName in methodSections) {
                if ([sectionName length] > 0) {
                    [unConfuseSymbolsDict addEntriesFromDictionary:@{sectionName: @(YES)}];
                }
            }
        }
    }];
    
    NSMutableArray *confuseClassNames = [NSMutableArray array];
    NSMutableArray *confuseMethods = [NSMutableArray array];
    
    // filter class method and instance method
    regex = @"\\](\\s+)(\\-|\\+)\\[.*?\\]";
    [self regularExpressionWithPattern:regex text:linkmap block:^(id obj, BOOL *stop) {
        NSString *objStr = [(NSString *)obj stringByReplacingOccurrencesOfString:@"] " withString:@""];
        NSString *name = [[(NSString *)objStr componentsSeparatedByString:@" "] firstObject];
        NSString *method = [[(NSString *)objStr componentsSeparatedByString:@" "] lastObject];
        name = [name stringByReplacingOccurrencesOfString:@"[" withString:@""];
        name = [name stringByReplacingOccurrencesOfString:@"-" withString:@""];
        name = [name stringByReplacingOccurrencesOfString:@"+" withString:@""];
        method = [method stringByReplacingOccurrencesOfString:@"]" withString:@""];
        method = [method stringByReplacingOccurrencesOfString:@" " withString:@""];
        
        NSCharacterSet *characterSet = [NSCharacterSet characterSetWithCharactersInString:@"_1234567890abcdefghijklmnopqrstuvwsyzABCDEFGHIJKLMNOPQRSTUVWXYZ"];

        if ([[name stringByTrimmingCharactersInSet:characterSet] length] > 0) {
            return;
        }
        
        if ([name isEqualToString:method]) {
            return;
        }
        
        if ([name length] == 0 || [method length] == 0) {
            return;
        }
        
        __block NSString *realName = name;
        // filter category
        NSString *regString = @"\\(.*?\\)";
        [self regularExpressionWithPattern:regString text:name block:^(id obj, BOOL *stop) {
            NSString *removeStr = (NSString *)obj;
            if (removeStr.length > 0) {
                realName = [realName stringByReplacingOccurrencesOfString:removeStr withString:@""];
            }
        }];
        
        if (![realName isEqualToString:NSStringFromClass([self class])]
            && ![unConfuseSymbolsDict objectForKey:realName]) {
            [confuseClassNames addObject:realName];
            [confuseMethods addObject:method];
        } else {
            NSArray *methodSections = [method componentsSeparatedByString:@":"];
            for (NSString *sectionName in methodSections) {
                if ([sectionName length] > 0) {
                    [unConfuseSymbolsDict addEntriesFromDictionary:@{sectionName: @(YES)}];
                }
            }
        }
        
    }];
    
    // get property
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    NSInteger index = 0;
    NSMutableDictionary *confuseProperty = [NSMutableDictionary dictionary];
    
    for (NSString *method in confuseMethods) {
        NSString *className = [confuseClassNames objectAtIndex:index];
        if ([self isCustomUnConfusedClass:NSClassFromString(className)]) {
            index ++;
            continue;
        }
        
        NSString *property = [method stringByReplacingOccurrencesOfString:@":" withString:@""];
        if ([self isPropertyWithClass:NSClassFromString(className) andProperty:property] ||
            [self isPropertyWithClass:NSClassFromString(className) andProperty:[@"_" stringByAppendingString:property]]) {
            [confuseProperty addEntriesFromDictionary:@{property: @(YES)}];
            [indexSet addIndex:index];
        }
        
        // filter setter and getter
        NSInteger setIndex = 0;
        for (NSString *setMethod in confuseMethods) {
            NSString *setClassName = [confuseClassNames objectAtIndex:setIndex];
            if ([setClassName isEqualToString:className]) {
                if ([setMethod hasPrefix:@"set"]
                    && [setMethod hasSuffix:@":"]) {
                    NSString *getMethod = [setMethod stringByReplacingOccurrencesOfString:@"set" withString:@""];
                    getMethod = [getMethod stringByReplacingOccurrencesOfString:@":" withString:@""];
                    if ([[[getMethod stcSubstringToIndex:1] uppercaseString] isEqualToString:[[method stcSubstringToIndex:1]uppercaseString]]
                        && [[getMethod stcSubstringFromIndex:1] isEqualToString:[method stcSubstringFromIndex:1]]) {
                        [confuseProperty addEntriesFromDictionary:@{method: @(YES)}];
                        [indexSet addIndex:index];
                        [indexSet addIndex:setIndex];
                        break;
                    }
                }
            }
            setIndex ++;
        }
        index ++;
    }
    [confuseClassNames removeObjectsAtIndexes:indexSet];
    [confuseMethods removeObjectsAtIndexes:indexSet];
    
    // filter method
    indexSet = [NSMutableIndexSet indexSet];
    index = 0;
    for (NSString *className in confuseClassNames) {
        NSString *method = [confuseMethods objectAtIndex:index];
        method = [method stringByReplacingOccurrencesOfString:@" " withString:@""];
        NSArray *methodSection = [method componentsSeparatedByString:@":"];
        
        for (NSString *section in methodSection) {
            // filter system method
            BOOL hasPre = NO;
            for (NSString *prefix in self.unConfuseMethodPrefix) {
                if ([section hasPrefix:prefix]) {
                    hasPre = YES;
                    break;
                }
            }
            
            if ([method hasPrefix:@"."]
                || [method hasPrefix:@"init"]
                || hasPre) {
                [indexSet addIndex:index];
                [unConfuseSymbolsDict addEntriesFromDictionary:@{section: @(YES)}];
            // filter custom method
            } else if ([self isCustomUnConfusedClass:NSClassFromString(className)]) {
                [unConfuseSymbolsDict addEntriesFromDictionary:@{className: @(YES)}];
                [indexSet addIndex:index];
                [unConfuseSymbolsDict addEntriesFromDictionary:@{section: @(YES)}];
            // filter set method
            } else if ([method hasPrefix:@"set"] && [method hasSuffix:@":"]) {
                NSString *property = [method stcSubstringFromIndex:3];
                property = [property stringByReplacingOccurrencesOfString:@":" withString:@""];
                property = [[[property stcSubstringToIndex:1] lowercaseString] stringByAppendingString:[property stcSubstringFromIndex:1]];
                [confuseProperty addEntriesFromDictionary:@{property: @(YES)}];
                [indexSet addIndex:index];
                [unConfuseSymbolsDict addEntriesFromDictionary:@{section: @(YES)}];
            } else {
            // filter property
                for (NSString *property  in confuseProperty.allKeys) {
                    if ([property isEqualToString:section]) {
                        [indexSet addIndex:index];
                    }
                }
            }
        }
        index ++;
    }
    [confuseClassNames removeObjectsAtIndexes:indexSet];
    [confuseMethods removeObjectsAtIndexes:indexSet];
    
    // filter similar property except first letter with uppercase and lowercase
    NSMutableSet *removeProperty = [NSMutableSet set];
    [confuseProperty.allKeys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *property = (NSString *)obj;
        NSString *headerStr = [[property stcSubstringToIndex:1] uppercaseString];
        NSString *tailStr = [property stcSubstringFromIndex:1];
        NSString *similarProperty = [headerStr stringByAppendingString:tailStr];
        if (![property isEqualToString:similarProperty]) {
            [confuseProperty.allKeys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([(NSString *)obj isEqualToString:similarProperty]) {
                    [removeProperty addObject:property];
                    [removeProperty addObject:similarProperty];
                    *stop = YES;
                }
            }];
        }
    }];
    
    [removeProperty enumerateObjectsUsingBlock:^(id  _Nonnull removeObj, BOOL * _Nonnull removeStop) {
        [confuseProperty.allKeys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([(NSString *) removeObj isEqualToString:(NSString *)obj]) {
                [confuseProperty removeObjectForKey:obj];
                *stop = YES;
            }
        }];
    }];
    
    // start obfuscator
    NSMutableString *result = [[NSMutableString alloc] init];
    [result appendString:@"\n\n#if (DEBUG != 1)\n\n//--------------------Obfuscator--------------------\n\n"];

    NSMutableDictionary *jsonObjects = [NSMutableDictionary dictionary];
    NSSet *classNameSet = [NSSet setWithArray:confuseClassNames];
    NSSet *methodSet = [NSSet setWithArray:confuseMethods];
    
    // confuse class name
    [classNameSet enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *name = (NSString *)obj;
        NSString *newStr = [NSString stringWithFormat:@"#ifndef %@\n#define %@ %@\n#endif\n",name, name, [self encodeWithString:name]];
        [result appendString:newStr];
        [jsonObjects addEntriesFromDictionary:@{[self encodeWithString:name]: name}];
    }];
    
    // confuse method
    NSMutableSet *confuseMethodSet = [NSMutableSet set];
    [methodSet enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *method = (NSString *)obj;
        NSString *temp = [method stringByReplacingOccurrencesOfString:@" " withString:@""];
        NSArray *methodSection = [temp componentsSeparatedByString:@":"];
        
        for (NSString *str in methodSection) {
            if (str.length > 1
                && ![[unConfuseSymbolsDict objectForKey:str] boolValue]) {
                [confuseMethodSet addObject:str];
                NSString *newStr = [NSString stringWithFormat:@"#ifndef %@\n#define %@ %@\n#endif\n", str,str, [self encodeWithString:str]];
                [result appendString:newStr];
                [jsonObjects addEntriesFromDictionary:@{[self encodeWithString:str]: str}];
            }
        }
    }];
    
    // confuse property
    NSMutableSet *confusePropertySet = [NSMutableSet set];
    [confuseProperty.allKeys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        NSString *property = (NSString *)obj;
        NSString *str = [property stringByReplacingOccurrencesOfString:@" " withString:@""];
        NSString *setStr = [@"set" stringByAppendingString:[[str stcSubstringToIndex:1] uppercaseString]];
        setStr = [setStr stringByAppendingString:[str stcSubstringFromIndex:1]];
        if (str.length > 1
            && ![[unConfuseSymbolsDict objectForKey:str] boolValue]
            && ![[unConfuseSymbolsDict objectForKey:setStr] boolValue]
            ) {
            [confusePropertySet addObject:str];
            [confusePropertySet addObject:setStr];
            [confusePropertySet addObject:[@"_" stringByAppendingString:str]];
            
            NSString *encryptStr = [self encodeWithString:str];
            // property
            NSString *newStr = [NSString stringWithFormat:@"#ifndef %@\n#define %@ %@\n#endif\n", str, str, encryptStr];
            [result appendString:newStr];
            [jsonObjects addEntriesFromDictionary:@{encryptStr: str}];

            // private property
            newStr = [NSString stringWithFormat:@"#ifndef _%@\n#define _%@ _%@\n#endif\n", str, str, encryptStr];
            [result appendString:newStr];
            [jsonObjects addEntriesFromDictionary:@{[@"_" stringByAppendingString:encryptStr]: [@"_" stringByAppendingString:str]}];

            // setter
            NSString *firstStr = [[str stcSubstringToIndex:1] uppercaseString];
            NSString *otherStr = [str stcSubstringFromIndex:1];
            newStr = [NSString stringWithFormat:@"#ifndef set%@%@\n#define set%@%@ set%@\n#endif\n", firstStr, otherStr,firstStr,otherStr, encryptStr];
            [result appendString:newStr];
            [jsonObjects addEntriesFromDictionary:@{[@"set" stringByAppendingString:encryptStr]: [@"set" stringByAppendingString:str]}];

        }
    }];
    
    // filter hardcode
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSMutableString *hardCodeStr = [NSMutableString stringWithString:@"\n"];
        NSString *allSourcePath = rootPath;
        NSMutableSet *confuseSet = [NSMutableSet set];
        [confuseSet addObjectsFromArray:classNameSet.allObjects];
        [confuseSet addObjectsFromArray:confuseMethodSet.allObjects];
        [confuseSet addObjectsFromArray:confusePropertySet.allObjects];
        
        NSArray *paths = [self searchSourceFilesInPath:allSourcePath];
        NSMutableDictionary *hardCodes = [NSMutableDictionary dictionary];
        dispatch_apply(paths.count, queue, ^(size_t i) {
            NSDictionary *hardCodeDict = [self searchSourceFilesInPath:paths[i] withConfuseSet:confuseSet];
            @synchronized (hardCodes) {
                [hardCodes addEntriesFromDictionary:hardCodeDict];
            }
        });
    
        for (NSString *key in hardCodes.allKeys) {
            NSString *encryptStr = [self encodeWithString:key];
            [jsonObjects removeObjectForKey:encryptStr];
            [jsonObjects removeObjectForKey:[@"_" stringByAppendingString:encryptStr]];
            [jsonObjects removeObjectForKey:[@"set" stringByAppendingString:encryptStr]];
        }
        
        if (hardCodes.count > 0) {
            for (NSString *hardCode in hardCodes.allKeys) {
                __block BOOL isProperty = NO;
                [confuseProperty.allKeys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if ([(NSString *)obj isEqualToString:hardCode]) {
                        
                        [hardCodeStr appendString:[NSString stringWithFormat:@"//warning %@ hardcode in %@\n", hardCode, [hardCodes objectForKey:hardCode]]];
                        
                        [hardCodeStr appendString:[NSString stringWithFormat:@"#define %@ %@ \n", hardCode, hardCode]];
                        [hardCodeStr appendString:[NSString stringWithFormat:@"#define _%@ _%@ \n", hardCode, hardCode]];
                        
                        NSString *setStr = [@"set" stringByAppendingString:[[hardCode stcSubstringToIndex:1] uppercaseString]];
                        setStr = [setStr stringByAppendingString:[hardCode stcSubstringFromIndex:1]];
                        [hardCodeStr appendString:[NSString stringWithFormat:@"#define %@ %@ \n", setStr, setStr]];
                        isProperty = YES;
                        *stop = YES;
                    }
                }];
                
                if (!isProperty) {
                    [hardCodeStr appendString:[NSString stringWithFormat:@"//warning %@ hardcode in %@\n", hardCode, [hardCodes objectForKey:hardCode]]];
                    [hardCodeStr appendString:[NSString stringWithFormat:@"#define %@ %@ \n", hardCode, hardCode]];
                }
            }
            
            NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
            NSData* oldData = [fileHandle readDataToEndOfFile];
            NSData* stringData  = [hardCodeStr dataUsingEncoding:NSUTF8StringEncoding];
            [fileHandle truncateFileAtOffset:0];
            [fileHandle writeData:stringData];
            [fileHandle seekToEndOfFile];
            [fileHandle writeData:oldData];
            [fileHandle closeFile];
        }
        
        NSLog(@"\n[👌]hardCode finished scanning...!");
        NSString *jsonPath = [NSString stringWithFormat:@"%@/confuse.json", rootPath];
        NSData *data =  [NSJSONSerialization dataWithJSONObject:jsonObjects options:NSJSONWritingPrettyPrinted error:nil];
        [self saveData:data toPath:jsonPath];
        
        NSData *confuseHeaderContent = [NSData dataWithContentsOfFile:filePath];
        NSString *podPath = [NSString stringWithFormat:@"%@/Pods", rootPath];

        [self replacePCHInPodFileWithPath:podPath content:confuseHeaderContent];
        
    });
    
    [result appendString:@"\n#endif\n//------------------------------------------------------\n\n\n"];
    // update headerFile
    NSData *data = [NSData dataWithBytes:result.UTF8String length:result.length];
    [self saveData:data toPath:filePath];
}

#pragma mark - Private Methods

- (BOOL)checkExistConfusedResultInFile:(NSString *)filePath
{
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
    NSData* data = [fileHandle readDataToEndOfFile];
    [fileHandle closeFile];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    str = [str stringByReplacingOccurrencesOfString:@" " withString:@""];
    str = [str stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    if (str.length == 0) {
        return NO;
    } else {
        return YES;
    }
}

- (NSMutableDictionary *)systemSymbolsDict
{
    NSMutableArray *protocols = [NSMutableArray array];
    NSMutableSet *classSet = [NSMutableSet set];
    
    unsigned int imageOutCount = 0;
    unsigned int classOutCount = 0;
    const char ** images = objc_copyImageNames(&imageOutCount);
    for (unsigned int i = 0; i < imageOutCount; i++) {
        NSString *imageName = [NSString stringWithUTF8String:images[i]];

        //NSParagraphStyle Framework: /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/UIFoundation.framework/UIFoundation, 私有库的类也会放到公开库中使用
        /*
        if ([imageName containsString:@"PrivateFrameworks"]) {
            continue;
        }
        */
        if ([imageName containsString:@".framework"]
             ||[imageName containsString:@".dylib"]) {
            const char ** class = objc_copyClassNamesForImage(images[i], &classOutCount);
            for (unsigned int k = 0; k < classOutCount; k++) {
                
                Class cls = NSClassFromString([NSString stringWithUTF8String:class[k]]);
                [classSet addObject:[NSString stringWithUTF8String:class[k]]];
                
                unsigned int count;
                __unsafe_unretained Protocol **protocolList = class_copyProtocolList(cls,&count);
                NSMutableArray *protocals = [NSMutableArray arrayWithCapacity:count];
                for (int i = 0; i < count; i++) {
                    Protocol *protocol = protocolList[i];
                    [protocals addObject:NSStringFromProtocol(protocol)];
                }
                [protocols addObjectsFromArray:protocals];
                
                if (protocolList) {
                    free(protocolList);
                }
            }
            if (class) {
                free(class);
            }
        }
    }
    if (images) {
        free(images);
    }
    return  [self getSymbolsDictWith:protocols classSet:classSet];
}

- (NSMutableDictionary *)staticlibSymbolsWithRootPath:(NSString *)path
{
    NSMutableArray *protocols = [NSMutableArray array];
    NSMutableSet *classSet = [NSMutableSet set];
    
    NSArray *libSymbolPath = [self searchLibSymbolsFilesInPath:path];
    NSString *regex = @"(\\-|\\+)\\[.*?\\]";
    [libSymbolPath enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *path = (NSString *)obj;
        NSString *libSymbolsText = [self readDataFromPath:path];
        [self regularExpressionWithPattern:regex text:libSymbolsText block:^(id obj, BOOL *stop) {
            NSString *className = (NSString *)obj;
            className = [[className componentsSeparatedByString:@" "] firstObject];
            className = [className stringByReplacingOccurrencesOfString:@"-" withString:@""];
            className = [className stringByReplacingOccurrencesOfString:@"+" withString:@""];
            className = [className stringByReplacingOccurrencesOfString:@"[" withString:@""];
            
            NSCharacterSet *characterSet = [NSCharacterSet characterSetWithCharactersInString:@"_1234567890abcdefghijklmnopqrstuvwsyzABCDEFGHIJKLMNOPQRSTUVWXYZ"];
            if ([[className stringByTrimmingCharactersInSet:characterSet] length] > 0) {
                return;
            }
            
            if ([className length] == 0 ) {
                return;
            }
            
            [classSet addObject:className];
            
            unsigned int count;
            __unsafe_unretained Protocol **protocolList = class_copyProtocolList(NSClassFromString(className),&count);
            NSMutableArray *protocals = [NSMutableArray arrayWithCapacity:count];
            for (int i = 0; i < count; i++) {
                Protocol *protocol = protocolList[i];
                [protocals addObject:NSStringFromProtocol(protocol)];
            }
            [protocols addObjectsFromArray:protocals];
            
            if (protocolList) {
                free(protocolList);
            }
        }];
    }];
    
    return  [self getSymbolsDictWith:protocols classSet:classSet];
}

- (NSMutableDictionary *)getSymbolsDictWith:(NSArray *)protocols classSet:(NSSet *)classSet
{
    NSMutableDictionary *symbolsDict = [NSMutableDictionary dictionary];
    // get class method
    [classSet enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *className = (NSString *)obj;
        [symbolsDict addEntriesFromDictionary:@{className: @(YES)}];
        NSArray *properties = [self allPropertyWithClass:NSClassFromString(className)];
        for (NSString *propertyName in properties) {
            NSString *name = propertyName;
            if (![name hasPrefix:@"_"]) {
                [symbolsDict addEntriesFromDictionary:@{name: @(YES)}];
                [symbolsDict addEntriesFromDictionary:@{[@"_" stringByAppendingString:name]: @(YES)}];
                NSString *setStr = [@"set" stringByAppendingString:[[name stcSubstringToIndex:1] uppercaseString]];
                [symbolsDict addEntriesFromDictionary:@{[setStr stringByAppendingString:[name stcSubstringFromIndex:1]]: @(YES)}];
            }
        }
        NSArray *methods = [self allMethodsWithClass:NSClassFromString(className)];
        for (NSString *methodName in methods) {
            NSArray *methodSections = [methodName componentsSeparatedByString:@":"];
            for (NSString *sectionName in methodSections) {
                if ([sectionName length] > 0) {
                    [symbolsDict addEntriesFromDictionary:@{sectionName: @(YES)}];
                }
            }
        }
    }];
    
    // get protocol method
    for (NSString *protocolName in protocols) {
        Protocol *protocol = NSProtocolFromString(protocolName);
        NSArray *methods = [self allProtocolMethodsWithProtocal:protocol];
        for (NSString *methodName in methods) {
            NSArray *methodSections = [methodName componentsSeparatedByString:@":"];
            for (NSString *sectionName in methodSections) {
                if ([sectionName length] > 0) {
                    [symbolsDict addEntriesFromDictionary:@{sectionName: @(YES)}];
                }
            }
        }
    }
    
    return symbolsDict;
}

#pragma mark - file handle

- (NSMutableDictionary *)readFileToCheckHardCodeStringWithPath:(NSString *)path
                                                withConfuseSet:(NSSet *)confuseSet
                                                  isSourceCode:(BOOL)isSourceCode
{
    NSMutableDictionary *hardCodeNameDict = [NSMutableDictionary dictionary];
    
    NSMutableArray *symbols = [NSMutableArray array];
    if (isSourceCode) {
        for (NSString *symbol in confuseSet.allObjects) {
            [symbols addObject:[NSString stringWithFormat:@"@\"%@\"", symbol]];
        }
    } else {
        symbols = [NSMutableArray arrayWithArray:confuseSet.allObjects];
    }
    NSArray *result = [self searchInContent:[NSData dataWithContentsOfFile:path] withSymbols:symbols];
    
    for (NSString *obj in result) {
        NSString *str = [obj stringByReplacingOccurrencesOfString:@"@\"" withString:@""];
        str = [str stringByReplacingOccurrencesOfString:@"\"" withString:@""];
        [hardCodeNameDict addEntriesFromDictionary:@{(NSString *)str: path}];
        NSLog(@"\n[⚠️warning] code file:%@\nhas hardCode %@!", path, str);
    }
    return hardCodeNameDict;
}

- (void)saveData:(NSData *)data toPath:(NSString *)path
{
    NSOutputStream *fileStream = [NSOutputStream outputStreamToFileAtPath:path append:NO];
    [fileStream open];
    NSInteger       dataLength;
    const uint8_t * dataBytes;
    NSInteger       bytesWritten;
    NSInteger       bytesWrittenSoFar;
    dataLength = [data length];
    dataBytes  = [data bytes];
    bytesWrittenSoFar = 0;
    do {
        bytesWritten = [fileStream write:&dataBytes[bytesWrittenSoFar]maxLength:dataLength - bytesWrittenSoFar];
        assert(bytesWritten != 0);
        if (bytesWritten == -1) {
            break;
        } else {
            bytesWrittenSoFar += bytesWritten;
        }
    } while (bytesWrittenSoFar != dataLength);
    [fileStream close];
}

- (NSString *)readDataFromPath:(NSString *)path
{
    NSInputStream *inputStream = [[NSInputStream alloc] initWithFileAtPath:path];
    [inputStream open];
    NSInteger maxLength = 128;
    uint8_t readBuffer [maxLength];
    NSMutableString *readStr = [[NSMutableString alloc] init];
    BOOL endOfStreamReached = NO;
    while (! endOfStreamReached) {
        NSInteger bytesRead = [inputStream read:readBuffer
                                      maxLength:maxLength];
        if (bytesRead == 0) {
            endOfStreamReached = YES;
        } else if (bytesRead == -1) {
            endOfStreamReached = YES;
        } else {
            NSString *readBufferString =[[NSString alloc] initWithBytesNoCopy:readBuffer
                                                                       length:bytesRead
                                                                     encoding:NSUTF8StringEncoding
                                                                 freeWhenDone:NO];
            if (readBufferString) {
                [readStr appendString:readBufferString];
            }
        }
    }
    [inputStream close];
    NSString *text = [readStr copy];
    return text;
}


- (NSArray *)searchLibSymbolsFilesInPath:(NSString *)path
{
    static int fileCount = 0;
    NSMutableArray *files = [NSMutableArray array];
    NSFileManager * fileManger = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isExist = [fileManger fileExistsAtPath:path isDirectory:&isDir];
    if (isExist) {
        if (isDir) {
            NSArray * dirArray = [fileManger contentsOfDirectoryAtPath:path error:nil];
            NSString * subPath = nil;
            for (NSString * str in dirArray) {
                subPath  = [path stringByAppendingPathComponent:str];
                BOOL issubDir = NO;
                [fileManger fileExistsAtPath:subPath isDirectory:&issubDir];
                NSArray *fileArray = [self searchLibSymbolsFilesInPath:subPath];
                [files addObjectsFromArray:fileArray];
            }
        }else{
            if ([path hasSuffix:@".a.txt"] || [path hasSuffix:@".framework.txt"]) {
                fileCount ++;
                return @[path];
            } else {
                return @[];
            }
        }
    }else{
        NSLog(@"\n[⚠️warning] path not exist!");
        return files;
    }
    return files;
}

- (NSArray *)searchSourceFilesInPath:(NSString *)path
{
    static int fileCount = 0;
    NSMutableArray *files = [NSMutableArray array];
    NSFileManager * fileManger = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isExist = [fileManger fileExistsAtPath:path isDirectory:&isDir];
    if (isExist) {
        if (isDir) {
            NSArray * dirArray = [fileManger contentsOfDirectoryAtPath:path error:nil];
            NSString * subPath = nil;
            for (NSString * str in dirArray) {
                subPath  = [path stringByAppendingPathComponent:str];
                BOOL issubDir = NO;
                [fileManger fileExistsAtPath:subPath isDirectory:&issubDir];
                NSArray *fileArray = [self searchSourceFilesInPath:subPath];
                [files addObjectsFromArray:fileArray];
            }
        }else{
            if (([path hasSuffix:@".mm"]
                 ||[path hasSuffix:@".m"]
                 ||[path hasSuffix:@".h"])
                && ![path containsString:NSStringFromClass([self class])]) {
                fileCount ++;
                return @[path];
            } else if ([path hasSuffix:@".xib"]
                       ||[path hasSuffix:@".storyboard"]) {
                fileCount ++;
                return @[path];
            } else {
                return @[];
            }
        }
    }else{
        NSLog(@"\n[⚠️warning] path not exist!");
        return files;
    }
    return files;
}

- (NSDictionary *)searchSourceFilesInPath:(NSString *)path withConfuseSet:(NSSet *)confuseSet
{
    static int fileCount = 0;
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSFileManager * fileManger = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isExist = [fileManger fileExistsAtPath:path isDirectory:&isDir];
    if (isExist) {
        if (isDir) {
            NSArray * dirArray = [fileManger contentsOfDirectoryAtPath:path error:nil];
            NSString * subPath = nil;
            for (NSString * str in dirArray) {
                subPath  = [path stringByAppendingPathComponent:str];
                BOOL issubDir = NO;
                [fileManger fileExistsAtPath:subPath isDirectory:&issubDir];
                NSDictionary *hardcodeDict = [self searchSourceFilesInPath:subPath withConfuseSet:confuseSet];
                [dict addEntriesFromDictionary:hardcodeDict];
            }
        }else{
            if (([path hasSuffix:@".mm"]
                 ||[path hasSuffix:@".m"]
                 ||[path hasSuffix:@".h"])
                && ![path containsString:NSStringFromClass([self class])]) {
                fileCount ++;
                NSDictionary *hardCodeDict = [self readFileToCheckHardCodeStringWithPath:path withConfuseSet:confuseSet isSourceCode:YES];
                NSLog(@"\n[⏰] hardCode scanning...%@...!\n file:%@", @(fileCount), path);
                return hardCodeDict;
            } else if ([path hasSuffix:@".xib"]
                       ||[path hasSuffix:@".storyboard"]) {
                fileCount ++;
                NSDictionary *hardCodeDict = [self readFileToCheckHardCodeStringWithPath:path withConfuseSet:confuseSet isSourceCode:NO];
                NSLog(@"\n[⏰] hardCode scannig ...%@...!\n file:%@", @(fileCount), path);
                return hardCodeDict;
            } else {
                return  nil;
            }
        }
    }else{
        NSLog(@"\n[⚠️warning] path not exist!");
        return dict;
    }
    return dict;
}

- (void)replacePCHInPodFileWithPath:(NSString *)path content:(NSData *)data
{
    static int fileCount = 0;
    NSFileManager * fileManger = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isExist = [fileManger fileExistsAtPath:path isDirectory:&isDir];
    if (isExist) {
        if (isDir) {
            NSArray * dirArray = [fileManger contentsOfDirectoryAtPath:path error:nil];
            NSString * subPath = nil;
            for (NSString * str in dirArray) {
                subPath  = [path stringByAppendingPathComponent:str];
                BOOL issubDir = NO;
                [fileManger fileExistsAtPath:subPath isDirectory:&issubDir];
                [self replacePCHInPodFileWithPath:subPath content:data];
            }
        }else{
            if ([path hasSuffix:@".pch"]) {
                fileCount ++;
                NSData *content = [NSData dataWithContentsOfFile:path];
                if (![fileManger fileExistsAtPath:[path stringByAppendingString:@".txt"]]) {
                    [self saveData:content toPath:[path stringByAppendingString:@".txt"]];
                } else {
                    content = [NSData dataWithContentsOfFile:[path stringByAppendingString:@".txt"]];
                }
                NSMutableData *mudata = [NSMutableData dataWithData:content];
                [mudata appendData:data];
                [self saveData:[mudata copy] toPath:path];
                NSLog(@"\n[⏰]replace succusss...%@...!\nfile:%@", @(fileCount), path);
            }
        }
    }else{
        NSLog(@"\n[⚠️warning] path not exist!");
    }
}

#pragma mark - text searching

- (void)regularExpressionWithPattern:(NSString *)regexStr text:(NSString *)text block:(void (NS_NOESCAPE ^)(id obj, BOOL *stop))block
{
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:regexStr options:0 error:nil];
    NSArray *result = [regex matchesInString:text options:0 range:NSMakeRange(0, text.length)];
    
    NSMutableSet *mutableSet = [[NSMutableSet alloc] init];
    for(NSTextCheckingResult *match in result) {
        NSRange range = [match range];
        NSString *subStr = [text substringWithRange:range];
        [mutableSet addObject:subStr];
    }
    
    [mutableSet enumerateObjectsUsingBlock:block];
}

- (NSArray *)searchInContent:(NSData *)content withSymbols:(NSArray *)symbols
{
    NSUInteger contentPseudoStringLength = content.length / sizeof(char);
    AC_ALPHABET_t *contentPseudoString = (char *)malloc(contentPseudoStringLength * sizeof(char));
    if (contentPseudoString == NULL) {
        printf("Not enough memory to process.\n");
        exit(-1);
    }
    
    {
        char *begin = (char *)content.bytes;
        NSUInteger idx = 0;
        for (char *itr = begin; itr < begin + content.length; ++itr, ++idx) {
            contentPseudoString[idx] = *itr;
        }
    }
    
    AC_ALPHABET_t **patterns;
    NSUInteger patternsCount = symbols.count;
    patterns = (char **)malloc(patternsCount * sizeof(char*));
    if (patterns == NULL) {
        printf("Not enough memory to process.\n");
        exit(-1);
    }
    
    NSArray *keys = symbols;
    for (NSUInteger idx = 0; idx < patternsCount; ++idx) {
        patterns[idx] = (AC_ALPHABET_t *)[keys[idx] cStringUsingEncoding:NSASCIIStringEncoding];
    }
    
    AC_AUTOMATA_t *atm;
    AC_PATTERN_t tmpPattern;
    AC_TEXT_t tmpText;
    
    atm = ac_automata_init();
    
    for (NSUInteger idx = 0; idx < patternsCount; ++idx) {
        tmpPattern.astring = patterns[idx];
        tmpPattern.length = (unsigned int)strlen(tmpPattern.astring);
        
        ac_automata_add(atm, &tmpPattern);
    }
    
    ac_automata_finalize(atm);
    
    tmpText.astring = contentPseudoString;
    tmpText.length = (unsigned int)contentPseudoStringLength;
    ac_automata_settext(atm, &tmpText, 0);
    
    NSMutableDictionary *locations = [[NSMutableDictionary alloc] init];
    
    AC_MATCH_t *matchPattern;
    while ((matchPattern = ac_automata_findnext(atm))) {
        NSUInteger maxStringIdx = 0, maxStringLength = 0;
        for (NSUInteger idx = 0; idx < matchPattern->match_num; ++idx) {
            // always take the longest string
            if (matchPattern->patterns[idx].length > maxStringLength) {
                maxStringIdx = idx;
                maxStringLength = matchPattern->patterns[idx].length;
            }
        }
        
        NSString *pattern = [[NSString alloc] initWithBytes:matchPattern->patterns[maxStringIdx].astring
                                                     length:matchPattern->patterns[maxStringIdx].length * sizeof(char)
                                                   encoding:NSASCIIStringEncoding
                             ];
        NSNumber *position = @(matchPattern->position - matchPattern->patterns[maxStringIdx].length);
        locations[pattern] = (locations[pattern]
                              ? [locations[pattern] arrayByAddingObject:position]
                              : @[position]
                              );
    }
    
    ac_automata_release(atm);
    
    free(patterns);
    free(contentPseudoString);
    
    return locations.allKeys;
}

#pragma mark - md5 calc

- (NSString *)encodeWithString:(NSString *)str
{
    if ([self.md5Salt length] > 0) {
        str = [str stringByAppendingString:self.md5Salt];
    }
    NSMutableString *output = [NSMutableString stringWithString:@"_STC"];
    unsigned char temp[CC_MD5_DIGEST_LENGTH];
    CC_LONG len = (CC_LONG)str.length;
    CC_MD5(str.UTF8String, len, temp);
    for (int i = 0 ; i <CC_MD5_DIGEST_LENGTH; i++ ) {
        [output appendFormat:@"%02X", temp[i]^0x5A];
    }
    return [output stringByAppendingString:@"_"];
}

#pragma mark - runtime method

- (NSArray *)allProtocolWithClass:(Class)class
{
    unsigned int count;
    __unsafe_unretained Protocol **protocolList = class_copyProtocolList(class,&count);
    NSMutableArray *protocals = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count; i++) {
        Protocol *protocol = protocolList[i];
        [protocals addObject:NSStringFromProtocol(protocol)];
    }
    return [NSArray arrayWithArray:protocals];
}

- (NSArray *)allProtocolMethodsWithProtocal:(Protocol *)protocol
{
    NSMutableArray *methods = [NSMutableArray arrayWithCapacity:0];
    unsigned int numberOfMethods = 0;
    struct objc_method_description *methodDescriptions_opt = protocol_copyMethodDescriptionList(protocol, NO /* optional only */, YES, &numberOfMethods);
    for (unsigned int i = 0; i < numberOfMethods; ++i) {
        struct objc_method_description methodDescription = methodDescriptions_opt[i];
        SEL selector = methodDescription.name;
        [methods addObject:NSStringFromSelector(selector)];
    }
    
    struct objc_method_description *methodDescriptions_req = protocol_copyMethodDescriptionList(protocol, YES /* require only */, YES, &numberOfMethods);
    for (unsigned int i = 0; i < numberOfMethods; ++i) {
        struct objc_method_description methodDescription = methodDescriptions_req[i];
        SEL selector = methodDescription.name;
        [methods addObject:NSStringFromSelector(selector)];
    }
    
    return [NSArray arrayWithArray:methods];
}

- (NSArray *)allPropertyWithClass:(Class)class
{
    unsigned int outCount, i;
    NSMutableArray *propertyArray = [NSMutableArray array];
    objc_property_t * properties = class_copyPropertyList(class, &outCount);
    for (i = 0; i < outCount; i++) {
        objc_property_t  property =properties[i];
        NSString *tempPropertyName = [[NSString alloc] initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        [propertyArray addObject:tempPropertyName];
        
    }
    free(properties);
    return [NSArray arrayWithArray:propertyArray];
}

- (NSArray *)allMethodsWithClass:(Class)class
{
    unsigned int outCount, i;
    NSMutableArray *methodArray = [NSMutableArray array];
    Method * methods = class_copyMethodList(class, &outCount);
    for (i = 0; i < outCount; i++) {
        Method method = methods[i];
        SEL methodSEL = method_getName(method);
        NSString *tempPropertyName = [[NSString alloc] initWithCString:sel_getName(methodSEL) encoding:NSUTF8StringEncoding];
        [methodArray addObject:tempPropertyName];
    }
    free(methods);
    
    Class metaClass = object_getClass(class);
    Method * classMethods = class_copyMethodList(metaClass, &outCount);
    for (i = 0; i < outCount; i++) {
        Method method = classMethods[i];
        SEL methodSEL = method_getName(method);
        NSString *tempPropertyName = [[NSString alloc] initWithCString:sel_getName(methodSEL) encoding:NSUTF8StringEncoding];
        [methodArray addObject:tempPropertyName];
    }
    free(classMethods);
    
    return [NSArray arrayWithArray:methodArray];
}

- (BOOL)isCustomUnConfusedClass:(Class)class
{
    if (self.unConfuseClassNames.count == 0 && self.unConfuseClassPrefix == 0) {
        return NO;
    }
    Class superClass = class;
    while (superClass) {
        NSString *superClassName = NSStringFromClass(superClass);
        for (NSString *className in self.unConfuseClassNames) {
            if ([superClassName isEqualToString:className]) {
                return YES;
            }
        }
        for (NSString *prefix in self.unConfuseClassPrefix) {
            if ([superClassName hasPrefix:prefix]) {
                return YES;
            }
        }
        superClass = [superClass superclass];
    }
    return NO;
}

- (BOOL)isPropertyWithClass:(Class)class andProperty:(NSString *)propertyName
{
    unsigned int outCount, i;
    objc_property_t * properties = class_copyPropertyList(class, &outCount);
    BOOL  isExist = NO;
    for (i = 0; i < outCount; i++) {
        objc_property_t  property =properties[i];
        NSString *tempPropertyName = [[NSString alloc] initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        if ([tempPropertyName isEqualToString:propertyName]) {
            isExist = YES;
        }
    }
    free(properties);
    return isExist;
}

@end

#endif
