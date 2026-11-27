import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import 'package:dio/dio.dart';
import 'package:JWHelper/infrastructure/network/client.dart';
import 'package:JWHelper/features/progress/domain/progress_item.dart';
import 'package:JWHelper/features/navigation/data/jw_endpoint_resolver.dart';
import 'package:JWHelper/features/navigation/domain/app_feature.dart';

final RegExp _fallbackMinCreditsRegExp = RegExp(
  r'(?:课程|方案|毕业|主修)?要求最低学分\s*[：:]\s*(\d+(?:\.\d+)?)',
);
final RegExp _postbackIdRegExp = RegExp(r"tvProgramProgress','([^']+)'");
final RegExp _nonDigitsRegExp = RegExp(r'[^0-9]');
final RegExp _digitsRegExp = RegExp(r'(\d+)');
final RegExp _whitespaceRegExp = RegExp(r'\s+');
final RegExp _creditPairRegExp =
    RegExp(r'(\d+(\.\d+)?)[（\(](\d+(\.\d+)?)[）\)]');
final RegExp _numberRegExp = RegExp(r'(\d+(\.\d+)?)');
final RegExp _groupHeaderRegExp =
    RegExp(r'(.+)\((\d+(?:\.\d+)?)/((?:\d+(?:\.\d+)?)|未设置)\)');

String _formatCreditNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toString();
}

bool _isUnsetCreditText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ||
      trimmed == '-' ||
      trimmed.contains('未设置');
}

/// 从文本中提取「（课程）要求最低学分：X」对应的数值。
double? _extractFallbackMinCreditsFromText(String text) {
  final match = _fallbackMinCreditsRegExp.firstMatch(text);
  if (match == null) return null;
  final value = double.tryParse(match.group(1)!);
  if (value == null || value <= 0) return null;
  return value;
}

/// 分组详情：课程列表 + 可选的后备最低学分要求。
class ProgressGroupDetail {
  final List<ProgressCourse> courses;
  final double? requiredCredits;

  const ProgressGroupDetail({
    required this.courses,
    this.requiredCredits,
  });
}

// Top-level helper
String? _extractId(Element a) {
  // 1. Try href postback: javascript:__doPostBack('...','s100')
  var href = a.attributes['href'] ?? "";
  var match = _postbackIdRegExp.firstMatch(href);
  if (match != null) return match.group(1);

  // 2. Try id attribute: childA123
  var idAttr = a.attributes['id'] ?? "";
  if (idAttr.isNotEmpty) {
    var digits = idAttr.replaceAll(_nonDigitsRegExp, '');
    if (digits.isNotEmpty) return digits;
  }

  // 3. Try onclick: changeGroup(123) or clickNode('123')
  var onclick = a.attributes['onclick'] ?? "";
  if (onclick.isNotEmpty) {
    var clickMatch = _digitsRegExp.firstMatch(onclick);
    if (clickMatch != null) return clickMatch.group(1);
  }

  return null;
}

