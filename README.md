# STCObfuscator

```
STCObfuscator 是用来进行object-c代码混淆的工具，在模拟器DEBUG环境下运行生成混淆宏，
混淆的宏可以在其他环境下进行编译，支持Cocoapod代码混淆.
```

## 怎么使用!

相关博客：https://blog.csdn.net/cating1314/article/details/80189295

```
如果你的工程支持cocoapod,你可以直接添加！
pod "STCObfuscator"(注：请用最新版本，最好更新下master repo)

把下面的代码加入到Appdelegate didFinishLaunchingWithOptions方法里，

#import "STCObfuscator.h"

#if (DEBUG == 1)
    [[STCObfuscator obfuscatorManager] confuseWithRootPath:[NSString stringWithFormat:@"%s", STRING(ROOT_PATH)] resultFilePath:[NSString stringWithFormat:@"%@/STCDefination.h", [NSString stringWithFormat:@"%s", STRING(ROOT_PATH)]] linkmapPath:[NSString stringWithFormat:@"%s", STRING(LINKMAP_FILE)]];
#endif

然后完成下面步骤的设置
```
![image](https://github.com/chenxiancai/STCObfuscator/raw/master/Snip20180510_18.png)


#### 步骤1、
```
在 Build Settings->Preprocessor Macros->DEBUG 中添加环境变量
LINKMAP_FILE=$(TARGET_TEMP_DIR)/$(PRODUCT_NAME)-LinkMap-$(CURRENT_VARIANT)-$(CURRENT_ARCH).txt 
和
ROOT_PATH="${SRCROOT}" 
（注：工程尽量不要放在中文路径下）
```
![image](https://github.com/chenxiancai/STCObfuscator/raw/master/Snip20180510_17.png)

#### 步骤2、
```
在 Build Settings 开启Write Link Map File, 设置成 YES
```
![image](https://github.com/chenxiancai/STCObfuscator/raw/master/Snip20180510_16.png)


#### 步骤3、
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
if [ ${file_name##*.} = framework ]; then
    find -P $dir -name ${file_name%%.*} > tmp.txt
    var=$(cat tmp.txt)
    nm $var > ${file_name}.txt
    rm tmp.txt
    fi
fi
done
```
![image](https://github.com/chenxiancai/STCObfuscator/raw/master/Snip20180510_15.png)


#### 步骤4、
```
在预编译文件最前面中添加以下代码
#if (DEBUG != 1)
#import "STCDefination.h"
#endif
```
![image](https://github.com/chenxiancai/STCObfuscator/raw/master/Snip20180510_19.png)


#### 步骤5、
```
在DEBUG环境下用模拟器运行工程，在STCDefination.h头文件中生成混淆的宏。
所有的混淆符号会保留在工程目录下的confuse.json。 
```
![image](https://github.com/chenxiancai/STCObfuscator/raw/master/Snip20180510_20.png)
```
可用于bug上报后反混淆的文件
```
![image](https://github.com/chenxiancai/STCObfuscator/raw/master/Snip20180510_26.png)


#### 步骤6、
```
把工程目录下STCDefination.h头文件加入工程。
混淆后，如果工程增加代码，需要再次混淆，先清空STCDefination.h里面的内容，不能留任何空格和换行，然后pod update，再次在模拟器DEBUG环境下运行。
```
![image](https://github.com/chenxiancai/STCObfuscator/raw/master/Snip20180510_21.png)




#### 步骤7、
```
在 RELEASE 环境下运行工程，实现代码混淆。 
```
```
混淆前逆向。 
```
![image](https://github.com/chenxiancai/STCObfuscator/raw/master/Snip20180510_25.png)
```
混淆后逆向。 
```
![image](https://github.com/chenxiancai/STCObfuscator/raw/master/Snip20180510_24.png)




# English steps ⬇︎


```
STCObfuscator is an Objective-C obfuscator for Mach-O executables, 
a runtime utility for obfuscating Objective-C class,it also support cocoapod file confusing!
```

## How to use it!
```
You can use STCObfuscator with cocoapod!
pod "STCObfuscator"
```

```
after you add under code to your project

#import "STCObfuscator.h"

#define STRING(str) _STRING(str)
#define _STRING(str) #str

#if (DEBUG == 1)
    [[STCObfuscator obfuscatorManager] confuseWithRootPath:[NSString stringWithFormat:@"%s", STRING(ROOT_PATH)] resultFilePath:[NSString stringWithFormat:@"%@/STCDefination.h", [NSString stringWithFormat:@"%s", STRING(ROOT_PATH)]] linkmapPath:[NSString stringWithFormat:@"%s", STRING(LINKMAP_FILE)]];
#endif

you should finish steps:
```

#### step 1、
```
add 
LINKMAP_FILE=$(TARGET_TEMP_DIR)/$(PRODUCT_NAME)-LinkMap-$(CURRENT_VARIANT)-$(CURRENT_ARCH).txt 
and 
ROOT_PATH="${SRCROOT}" 
to Build Settings Preprocessor Macros 
```

#### step 2、
```
enable Write Link Map File in Build Settings, set YES
```

#### step 3、
```
add shell script to Build Phases
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

#### step 4、
```
import STCDefination.h to PrefixHeader File like this:
#if (DEBUG != 1)
#import "STCDefination.h"
#endif
```

#### step 5、
```
run project in DEBUG environment with iPhone simulator to generate confuse macros in STCDefination.h.
all confused symbols will save to confuse.json in project catalog. 
```

#### step 6、
```
add STCDefination.h.
```

#### step 7、
```
run project in RELEASE environment that class confused. 
```

