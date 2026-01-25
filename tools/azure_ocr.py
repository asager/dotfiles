#!/usr/bin/env python3
"""Azure AI Document Intelligence OCR Script

For extracting text from PDFs to markdown.

Usage:
  azure_ocr <pdf_file_or_dir> [options]

Environment variables required:
  AZURE_DOC_INTELLIGENCE_ENDPOINT
  AZURE_DOC_INTELLIGENCE_KEY
"""

import json
import os
import sys
from pathlib import Path

from azure.ai.documentintelligence import DocumentIntelligenceClient
from azure.ai.documentintelligence.models import AnalyzeResult
from azure.core.credentials import AzureKeyCredential


def get_credentials():
    """Get Azure credentials from environment variables."""
    endpoint = os.environ.get("AZURE_DOC_INTELLIGENCE_ENDPOINT")
    key = os.environ.get("AZURE_DOC_INTELLIGENCE_KEY")

    if not endpoint or not key:
        print("Error: Azure credentials not found.")
        print("\nPlease set the following environment variables:")
        print(
            "  export AZURE_DOC_INTELLIGENCE_ENDPOINT='https://your-resource.cognitiveservices.azure.com/'"
        )
        print("  export AZURE_DOC_INTELLIGENCE_KEY='your-api-key'")
        print("\nTo get these credentials:")
        print("  1. Go to https://portal.azure.com")
        print(
            "  2. Create a 'Document Intelligence' resource (or 'Azure AI services' multi-service)"
        )
        print("  3. Go to 'Keys and Endpoint' in the resource")
        print("  4. Copy KEY 1 and Endpoint")
        sys.exit(1)

    return endpoint, key


def analyze_document(pdf_path: str, output_format: str = "markdown") -> str:
    """Analyze a PDF document using Azure AI Document Intelligence."""
    endpoint, key = get_credentials()

    client = DocumentIntelligenceClient(endpoint=endpoint, credential=AzureKeyCredential(key))

    pdf_file = Path(pdf_path)
    if not pdf_file.exists():
        raise FileNotFoundError(f"PDF file not found: {pdf_file}")

    print(f"Analyzing: {pdf_file.name}")
    print("Uploading to Azure AI Document Intelligence...")

    with open(pdf_file, "rb") as f:
        poller = client.begin_analyze_document(
            model_id="prebuilt-read",
            body=f,
            content_type="application/pdf",
            output_content_format="markdown" if output_format == "markdown" else "text",
        )

    print("Processing... (this may take a minute)")
    result: AnalyzeResult = poller.result()

    print(f"Analysis complete. Pages: {len(result.pages)}")
    return result.content


def analyze_document_with_layout(pdf_path: str) -> dict:
    """Analyze a PDF with full layout extraction (tables, structure, etc.)."""
    endpoint, key = get_credentials()

    client = DocumentIntelligenceClient(endpoint=endpoint, credential=AzureKeyCredential(key))

    pdf_file = Path(pdf_path)
    if not pdf_file.exists():
        raise FileNotFoundError(f"PDF file not found: {pdf_file}")

    print(f"Analyzing with layout model: {pdf_file.name}")

    with open(pdf_file, "rb") as f:
        poller = client.begin_analyze_document(
            model_id="prebuilt-layout",
            body=f,
            content_type="application/pdf",
            output_content_format="markdown",
        )

    print("Processing with layout analysis...")
    result: AnalyzeResult = poller.result()

    output = {"content": result.content, "pages": [], "tables": [], "paragraphs": []}

    for page in result.pages:
        page_info = {
            "page_number": page.page_number,
            "width": page.width,
            "height": page.height,
            "lines": [],
        }
        if page.lines:
            for line in page.lines:
                page_info["lines"].append(line.content)
        output["pages"].append(page_info)

    if result.tables:
        for table in result.tables:
            table_data = {
                "row_count": table.row_count,
                "column_count": table.column_count,
                "cells": [],
            }
            for cell in table.cells:
                table_data["cells"].append(
                    {
                        "row": cell.row_index,
                        "col": cell.column_index,
                        "content": cell.content,
                    }
                )
            output["tables"].append(table_data)

    if result.paragraphs:
        for para in result.paragraphs:
            output["paragraphs"].append(para.content)

    return output