// Top-level function for compute
Map<String, dynamic> _parseProgressHtml(String html) {
  var doc = parser.parse(html);

  // Extract systemNumber
  String systemNumber = "";
  var sysInput = doc.querySelector('input#systemNumber');
  if (sysInput != null) {
    systemNumber = sysInput.attributes['value'] ?? "";
  }

  List<ProgressInfo> basicInfo = [];
  List<ProgressGroup> groups = [];

  // 1. Parse Basic Info
  Map<String, String> idMap = {
    'lblMainAvgCreditHour': '学位课程绩点',
    'lblAcquiredCreditsInProg2': '已获得学分',
    'lblLeastCreditsOfProg': '要求最低学分',
  };

  idMap.forEach((id, label) {
    var element = doc.querySelector('#$id');
    if (element != null) {
      var value = element.text.trim();
      if (value.isNotEmpty) {
        basicInfo.add(ProgressInfo(label: label, value: value));
      }
    }
  });

  // Fallback: If IDs fail, try to scan tables (Legacy support)
  if (basicInfo.isEmpty) {
    var tables = doc.querySelectorAll('table');
    Set<String> foundLabels = {};

    for (var table in tables) {
      if (table.id == 'tableTree') continue;

      var rows = table.querySelectorAll('tr');
      for (var row in rows) {
        var cols = row.querySelectorAll('td, th');
        for (var i = 0; i < cols.length; i++) {
          var text = cols[i].text.trim();

          if (text.contains("已获得学分") && text.contains("要求最低学分")) {
            if (i + 1 < cols.length) {
              var valueText =
                  cols[i + 1].text.trim().replaceAll(_whitespaceRegExp, '');
              var match = _creditPairRegExp.firstMatch(valueText);

              if (match != null) {
                if (!foundLabels.contains("已获得学分")) {
                  basicInfo.add(
                      ProgressInfo(label: "已获得学分", value: match.group(1)!));
                  foundLabels.add("已获得学分");
                }
                if (!foundLabels.contains("要求最低学分")) {
                  basicInfo.add(
                      ProgressInfo(label: "要求最低学分", value: match.group(3)!));
                  foundLabels.add("要求最低学分");
                }
              }
            }
            continue;
          }

          bool isMajorCredit = text.contains("主修") && text.contains("方案外");
          bool isGPA = text.contains("学位课程绩点");

          if (isMajorCredit || isGPA) {
            String label = isMajorCredit ? "主修与方案外获得学分" : "学位课程绩点";
            if (i + 1 < cols.length) {
              var value =
                  cols[i + 1].text.trim().replaceAll(_whitespaceRegExp, ' ');
              if (isGPA) {
                var match = _numberRegExp.firstMatch(value);
                if (match != null) value = match.group(1)!;
              }
              if (!foundLabels.contains(label)) {
                basicInfo.add(ProgressInfo(label: label, value: value));
                foundLabels.add(label);
              }
            }
          }
        }
      }
    }
  }

  // 2. Parse Course Groups (Tree Table)
  var treeTable = doc.querySelector('table#tableTree');
  if (treeTable != null) {
    var links = treeTable.querySelectorAll('a');

    for (var i = 0; i < links.length; i++) {
      var a = links[i];
      var text = a.text.trim();

      if (text.contains("展开") || text.contains("折叠") || text.isEmpty) continue;

      // Modified regex to handle "未设置" (Not Set) in required credits
      var match = _groupHeaderRegExp.firstMatch(text);

      if (match != null) {
        String name = match.group(1)!.trim();
        double earned = double.parse(match.group(2)!);

        double required = -1;
        String requiredStr = match.group(3)!;
        if (requiredStr != "未设置") {
          required = double.parse(requiredStr);
        } else {
          // 后备查询：尝试从节点属性或所在行中提取「课程要求最低学分：X」
          final titleHint = a.attributes['title'] ?? '';
          final rowText = a.parent?.text ?? '';
          final fallback = _extractFallbackMinCreditsFromText(titleHint) ??
              _extractFallbackMinCreditsFromText(rowText);
          if (fallback != null) {
            required = fallback;
          }
        }

        String? id = _extractId(a);
        if (id == null && i + 1 < links.length) {
          id = _extractId(links[i + 1]);
        }
        if (id == null && i - 1 >= 0) {
          id = _extractId(links[i - 1]);
        }
        id ??= name;

        groups.add(ProgressGroup(
          id: id,
          name: name,
          required: required,
          earned: earned,
        ));
      }
    }
  }

  // Parse "Out of Program" Courses (方案外课程)
  var outOfProgBoxes = doc.querySelectorAll('div.box.box-primary');

  for (var outOfProgBox in outOfProgBoxes) {
    var titleEl = outOfProgBox.querySelector('h3.box-title');

    if (titleEl != null && titleEl.text.contains("方案外课程")) {
      double earned = 0;
      var earnedEl =
          outOfProgBox.querySelector('#lblAcquiredCreditsOutOfProg2');
      if (earnedEl != null) {
        earned = double.tryParse(earnedEl.text.trim()) ?? 0;
      }

      List<ProgressCourse> outCourses = [];
      var table = outOfProgBox.querySelector('table#tableCourseOutOfProg');
      if (table != null) {
        var rows = table.querySelectorAll('tr');
        for (var i = 1; i < rows.length; i++) {
          var cols = rows[i].querySelectorAll('td');
          if (cols.length >= 8) {
            String name = cols[2].text.trim();
            String score = cols[3].text.trim();
            String credit = cols[5].text.trim();

            bool isPassed = true;
            double? scoreNum = double.tryParse(score);
            if (scoreNum != null) {
              isPassed = scoreNum >= 60;
            } else {
              if (score.contains("不合格") || score.contains("F")) {
                isPassed = false;
              }
            }

            outCourses.add(ProgressCourse(
              name: name,
              credit: credit,
              score: score,
              isPassed: isPassed,
            ));
          }
        }
      }

      groups.add(ProgressGroup(
        id: "out_of_program",
        name: "方案外课程",
        required: 0,
        earned: earned,
        courses: outCourses,
      ));
      break;
    }
  }

  // Calculate "Major & Extra Credits"
  String? extraCreditsStr;
  var extraCreditsEl = doc.querySelector('#lblAcquiredCreditsOutOfProg2');
  if (extraCreditsEl != null) {
    extraCreditsStr = extraCreditsEl.text.trim();
  }

  var inProgInfo = basicInfo.firstWhere((i) => i.label == "已获得学分",
      orElse: () => ProgressInfo(label: "", value: ""));

  if (inProgInfo.value.isNotEmpty && extraCreditsStr != null) {
    double inProg = double.tryParse(inProgInfo.value) ?? 0;
    double outProg = double.tryParse(extraCreditsStr) ?? 0;
    double total = inProg + outProg;
    String value = total % 1 == 0 ? total.toInt().toString() : total.toString();

    basicInfo.removeWhere((i) => i.label == "主修与方案外获得学分");
    basicInfo.insert(0, ProgressInfo(label: "主修与方案外获得学分", value: value));
  } else {
    bool hasTotalCredits = basicInfo.any((i) => i.label.contains("主修与方案外获得学分"));
    if (!hasTotalCredits && groups.isNotEmpty) {
      double total = 0;
      for (var g in groups) {
        total += g.earned;
      }
      String value =
          total % 1 == 0 ? total.toInt().toString() : total.toString();
      basicInfo.insert(0, ProgressInfo(label: "主修与方案外获得学分", value: value));
    }
  }

  // 后备查询：若顶部「要求最低学分」缺失或显示「未设置」，
  // 在页面中寻找「课程要求最低学分：X」等相关字样。
  final minCreditIndex = basicInfo.indexWhere((i) => i.label == '要求最低学分');
  final minCreditUnset = minCreditIndex < 0 ||
      _isUnsetCreditText(basicInfo[minCreditIndex].value);
  if (minCreditUnset) {
    final fallbackCredits =
        _extractFallbackMinCreditsFromText(doc.body?.text ?? html) ??
            _extractFallbackMinCreditsFromText(html);
    if (fallbackCredits != null) {
      final formatted = _formatCreditNumber(fallbackCredits);
      if (minCreditIndex >= 0) {
        basicInfo[minCreditIndex] =
            ProgressInfo(label: '要求最低学分', value: formatted);
      } else {
        basicInfo.add(ProgressInfo(label: '要求最低学分', value: formatted));
      }
    }
  }

  return {
    "groups": groups,
    "info": basicInfo,
    "systemNumber": systemNumber,
  };
}

