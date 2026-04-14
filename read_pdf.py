import PyPDF2

pdf_path = r'd:\王元元老师大创\AI智能环保小卫士软件—米洋成\AI智能环保小卫士软件软著申请\AI智能环保小卫士（V1.0）软件使用说明书.pdf'

with open(pdf_path, 'rb') as pdf_file:
    reader = PyPDF2.PdfReader(pdf_file)
    text = ''
    for page in reader.pages:
        text += page.extract_text() + '\n'
    print(text)
