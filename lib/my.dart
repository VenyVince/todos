import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:collection/collection.dart';
import 'dart:math' as math;
import 'todo.dart';
import 'nut.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

String getUserEmail() {
  final user = FirebaseAuth.instance.currentUser;
  return user?.email ?? ''; // 사용자가 로그인되어 있지 않으면 빈 문자열을 반환
}

Future<List<Todo>> _getTodosFromFirestore(String userEmail) async {
  try {
    var snapshot = await FirebaseFirestore.instance
        .collection('todos')
        .where('userEmail', isEqualTo: userEmail)  // userEmail을 기준으로 필터링
        .get();

    // 데이터가 존재하면 Todo 객체로 변환 / excel에 사용
    return snapshot.docs.map((doc) {
      return Todo(
          title: doc['title'] ?? '',  // title이 null일 경우 빈 문자열로 처리
          date: (doc['date'] as Timestamp?)?.toDate() ?? DateTime.now(),  // date가 null일 경우 현재 시간으로 처리
          isDone: doc['isDone'] ?? false,  // isDone이 null일 경우 false로 처리
          userEmail: doc['userEmail']
      );
    }).toList();
  } catch (e) {
    print('Error getting todos: $e');
    return [];
  }
}




class MyPage extends StatefulWidget {
  final List<Todo> todos;
  final List<Nutrition> nutritions;

  MyPage({required this.todos, required this.nutritions});

  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  int _selectedIndex = 0;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Page')),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: _buildSelectedView(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildTabButton('나의 기록', 0),
        _buildTabButton('통계', 1),
        _buildTabButton('피드백', 2),
      ],
    );
  }

  Widget _buildTabButton(String title, int index) {
    return ElevatedButton(
      child: Text(title),
      style: ElevatedButton.styleFrom(
        backgroundColor: _selectedIndex == index ? Colors.blue : Colors.grey,
        foregroundColor: Colors.white,
      ),
      onPressed: () {
        setState(() {
          _selectedIndex = index;
        });
      },
    );
  }

  Widget _buildSelectedView() {
    switch (_selectedIndex) {
      case 0:
        return _buildMyRecordsView();
      case 1:
        return _buildStatisticsView();
      case 2:
        return _buildFeedbackView();
      default:
        return Container();
    }
  }

  Widget _buildMyRecordsView() {
    List<Todo> displayTodos;

    if (_searchQuery.isEmpty) {
      // 검색어가 없을 때 모든 할 일을 오름차순 정렬
      displayTodos = widget.todos.toList();
      displayTodos.sort((a, b) => a.title.compareTo(b.title));
    } else {
      // 검색어가 있을 때 필터링 후 오름차순 정렬
      displayTodos = widget.todos
          .where((todo) => todo.title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
      displayTodos.sort((a, b) => a.title.compareTo(b.title));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              labelText: '할 일 검색',
              suffixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: displayTodos.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(displayTodos[index].title),
                subtitle: Text(displayTodos[index].date.toString()),
                trailing: Icon(
                  displayTodos[index].isDone ? Icons.check_box : Icons.check_box_outline_blank,
                ),
              );
            },
          ),
        ),
        ElevatedButton(
          child: Text('엑셀로 다운로드'),
          onPressed: () async {
            String userEmail = getUserEmail(); // 로그인한 사용자의 이메일 가져오기
            if (userEmail.isNotEmpty) {
              await _exportToExcelMobile(userEmail); // userEmail을 인자로 전달
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('로그인된 사용자가 없습니다.')),
              );
            }
          },
        )
      ],
    );
  }
  Future<void> _exportToExcelMobile(userEmail) async {
    String userEmail = getUserEmail(); // 로그인한 사용자의 이메일 가져오기
    if (userEmail.isNotEmpty) {
      // userEmail을 인자로 전달
      List<Todo> todos = await _getTodosFromFirestore(userEmail);
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      // 헤더 추가
      sheetObject.cell(CellIndex.indexByString("A1")).value = TextCellValue("제목");
      sheetObject.cell(CellIndex.indexByString("B1")).value = TextCellValue("날짜");
      sheetObject.cell(CellIndex.indexByString("C1")).value = TextCellValue("완료 여부");

      // 데이터 추가
      for (int i = 0; i < todos.length; i++) {
        sheetObject.cell(CellIndex.indexByString("A${i + 2}")).value = TextCellValue(todos[i].title);
        sheetObject.cell(CellIndex.indexByString("B${i + 2}")).value = TextCellValue(todos[i].date.toString());
        sheetObject.cell(CellIndex.indexByString("C${i + 2}")).value = TextCellValue(todos[i].isDone ? "완료" : "미완료");
      }

      final fileBytes = excel.save()!;

      // 임시 파일 저장
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/todos.xlsx');
      await file.writeAsBytes(fileBytes);

      // 파일 공유
      await Share.share('엑셀 파일을 다운로드하려면 이 링크를 클릭하세요: ${file.path}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인된 사용자가 없습니다.')),
      );
    }
  }



