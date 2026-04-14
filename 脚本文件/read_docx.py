
import sys
from docx import Document

if len(sys.argv) != 2:
    print("Usage: python read_docx.py <docx_file_path>")
    sys.exit(1)

docx_path = sys.argv[1]
doc = Document(docx_path)
for para in doc.paragraphs:
    print(para.text)
