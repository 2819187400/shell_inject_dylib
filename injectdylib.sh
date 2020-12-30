# !/bin/bash
# initnil 2020/12/30 make.
# 使用方法，cd到脚本文件夹 ./inject.sh dylib文件路径  ipa文件路径
# 可依次往终端拖入：本脚本，dylib，ipa，回车即可
# 注意，需要安装Xcode，不然无法修改依赖

#工程变量创建
shell_path="$(dirname "$0")"
DYLIB="$1"
IPA="$2"
LIBSUBSTRATE="${shell_path}/libsubstrate.dylib"

temp="${shell_path}/inject-temp"
dylib="${temp}/${DYLIB##*/}"
ipa="${temp}/${IPA##*/}"
libsubstrate="${temp}/${LIBSUBSTRATE##*/}"
#工程变量结束

#创建临时工程目录
rm -rf ${shell_path}/extracted
rm -rf ${shell_path}/Payload
rm -rf ${shell_path}/injected.ipa
rm -rf ${temp}
mkdir ${shell_path}/Payload/
mkdir ${temp}

echo "开始注入dylib"
#复制本次工程的文件至临时工程目录，并解压
cp "$DYLIB" "$IPA" "$LIBSUBSTRATE" ${temp}
unzip -qo "$ipa" -d ${shell_path}/extracted
APPLICATION=$(ls "${shell_path}/extracted/Payload/")
app="${shell_path}/extracted/Payload/${APPLICATION}"

#删除无法签名的组件
rm -rf ${app}/*watch* ${app}/*Watch*
rm -rf ${app}/*plugIns* ${app}/*PlugIns*
rm -rf ${app}/*com.apple.WatchPlaceholder*

#检查是否依赖libsubstrate，如果依赖就替换，并且把libsubstrate.dylib拷贝进去
otool -L ${dylib} > ${temp}/otool.log
grep "/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate" ${temp}/otool.log >${temp}/grep_result.log
if [ $? -eq 0 ]; then
    echo "发现 ${DYLIB##*/} 依赖 CydiaSubstrate"
    cp ${libsubstrate} ${app}/
    install_name_tool -change /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate @executable_path/libsubstrate.dylib ${dylib}
else
    echo "没有发现 ${DYLIB##*/} 依赖 CydiaSubstrate"
fi

#注入的dylib拷贝进去
cp ${dylib} ${app}/

#注入dylib到主二进制文件
${shell_path}/insert_dylib @executable_path/${DYLIB##*/} ${app}/${APPLICATION%.*} --all-yes

#注入完成的二进制文件替换原始文件
mv ${app}/${APPLICATION%.*}_patched ${app}/${APPLICATION%.*}
cp -R ${app} ${shell_path}/Payload/
cd ${shell_path}

#打包IPA
zip -qr injected.ipa Payload/

#删除注入缓存工程
rm -rf ${shell_path}/extracted
rm -rf ${shell_path}/Payload
rm -rf ${temp}

echo "注入dylib完成"

#打开生成IPA目录
open ${shell_path}/