class ProgressService {
  final ApiClient _client;
  final JwEndpointResolver _endpoints;
  String _systemNumber = "";

  ProgressService({
    ApiClient? client,
    JwEndpointResolver? endpoints,
  })  : _client = client ?? ApiClient(),
        _endpoints = endpoints ?? JwEndpointResolver();

  String get _progressPageUrl => _endpoints.pageUrl(AppFeature.progress);

  String get _progressHandlerUrl =>
      _endpoints.handlerUrl(AppFeature.progress);

  Future<Map<String, dynamic>> getProgressData() async {
    try {
      var response = await _client.dio.get(_progressPageUrl);

      // Use compute for parsing
      var result = await compute(_parseProgressHtml, response.data.toString());

      _systemNumber = result['systemNumber'] ?? "";

      return {
        "groups": result['groups'],
        "info": result['info'],
      };
    } catch (e) {
      debugPrint("Get progress failed: $e");
      rethrow;
    }
  }

  @visibleForTesting
  static Map<String, dynamic> parseProgressHtmlForTest(String html) =>
      _parseProgressHtml(html);

  /// 从 `MyProgramProgressHandler.ashx?action=GetData` 响应中提取后备最低学分。
  static double? parseRequiredCreditsFromGroupResponse(
    dynamic data, {
    String? rawText,
  }) {
    const creditKeys = {
      'leastcredit',
      'leastcredits',
      'mincredit',
      'mincredits',
      'requiredcredit',
      'requiredcredits',
      'needcredit',
      'needcredits',
      'courseleastcredit',
      'courseleastcredits',
    };

    double? searchMap(Map map) {
      for (final entry in map.entries) {
        final key = entry.key.toString().toLowerCase();
        final value = entry.value;
        if (value is String) {
          final fromText = _extractFallbackMinCreditsFromText(value);
          if (fromText != null) return fromText;
        }
        if (creditKeys.contains(key)) {
          final parsed = value is num
              ? value.toDouble()
              : double.tryParse(value?.toString().trim() ?? '');
          if (parsed != null && parsed > 0) return parsed;
        }
        if (value is Map) {
          final nested = searchMap(value);
          if (nested != null) return nested;
        }
      }
      return null;
    }

    if (data is Map) {
      final fromMap = searchMap(data);
      if (fromMap != null) return fromMap;
    }
    if (rawText != null && rawText.isNotEmpty) {
      return _extractFallbackMinCreditsFromText(rawText);
    }
    return null;
  }

