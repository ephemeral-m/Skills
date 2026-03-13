---
name: document-processing-docx
description: 使用 docx 或 mammoth.js 等库程序化处理、解析、创建和操作 Microsoft Word (.docx) 文档，实现文档生成和数据提取。当用户需要从模板生成 Word 文档、从 .docx 文件提取文本和格式、创建报告和发票、解析简历和表单、将 Word 转换为 HTML、创建邮件合并文档或自动化文档工作流时使用此 skill。
---

# 文档处理 - DOCX 文件

## 何时使用此 Skill

- 从模板生成 Word 文档
- 从 .docx 文件提取文本内容
- 创建自动化报告和发票
- 解析简历和职位申请
- 将 Word 文档转换为 HTML 或 Markdown
- 程序化创建邮件合并文档
- 从 Word 文件提取表格和数据
- 自动化文档生成工作流
- 从模板创建合同或协议
- 处理批量文档上传
- 从 Word 文档提取元数据
- 构建文档管理系统

---

## 常用库

| 库 | 用途 | 安装 |
|---|---|---|
| `docx` | 创建/编辑 Word 文档 | `npm install docx` |
| `mammoth` | DOCX 转 HTML | `npm install mammoth` |
| `pizzip` | 解压 DOCX（ZIP 格式） | `npm install pizzip` |
| `docxtemplater` | 模板引擎 | `npm install docxtemplater` |

---

## 示例：创建 Word 文档

```typescript
import { Document, Packer, Paragraph, TextRun, HeadingLevel, Table } from 'docx';
import * as fs from 'fs';

// 创建文档
const doc = new Document({
  sections: [{
    properties: {},
    children: [
      // 标题
      new Paragraph({
        text: "项目报告",
        heading: HeadingLevel.HEADING_1,
      }),

      // 正文段落
      new Paragraph({
        children: [
          new TextRun("这是一份自动生成的报告。"),
          new TextRun({
            text: "重要内容",
            bold: true,
            color: "FF0000",
          }),
        ],
      }),

      // 表格
      new Table({
        rows: [
          {
            children: [
              new TableCell({ children: [new Paragraph("姓名")] }),
              new TableCell({ children: [new Paragraph("年龄")] }),
            ],
          },
          {
            children: [
              new TableCell({ children: [new Paragraph("张三")] }),
              new TableCell({ children: [new Paragraph("25")] }),
            ],
          },
        ],
      }),
    ],
  }],
});

// 保存文档
Packer.toBuffer(doc).then(buffer => {
  fs.writeFileSync("report.docx", buffer);
});
```

---

## 示例：读取 Word 文档

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

// 使用示例
const text = await extractText('document.docx');
const html = await toHtml('document.docx');
```

---

## 示例：模板填充

```typescript
import PizZip from 'pizzip';
import Docxtemplater from 'docxtemplater';
import * as fs from 'fs';

function fillTemplate(templatePath: string, data: object, outputPath: string) {
  // 读取模板
  const content = fs.readFileSync(templatePath, 'binary');
  const zip = new PizZip(content);

  // 创建模板实例
  const doc = new Docxtemplater(zip, {
    paragraphLoop: true,
    linebreaks: true,
  });

  // 填充数据
  doc.render(data);

  // 保存文档
  const buffer = doc.getZip().generate({
    type: 'nodebuffer',
  });
  fs.writeFileSync(outputPath, buffer);
}

// 使用示例
fillTemplate('template.docx', {
  name: '张三',
  date: '2026-03-13',
  items: [
    { name: '项目A', status: '完成' },
    { name: '项目B', status: '进行中' },
  ],
}, 'output.docx');
```

---

## 常见场景

### 生成发票

```typescript
function createInvoice(invoice: InvoiceData): Document {
  return new Document({
    sections: [{
      children: [
        new Paragraph({
          text: `发票编号: ${invoice.id}`,
          heading: HeadingLevel.HEADING_1,
        }),
        new Paragraph(`客户: ${invoice.customerName}`),
        new Paragraph(`日期: ${invoice.date}`),
        // 商品明细表格
        createItemsTable(invoice.items),
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

  // 使用正则提取关键信息
  const email = text.match(/[\w.-]+@[\w.-]+\.\w+/)?.[0];
  const phone = text.match(/1[3-9]\d{9}/)?.[0];

  return {
    rawText: text,
    email,
    phone,
    // 可使用 NLP 提取更多信息
  };
}
```

---

## 参考资源

- [docx npm 包](https://www.npmjs.com/package/docx)
- [mammoth 文档](https://www.npmjs.com/package/mammoth)
- [docxtemplater 文档](https://docxtemplater.com/)
- [Office Open XML 标准](https://docs.microsoft.com/en-us/office/open-xml/open-xml-sdk)