def process_batch(input_dir: str, output_dir: str | None = None):
    """Process all PDFs in a directory."""
    endpoint, key = get_credentials()

    client = DocumentIntelligenceClient(endpoint=endpoint, credential=AzureKeyCredential(key))

    input_path = Path(input_dir)
    pdfs = list(input_path.rglob("*.pdf"))

    if not pdfs:
        print(f"No PDF files found in {input_dir}")
        return

    print(f"Found {len(pdfs)} PDF files to process:")
    for pdf in pdfs:
        print(f"  - {pdf}")

    if output_dir:
        out_path = Path(output_dir)
    else:
        out_path = Path(str(input_path) + "_markdown")

    out_path.mkdir(exist_ok=True)

    for pdf_path in pdfs:
        try:
            print(f"\nProcessing: {pdf_path.name}")
            print("  Uploading...")

            with open(pdf_path, "rb") as f:
                poller = client.begin_analyze_document(
                    model_id="prebuilt-read",
                    body=f,
                    content_type="application/pdf",
                    output_content_format="markdown",
                )

            print("  Processing...")
            result: AnalyzeResult = poller.result()
            print(f"  Complete. Pages: {len(result.pages)}")

            relative_path = pdf_path.relative_to(input_path)
            output_file = out_path / relative_path.with_suffix(".md")
            output_file.parent.mkdir(parents=True, exist_ok=True)

            with open(output_file, "w") as f:
                f.write(result.content)

            print(f"  Saved to: {output_file}")

        except Exception as e:
            print(f"  Error: {e}")

    print(f"\nDone! Markdown files saved to: {out_path}/")


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage: azure_ocr <pdf_file_or_dir> [options]")
        print("\nOptions:")
        print("  --layout       Use layout model for better table/structure extraction")
        print("  --output FILE  Write output to specified file (single file mode)")
        print("  --batch        Process all PDFs in directory recursively")
        print("  --outdir DIR   Output directory for batch mode")
        print("\nExamples:")
        print("  azure_ocr document.pdf")
        print("  azure_ocr document.pdf --layout --output result.md")
        print("  azure_ocr ./pdfs/ --batch --outdir ./markdown/")
        print("\nEnvironment variables required:")
        print("  AZURE_DOC_INTELLIGENCE_ENDPOINT")
        print("  AZURE_DOC_INTELLIGENCE_KEY")
        sys.exit(1)

    input_path = sys.argv[1]
    use_layout = "--layout" in sys.argv
    batch_mode = "--batch" in sys.argv

    output_file = None
    if "--output" in sys.argv:
        idx = sys.argv.index("--output")
        if idx + 1 < len(sys.argv):
            output_file = sys.argv[idx + 1]

    output_dir = None
    if "--outdir" in sys.argv:
        idx = sys.argv.index("--outdir")
        if idx + 1 < len(sys.argv):
            output_dir = sys.argv[idx + 1]

    try:
        if batch_mode or Path(input_path).is_dir():
            process_batch(input_path, output_dir)
        elif use_layout:
            result = analyze_document_with_layout(input_path)
            content = result["content"]

            if output_file:
                json_file = Path(output_file).with_suffix(".json")
                with open(json_file, "w") as f:
                    json.dump(result, f, indent=2)
                print(f"Structured data saved to: {json_file}")
                with open(output_file, "w") as f:
                    f.write(content)
                print(f"Content saved to: {output_file}")
            else:
                print("\n" + "=" * 80)
                print(content)
        else:
            content = analyze_document(input_path, output_format="markdown")

            if output_file:
                with open(output_file, "w") as f:
                    f.write(content)
                print(f"Content saved to: {output_file}")
            else:
                print("\n" + "=" * 80)
                print(content)

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
