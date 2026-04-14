import os
import markdown
from xhtml2pdf import pisa

# 输入目录和输出目录
input_dir = "d:\\王元元老师大创\\APP开发\\软著申请材料"
output_dir = "d:\\王元元老师大创\\王元元老师（王诗涵）—软著申请单"

# 确保输出目录存在
os.makedirs(output_dir, exist_ok=True)

# 需要转换的文件列表
files_to_convert = [
    "软著申请表.md",
    "用户使用说明书.md",
    "代码统计报告.md",
    "源代码清单.md",
    "设计说明书.md"
]

# 转换每个文件
for file_name in files_to_convert:
    input_path = os.path.join(input_dir, file_name)
    output_path = os.path.join(output_dir, file_name.replace(".md", ".pdf"))
    
    if os.path.exists(input_path):
        print(f"转换文件: {file_name}")
        
        # 读取Markdown文件
        with open(input_path, 'r', encoding='utf-8') as f:
            md_content = f.read()
        
        # 转换为HTML
        html_content = markdown.markdown(md_content, extensions=['tables'])
        
        # 添加基本样式
        styled_html = '''
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body {
                    font-family: SimSun, serif;
                    line-height: 1.6;
                    margin: 20px;
                }
                h1, h2, h3, h4, h5, h6 {
                    color: #333;
                    margin-top: 20px;
                    margin-bottom: 10px;
                }
                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 20px 0;
                }
                th, td {
                    border: 1px solid #ddd;
                    padding: 8px;
                    text-align: left;
                }
                th {
                    background-color: #f2f2f2;
                }
                code {
                    font-family: Consolas, Monaco, monospace;
                    background-color: #f4f4f4;
                    padding: 2px 4px;
                    border-radius: 3px;
                }
                pre {
                    background-color: #f4f4f4;
                    padding: 10px;
                    border-radius: 3px;
                    overflow-x: auto;
                }
                img {
                    max-width: 100%;
                    height: auto;
                }
            </style>
        </head>
        <body>
        ''' + html_content + '''
        </body>
        </html>
        '''
        
        # 转换为PDF
        with open(output_path, 'wb') as f:
            pisa_status = pisa.CreatePDF(
                styled_html,
                dest=f
            )
        
        if pisa_status.err:
            print(f"转换失败: {pisa_status.err}")
        else:
            print(f"已保存为: {output_path}")
    else:
        print(f"文件不存在: {input_path}")

print("转换完成！")
