import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_echarts/echarts_script.dart' show echartsScript;
import 'package:webview_flutter/webview_flutter.dart';




/// <!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=0" /><style type="text/css">body,html,#chart{height: 100%;width: 100%;margin: 0px;}div {-webkit-tap-highlight-color:rgba(255,255,255,0);}</style></head><body><div id="chart" /></body></html>
/// 'data:text/html;base64,' + base64Encode(const Utf8Encoder().convert( /* STRING ABOVE */ ))

const htmlBase64 =
    'PCFET0NUWVBFIGh0bWw+PGh0bWw+PGhlYWQ+PG1ldGEgY2hhcnNldD0idXRmLTgiPjxtZXRhIG5hbWU9InZpZXdwb3J0IiBjb250ZW50PSJ3aWR0aD1kZXZpY2Utd2lkdGgsIGluaXRpYWwtc2NhbGU9MS4wLCBtYXhpbXVtLXNjYWxlPTEuMCwgbWluaW11bS1zY2FsZT0xLjAsIHVzZXItc2NhbGFibGU9MCIgLz48c3R5bGUgdHlwZT0idGV4dC9jc3MiPmJvZHksaHRtbCwjY2hhcnR7aGVpZ2h0OiAxMDAlO3dpZHRoOiAxMDAlO21hcmdpbjogMHB4O31kaXYgey13ZWJraXQtdGFwLWhpZ2hsaWdodC1jb2xvcjpyZ2JhKDI1NSwyNTUsMjU1LDApO308L3N0eWxlPjwvaGVhZD48Ym9keT48ZGl2IGlkPSJjaGFydCIgLz48L2JvZHk+PC9odG1sPg==';

class Echarts extends StatefulWidget {
  const Echarts({
    required this.option,
    Key? key,
    this.extraScript = '',
    this.onMessage,
    this.extensions = const [],
    this.theme,
    this.captureAllGestures = false,
    this.captureHorizontalGestures = false,
    this.captureVerticalGestures = false,
    this.onLoad,
    this.onWebResourceError,
    this.reloadAfterInit = false,
    this.renderer = 'svg',
    this.loader,
  }) : super(key: key);

  final String option;

  final String extraScript;

  final void Function(String message)? onMessage;

  final List<String> extensions;

  final String? theme;

  final String renderer;

  final bool captureAllGestures;

  final bool captureHorizontalGestures;

  final bool captureVerticalGestures;

  final void Function(WebViewController)? onLoad;

  final void Function(WebViewController, Exception)? onWebResourceError;

  final bool reloadAfterInit;

  final Widget? loader;

  @override
  EchartsState createState() => EchartsState();
}

class EchartsState extends State<Echarts> {
  late final WebViewController _controller;
  String? _currentOption;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentOption = widget.option;

    _controller = WebViewController()
      ..setBackgroundColor(const Color(0x00000000))
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) async {
            await init();
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            if (widget.onWebResourceError != null) {
              widget.onWebResourceError?.call(_controller, Exception(error));
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'Messager',
        onMessageReceived: (JavaScriptMessage message) {
          if (widget.onMessage != null) {
            widget.onMessage?.call(message.message);
          }
        },
      )
      ..loadHtmlString(utf8.fuse(base64).decode(htmlBase64));

    if (widget.reloadAfterInit) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _controller.reload();
      });
    }
  }

  Future<void> init() async {
    final extensionsStr =
        widget.extensions.isNotEmpty ? widget.extensions.join('\n') : '';
    final themeStr = widget.theme != null ? "'${widget.theme}'" : 'null';
    await _controller.runJavaScript('''
      $echartsScript
      $extensionsStr
      var chart = echarts.init(document.getElementById('chart'), $themeStr, {renderer: '${widget.renderer}'});
      ${widget.extraScript}
      chart.setOption($_currentOption, true);
    ''');
    if (widget.onLoad != null) {
      widget.onLoad?.call(_controller);
    }
  }

  Set<Factory<OneSequenceGestureRecognizer>> getGestureRecognizers() {
    final gestures = <Factory<OneSequenceGestureRecognizer>>{};
    if (widget.captureAllGestures || widget.captureHorizontalGestures) {
      gestures.add(
        Factory<HorizontalDragGestureRecognizer>(
          () => HorizontalDragGestureRecognizer(),
        ),
      );
    }
    if (widget.captureAllGestures || widget.captureVerticalGestures) {
      gestures.add(
        Factory<VerticalDragGestureRecognizer>(
          () => VerticalDragGestureRecognizer(),
        ),
      );
    }
    return gestures;
  }

  Future<void> update(String previousOption) async {
    _currentOption = widget.option;
    if (_currentOption != previousOption) {
      await _controller.runJavaScript('''
        try {
          chart.setOption($_currentOption, true);
        } catch(e) {
        }
      ''');
    }
  }

  @override
  void didUpdateWidget(covariant Echarts oldWidget) {
    super.didUpdateWidget(oldWidget);
    update(oldWidget.option);
  }

  @override
  void dispose() {
    _controller.clearCache();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(
          controller: _controller,
          gestureRecognizers: getGestureRecognizers(),
        ),
        if (widget.loader != null && _isLoading)
          Positioned.fill(child: widget.loader!),
      ],
    );
  }
}
