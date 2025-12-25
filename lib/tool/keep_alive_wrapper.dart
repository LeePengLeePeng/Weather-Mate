import 'package:flutter/material.dart';

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  final bool keepAlive;

  const KeepAliveWrapper({
    super.key, 
    required this.child, 
    this.keepAlive = true,
  });

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    // 🔥 這一行絕對不能少！沒有它，KeepAlive 就無效！
    super.build(context); 
    return widget.child;
  }

  @override
  bool get wantKeepAlive => widget.keepAlive;
}