// 서버에 엑셀 파일 업로드하는 함수
  Future<String?> _uploadExcelFile(File file) async {
    final uri = Uri.parse('https://your-server.com/upload');  // 서버 URL
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseBody = await response.stream.bytesToString();
      final jsonResponse = jsonDecode(responseBody);
      return jsonResponse['downloadUrl'];  // 서버에서 제공한 다운로드 URL
    } else {
      print('파일 업로드 실패: ${response.statusCode}');
      return null;
    }
  }
  Widget _buildFeedbackView() {
    return Center(
      child: ElevatedButton(
        child: Text('피드백 보내기'),
        onPressed: () async {
          final Uri emailLaunchUri = Uri(
            scheme: 'mailto',
            path: 'redguy0814@gmail.com',
            query: encodeQueryParameters(<String, String>{
              'subject': 'All Care 앱 피드백',
              'body': '여기에 피드백을 작성해주세요.'
            }),
          );
          if (await canLaunch(emailLaunchUri.toString())) {
            await launch(emailLaunchUri.toString());
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('이메일 앱을 열 수 없습니다.')),
            );
          }
        },
      ),
    );
  }

  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
  Widget _buildStatisticsView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('통계', style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 20),
            _buildTodoCompletionChart(),
            SizedBox(height: 20),
            _buildNutritionIntakeChart(),
            SizedBox(height: 20),
            _buildCorrelationAnalysis(),
            SizedBox(height: 20),
            _buildRecommendations(),
          ],
        ),
      ),
    );
  }Widget _buildTodoCompletionChart() {
    final completionRates = _calculateTodoCompletionRates();
    return Container(
      height: 200,
      child: completionRates.isEmpty
          ? Center(child: Text('할 일 데이터가 없습니다.'))
          : LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: true),
          minX: 0,
          maxX: completionRates.length.toDouble() - 1,
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: completionRates.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value);
              }).toList(),
              isCurved: true,
              color: Colors.blue,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionIntakeChart() {
    final intakeRates = _calculateNutritionIntakeRates();
    return Container(
      height: 200,
      child: intakeRates.isEmpty
          ? Center(child: Text('영양제 데이터가 없습니다.'))
          : BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: intakeRates.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [BarChartRodData(toY: entry.value, color: Colors.green)],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCorrelationAnalysis() {
    List<double> todoCompletionRates = _calculateTodoCompletionRates();
    List<double> nutritionIntakeRates = _calculateNutritionIntakeRates();

    if (todoCompletionRates.isEmpty || nutritionIntakeRates.isEmpty) {
      return Text('상관관계를 계산할 데이터가 충분하지 않습니다.');
    }

    double correlation = _calculateCorrelation(todoCompletionRates, nutritionIntakeRates);
    return Text('할 일 완료율과 영양제 섭취율의 상관계수: ${correlation.toStringAsFixed(2)}');
  }

  Widget _buildRecommendations() {
    if (_calculateTodoCompletionRates().isEmpty && _calculateNutritionIntakeRates().isEmpty) {
      return Text('추천을 생성할 데이터가 충분하지 않습니다.');
    }
    String recommendation = _generateRecommendation();
    return Text('추천: $recommendation', style: TextStyle(fontWeight: FontWeight.bold));
  }

  List<double> _calculateTodoCompletionRates() {
    // 최근 7일간의 Todo 완료율 계산
    final now = DateTime.now();
    return List.generate(7, (index) {
      final date = now.subtract(Duration(days: index));
      final todosForDay = widget.todos.where((todo) => isSameDay(todo.date, date)).toList();
      if (todosForDay.isEmpty) return 0.0;
      final completedTodos = todosForDay.where((todo) => todo.isDone).length;
      return (completedTodos / todosForDay.length) * 100;
    }).reversed.toList();
  }

  List<double> _calculateNutritionIntakeRates() {
    // 최근 7일간의 영양제 섭취율 계산
    final now = DateTime.now();
    return List.generate(7, (index) {
      final date = now.subtract(Duration(days: index));
      final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      double totalTaken = 0;
      int totalNutritions = 0;

      for (var nutrition in widget.nutritions) {
        if (nutrition.takenDosageByDate.containsKey(dateString)) {
          totalTaken += nutrition.takenDosageByDate[dateString]! / nutrition.dosagePerCount;
          totalNutritions++;
        }
      }

      if (totalNutritions == 0) return 0.0;
      return (totalTaken / totalNutritions) * 100;
    }).reversed.toList();
  }

  double _calculateCorrelation(List<double> x, List<double> y) {
    if (x.length != y.length || x.isEmpty) return 0.0;

    double sum_x = 0, sum_y = 0, sum_xy = 0;
    double squareSum_x = 0, squareSum_y = 0;

    for (int i = 0; i < x.length; i++) {
      sum_x += x[i];
      sum_y += y[i];
      sum_xy += x[i] * y[i];
      squareSum_x += x[i] * x[i];
      squareSum_y += y[i] * y[i];
    }

    double corr = (x.length * sum_xy - sum_x * sum_y) /
        (math.sqrt((x.length * squareSum_x - sum_x * sum_x) *
            (x.length * squareSum_y - sum_y * sum_y)));

    return corr;
  }

  String _generateRecommendation() {
    double todoAverage = _calculateTodoCompletionRates().average;
    double nutritionAverage = _calculateNutritionIntakeRates().average;

    if (todoAverage < 50 && nutritionAverage < 50) {
      return '할 일 완료율과 영양제 섭취율을 모두 높이는 것이 좋겠습니다.';
    } else if (todoAverage < 50) {
      return '할 일 완료율을 높이면 전반적인 생산성이 향상될 수 있습니다.';
    } else if (nutritionAverage < 50) {
      return '영양제 섭취율을 높이면 건강 관리에 도움이 될 수 있습니다.';
    } else {
      return '현재 할 일 관리와 영양제 섭취가 잘 되고 있습니다. 계속 유지하세요!';
    }
  }
}


// 기존의 _buildStatisticsView() 및 관련 메서드들은 그대로 유지

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}