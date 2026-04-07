import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subject.dart';

/// 全局当前学科，所有功能页共享
final currentSubjectProvider = StateProvider<Subject?>((ref) => null);