  Future<ProgressGroupDetail> getGroupDetails(String groupId) async {
    // systemNumber can be empty, so we don't check for isEmpty

    try {
      String url =
          '$_progressHandlerUrl?action=GetData&random=${DateTime.now().millisecondsSinceEpoch}';

      var formData = {
        "groupId": groupId,
        "systemNumber": _systemNumber,
      };

      var response = await _client.dio.post(
        url,
        data: formData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            "X-Requested-With": "XMLHttpRequest",
            "Referer": _progressPageUrl,
          },
        ),
      );

      if (response.statusCode == 200) {
        var data = response.data;
        final rawText = data?.toString() ?? '';
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            debugPrint("JSON decode error: $e");
          }
        }

        final requiredCredits = parseRequiredCreditsFromGroupResponse(
          data,
          rawText: rawText,
        );

        if (data is Map && data.containsKey('Datas')) {
          List<dynamic> datas = data['Datas'];
          debugPrint("Group [$groupId] courses loaded: ${datas.length}");
          final courses = datas.map((json) {
            return ProgressCourse(
              name: json['CourseName'] ?? '未知',
              credit: json['GetCredit']?.toString() ?? '0',
              score: (json['Mark']?.toString().isNotEmpty == true)
                  ? json['Mark'].toString()
                  : '-',
              isPassed: json['IsPass'] == true,
            );
          }).toList();
          return ProgressGroupDetail(
            courses: courses,
            requiredCredits: requiredCredits,
          );
        }

        return ProgressGroupDetail(
          courses: const [],
          requiredCredits: requiredCredits,
        );
      }
    } catch (e) {
      debugPrint("Get group courses failed: $e");
      rethrow;
    }
    return const ProgressGroupDetail(courses: []);
  }

  Future<List<ProgressCourse>> getGroupCourses(String groupId) async {
    final detail = await getGroupDetails(groupId);
    return detail.courses;
  }
}
