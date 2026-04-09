import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/// 渲染 Markdown + LaTeX 的通用组件。
/// 支持行内公式 $...$ 和块级公式 \[...\] 或 $$...$$
class MarkdownLatexView extends StatelessWidget {
  final String data;
  final TextStyle? textStyle;
  final Color? codeBackgroundColor;

  const MarkdownLatexView({
    super.key,
    required this.data,
    this.textStyle,
    this.codeBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = textStyle ?? DefaultTextStyle.of(context).style;
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: baseStyle.copyWith(height: 1.6),
        code: baseStyle.copyWith(
          fontFamily: 'monospace',
          fontSize: (baseStyle.fontSize ?? 14) * 0.9,
          backgroundColor: codeBackgroundColor ?? Colors.black12,
        ),
        codeblockDecoration: BoxDecoration(
          color: codeBackgroundColor ?? Colors.black12,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      builders: {'latex': _LatexElementBuilder()},
      inlineSyntaxes: [_InlineLatexSyntax()],
      blockSyntaxes: [_BlockLatexSyntax()],
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );
  }
}

// ── LaTeX 行内语法：$...$ 和 \(...\) ─────────────────────────────────────
class _InlineLatexSyntax extends md.InlineSyntax {
  // 匹配 $...$ (非空，不跨行) 或 \(...\)
  _InlineLatexSyntax() : super(r'\$([^\$\n]+?)\$|\\\((.+?)\\\)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final formula = match[1] ?? match[2] ?? '';
    final el = md.Element.text('latex', formula);
    el.attributes['display'] = 'inline';
    parser.addNode(el);
    return true;
  }
}

// ── LaTeX 块级语法：\[...\]、$$...$$ 和 \begin{...}...\end{...} ──────────
class _BlockLatexSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\s*(\\\[|\$\$|\\begin\{)');

  @override
  md.Node? parse(md.BlockParser parser) {
    final startLine = parser.current.content.trimLeft();
    final String endPattern;
    if (startLine.startsWith(r'$$')) {
      endPattern = r'$$';
    } else if (startLine.startsWith(r'\[')) {
      endPattern = r'\]';
    } else {
      // \begin{...} 找对应 \end{...}
      final envMatch = RegExp(r'\\begin\{(\w+)\}').firstMatch(startLine);
      endPattern = envMatch != null ? '\\end{${envMatch.group(1)}}' : r'\end';
    }
    parser.advance();

    final buffer = StringBuffer();
    while (!parser.isDone) {
      final line = parser.current.content;
      if (line.contains(endPattern)) { parser.advance(); break; }
      buffer.writeln(line);
      parser.advance();
    }

    final el = md.Element('latex', [md.Text(buffer.toString().trim())]);
    el.attributes['display'] = 'block';
    return el;
  }
}

// ── LaTeX 渲染 Builder ────────────────────────────────────────────────────
class _LatexElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final formula = element.textContent;
    final isBlock = element.attributes['display'] == 'block';

    final math = Math.tex(
      formula,
      textStyle: preferredStyle,
      onErrorFallback: (err) => SelectableText(
        '[$formula]',
        style: preferredStyle?.copyWith(color: Colors.orange),
      ),
    );

    if (isBlock) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: math),
      );
    }
    return math;
  }
}
