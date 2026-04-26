import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/// 渲染 Markdown + LaTeX 的通用组件。
/// 支持行内公式 $...$ / \(...\) 和块级公式 $$...$$、\[...\]、\begin{...}
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // 基础字体：优先用传入的，否则用主题 bodyMedium，颜色强制 onSurface
    final base = (textStyle ?? theme.textTheme.bodyMedium ?? const TextStyle())
        .copyWith(color: cs.onSurface);

    final codeBg = codeBackgroundColor ?? cs.surfaceContainerHighest;

    return MarkdownBody(
      data: data,
      selectable: false,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        // 正文
        p: base.copyWith(height: 1.7),
        // 标题
        h1: base.copyWith(fontSize: 22, fontWeight: FontWeight.bold, height: 1.4),
        h2: base.copyWith(fontSize: 19, fontWeight: FontWeight.bold, height: 1.4),
        h3: base.copyWith(fontSize: 17, fontWeight: FontWeight.w600, height: 1.4),
        h4: base.copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
        h5: base.copyWith(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
        h6: base.copyWith(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
        // 行内代码
        code: base.copyWith(
          fontFamily: 'monospace',
          fontSize: (base.fontSize ?? 14) * 0.9,
          backgroundColor: codeBg,
          color: cs.onSurface,
        ),
        // 代码块
        codeblockDecoration: BoxDecoration(
          color: codeBg,
          borderRadius: BorderRadius.circular(6),
        ),
        codeblockPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        // 列表
        listBullet: base.copyWith(height: 1.7),
        // 引用块
        blockquote: base.copyWith(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: cs.outlineVariant, width: 3)),
          color: cs.surfaceContainerLow,
        ),
        blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        // 分隔线
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: cs.outlineVariant, width: 1)),
        ),
      ),
      builders: {'latex': _LatexElementBuilder(baseStyle: base)},
      inlineSyntaxes: [_InlineLatexSyntax()],
      blockSyntaxes: [_BlockLatexSyntax()],
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );
  }
}

// ── LaTeX 行内语法：$...$ 和 \(...\) ─────────────────────────────────────────
class _InlineLatexSyntax extends md.InlineSyntax {
  _InlineLatexSyntax()
      : super(r'\$([^\$\n]+?)\$|\\\((.+?)\\\)', caseSensitive: true);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final formula = (match[1] ?? match[2] ?? '').trim();
    if (formula.isEmpty) return false;
    final el = md.Element.text('latex', formula);
    el.attributes['display'] = 'inline';
    parser.addNode(el);
    return true;
  }
}

// ── LaTeX 块级语法：$$...$$、\[...\]、\begin{...}...\end{...} ────────────────
class _BlockLatexSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\s*(\$\$|\\\[|\\begin\{)');

  @override
  md.Node? parse(md.BlockParser parser) {
    final startLine = parser.current.content.trimLeft();
    final String endPattern;
    final StringBuffer buffer = StringBuffer();

    if (startLine.startsWith(r'$$')) {
      endPattern = r'$$';
      final rest = startLine.substring(2).trimLeft();
      // 单行 $$...$$ 处理
      if (rest.contains(r'$$')) {
        final formula = rest.substring(0, rest.indexOf(r'$$')).trim();
        parser.advance();
        final el = md.Element('latex', [md.Text(formula)]);
        el.attributes['display'] = 'block';
        return el;
      }
      buffer.write(rest);
    } else if (startLine.startsWith(r'\[')) {
      endPattern = r'\]';
      final rest = startLine.substring(2).trimLeft();
      // 单行 \[...\] 处理
      if (rest.contains(r'\]')) {
        final formula = rest.substring(0, rest.indexOf(r'\]')).trim();
        parser.advance();
        final el = md.Element('latex', [md.Text(formula)]);
        el.attributes['display'] = 'block';
        return el;
      }
      buffer.write(rest);
    } else {
      final envMatch = RegExp(r'\\begin\{(\w+\*?)\}').firstMatch(startLine);
      endPattern = envMatch != null ? '\\end{${envMatch.group(1)}}' : r'\end';
      buffer.write(startLine);
    }
    parser.advance();

    while (!parser.isDone) {
      final line = parser.current.content;
      if (line.contains(endPattern)) {
        final idx = line.indexOf(endPattern);
        if (idx > 0) buffer.writeln(line.substring(0, idx));
        parser.advance();
        break;
      }
      buffer.writeln(line);
      parser.advance();
    }

    final formula = buffer.toString().trim();
    if (formula.isEmpty) return null;
    final el = md.Element('latex', [md.Text(formula)]);
    el.attributes['display'] = 'block';
    return el;
  }
}

// ── LaTeX 渲染 Builder ────────────────────────────────────────────────────────
class _LatexElementBuilder extends MarkdownElementBuilder {
  final TextStyle baseStyle;
  _LatexElementBuilder({required this.baseStyle});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final formula = element.textContent.trim();
    if (formula.isEmpty) return const SizedBox.shrink();

    final isBlock = element.attributes['display'] == 'block';
    final fontSize = isBlock
        ? (baseStyle.fontSize ?? 15) * 1.1
        : (baseStyle.fontSize ?? 15);

    final mathStyle = baseStyle.copyWith(fontSize: fontSize);

    final math = Math.tex(
      formula,
      textStyle: mathStyle,
      mathStyle: isBlock ? MathStyle.display : MathStyle.text,
      onErrorFallback: (err) => Text(
        '[$formula]',
        style: mathStyle.copyWith(color: Colors.orange, fontFamily: 'monospace'),
      ),
    );

    if (isBlock) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: math,
          ),
        ),
      );
    }
    return math;
  }
}
