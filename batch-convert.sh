#!/bin/bash

# 创建 pdfs 文件夹（如果不存在）
mkdir -p pdfs

# 遍历 cajs 目录下所有 .caj 文件
for caj_file in cajs/*.caj; do
    # 跳过目录（防止没有.caj文件时匹配到cajs/*.caj字符串）
    [ -f "$caj_file" ] || continue
    
    # 提取 CAJ 文件名（仅文件名，不含路径）
    filename=$(basename "$caj_file")
    # 生成 pdfs 文件夹下的 PDF 路径（保留原文件名，替换后缀）
    pdf_file="pdfs/${filename%.caj}.pdf"
    
    # 执行转换命令（输出到 pdfs 文件夹）
    ./caj2pdf convert "$caj_file" -o "$pdf_file"
done

echo "批量转换完成！PDF 文件已保存到 ./pdfs 文件夹"
