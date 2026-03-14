---
name: document-ar-docx
description: 使用 docx 或 mammoth.js 等库程序化处理、解析、创建和操作 Microsoft Word (.docx) 文档。当用户需要生成 Word 文档、提取文档内容、模板填充、创建报告、解析简历、Word 转 HTML 时使用此 skill。
---

# 文档处理 - DOCX

程序化处理 Microsoft Word (.docx) 文档。

## 常用库

| 库 | 用途 | 安装 |
|---|---|---|
| `docx` | 创建/编辑 Word 文档 | `npm install docx` |
| `mammoth` | DOCX 转 HTML | `npm install mammoth` |
| `docxtemplater` | 模板引擎 | `npm install docxtemplater` |

## 创建 Word 文档

```typescript
import { Document, Packer, Paragraph, TextRun, HeadingLevel, Table, TableCell } from 'docx';
import * as fs from 'fs';

const doc = new Document({
  sections: [{
    children: [
      new Paragraph({ text: "项目报告", heading: HeadingLevel.HEADING_1 }),
      new Paragraph({
        children: [
          new TextRun("这是自动生成的报告。"),
          new TextRun({ text: "重要内容", bold: true, color: "FF0000" }),
        ],
      }),
      new Table({
        rows: [
          { children: [new TableCell({ children: [new Paragraph("姓名")] }), new TableCell({ children: [new Paragraph("年龄")] })] },
          { children: [new TableCell({ children: [new Paragraph("张三")] }), new TableCell({ children: [new Paragraph("25")] })] },
        ],
      }),
    ],
  }],
});

Packer.toBuffer(doc).then(buffer => fs.writeFileSync("report.docx", buffer));
```

## 读取 Word 文档

```typescript
import mammoth from 'mammoth';
import * as fs from 'fs';

// 提取文本
async function extractText(filePath: string): Promise<string> {
  const buffer = fs.readFileSync(filePath);
  const result = await mammoth.extractRawText({ buffer });
  return result.value;
}

// 转换为 HTML
async function toHtml(filePath: string): Promise<string> {
  const buffer = fs.readFileSync(filePath);
  const result = await mammoth.convertToHtml({ buffer });
  return result.value;
}
```

## 模板填充

```typescript
import PizZip from 'pizzip';
import Docxtemplater from 'docxtemplater';
import * as fs from 'fs';

function fillTemplate(templatePath: string, data: object, outputPath: string) {
  const content = fs.readFileSync(templatePath, 'binary');
  const zip = new PizZip(content);
  const doc = new Docxtemplater(zip, { paragraphLoop: true, linebreaks: true });
  doc.render(data);
  const buffer = doc.getZip().generate({ type: 'nodebuffer' });
  fs.writeFileSync(outputPath, buffer);
}

fillTemplate('template.docx', {
  name: '张三',
  date: '2026-03-14',
  items: [{ name: '项目A', status: '完成' }, { name: '项目B', status: '进行中' }],
}, 'output.docx');
```

## 常见场景

### 生成发票

```typescript
function createInvoice(invoice: InvoiceData): Document {
  return new Document({
    sections: [{
      children: [
        new Paragraph({ text: `发票编号: ${invoice.id}`, heading: HeadingLevel.HEADING_1 }),
        new Paragraph(`客户: ${invoice.customerName}`),
        new Paragraph(`总计: ¥${invoice.total.toFixed(2)}`),
      ],
    }],
  });
}
```

### 解析简历

```typescript
async function parseResume(filePath: string): Promise<ResumeData> {
  const text = await extractText(filePath);
  return {
    rawText: text,
    email: text.match(/[\w.-]+@[\w.-]+\.\w+/)?.[0],
    phone: text.match(/1[3-9]\d{9}/)?.[0],
  };
}
```