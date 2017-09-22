# STCObfuscator
```
STCObfuscator is an Objective-C obfuscator for Mach-O executables, 
a runtime utility for obfuscating Objective-C class,it also support cocoapod file confusing!
```
```
STCObfuscator 是用来进行代码混淆的工具，在模拟器环境下运行生成混淆宏，
混淆后的宏可以在其他环境下进行编译，支持Cocoapod代码混淆.
```

## How to use it!
```
You can use STCObfuscator with cocoapod!
pod "STCObfuscator"
```
```
after you add under code to your project

#if (DEBUG == 1)
    [STCObfuscator obfuscatorManager].unConfuseClassNames = @[@"UnConfusedClass"];
    [[STCObfuscator obfuscatorManager] confuseWithRootPath:[NSString stringWithFormat:@"%s", STRING(ROOT_PATH)] resultFilePath:[NSString stringWithFormat:@"%@/STCDefination.h", [NSString stringWithFormat:@"%s", STRING(ROOT_PATH)]] linkmapPath:[NSString stringWithFormat:@"%s", STRING(LINKMAP_FILE)]];
#endif

you should finish steps:
```
```
在你把下面的代码加入到你的工程之后，你要完成下面的步骤
#if (DEBUG == 1)
    [STCObfuscator obfuscatorManager].unConfuseClassNames = @[@"UnConfusedClass"];
    [[STCObfuscator obfuscatorManager] confuseWithRootPath:[NSString stringWithFormat:@"%s", STRING(ROOT_PATH)] resultFilePath:[NSString stringWithFormat:@"%@/STCDefination.h", [NSString stringWithFormat:@"%s", STRING(ROOT_PATH)]] linkmapPath:[NSString stringWithFormat:@"%s", STRING(LINKMAP_FILE)]];
#endif
```

#### 1、
```
add 
LINKMAP_FILE=$(TARGET_TEMP_DIR)/$(PRODUCT_NAME)-LinkMap-$(CURRENT_VARIANT)-$(CURRENT_ARCH).txt 
and 
ROOT_PATH="${SRCROOT}" 
to Build Settings Preprocessor Macros 
```
```
在 Build Settings-Preprocessor Macros-DEBUG 中添加环境变量
LINKMAP_FILE=$(TARGET_TEMP_DIR)/$(PRODUCT_NAME)-LinkMap-$(CURRENT_VARIANT)-$(CURRENT_ARCH).txt 
和
ROOT_PATH="${SRCROOT}" 
```

#### 2、
```
enable Write Link Map File in Build Settings, set YES
```
```
在 Build Settings 开启Write Link Map File, 设置成 YES
```

#### 3、
```
add shell script to Build Phases
```
```
将下面的脚本添加到 Build Phases
```
```
dir=${SRCROOT}
file_count=0
file_list=`ls -R $dir 2> /dev/null | grep -v '^$'`
for file_name in $file_list
do
temp=`echo $file_name | sed 's/:.*$//g'`
if [ "$file_name" != "$temp" ]; then
cur_dir=$temp
else
if [ ${file_name##*.} = a ]; then
    find -P $dir -name $file_name > tmp.txt
    var=$(cat tmp.txt)
    nm $var > ${file_name}.txt
    rm tmp.txt
fi
fi
done
```

#### 4、
```
import STCDefination.h to PrefixHeader File like this:
#if (DEBUG != 1)
#import "STCDefination.h"
#endif
```
```
在预编译文件中添加以下
#if (DEBUG != 1)
#import "STCDefination.h"
#endif
```

#### 5、
```
clean content in STCDefination.h 
```
```
清空STCDefination.h里面的内容
```

#### 6、
```
run project in DEBUG environment with iPhone simulator to generate confuse macros in STCDefination.h 
```
```
在DEBUG环境下用模拟器运行工程，在STCDefination.h头文件中生成混淆的宏。
```

#### 7、
```
run project in REALEASE environment that class confused. 
```
```
在 REALEASE 环境下运行工程，实现代码混淆。 
```

#### 8、
```
all confused symbols will save to confuse.json in project catalog. 
```
```
所有的混淆符号会保留在工程目录下的confuse.json。 
```

#### 9、
```
if you use cocoapod in jenkins you should run under shell script after pod update 
```
```
如果你使用了cocoapod,而且通过自动化打包工具如jenkins进行打包，那么你在执行完pod update脚本后，请执行下面脚本。
```
```
dir=${SRCROOT}/Pods
headerFile=${SRCROOT}/STCDefination.h 
file_count=0
file_list=`ls -R $dir 2> /dev/null | grep -v '^$'`
for file_name in $file_list
do
temp=`echo $file_name | sed 's/:.*$//g'`
if [ "$file_name" != "$temp" ]; then
cur_dir=$temp
else
if [ ${file_name##*.} = pch ]; then
    echo $file_name
    find -P $dir -name $file_name > tmp1.txt
    var1=$(cat tmp1.txt)
    echo $var1
    var2=$(cat $headerFile)
    echo "" > $var1
    echo "Pipe"
    echo "$var2" | while read line
    do
    echo "$line" >> $var1
    done
    rm tmp1.txt
    fi
    let file_count++
    fi
done
```
