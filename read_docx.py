from docx import Document

docx_path = r'd:\王元元老师大创\王元元老师（王诗涵）—软著申请单\软著申请表.docx'

doc = Document(docx_path)
text = ''
for para in doc.paragraphs:
    text += para.text + '\n'
print(text)