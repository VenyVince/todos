import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'todo.dart'; // Todo 클래스를 가져옵니다.
import 'nut.dart';  // Nutrition 클래스를 가져옵니다.
import 'package:firebase_auth/firebase_auth.dart';


class MyPage extends StatelessWidget {
  final List<Todo> todos; // Todo 리스트
  final List<Nutrition> nutritions; // Nutrition 리스트
  final String userEmail;

  MyPage({required this.todos, required this.nutritions, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '나의 기록',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomeScreen(todos: todos, nutritions: nutritions, userEmail: userEmail,), // HomeScreen에 todos와 nutritions 전달
    );
  }
}

class SearchPage extends StatefulWidget {
  final List<Todo> todos;
  final List<Nutrition> nutritions;
  final String userEmail;

  SearchPage({required this.todos, required this.nutritions, required this.userEmail});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late List<Todo> filteredTodos;
  late List<Nutrition> filteredNutritions;
  String searchQuery = '';
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    filteredTodos = widget.todos;
    filteredNutritions = widget.nutritions;
    sortData(); // 초기 데이터 정렬
  }

  void sortData() {
    filteredTodos.sort((a, b) => a.title.compareTo(b.title)); // 제목 오름차순 정렬
    filteredNutritions.sort((a, b) => a.name.compareTo(b.name)); // 이름 오름차순 정렬
  }

  Future<void> _enterDateRange(BuildContext context) async {
    int? startYear;
    int? startMonth;
    int? endYear;
    int? endMonth;

    List<int> years = [for (int i = 2000; i <= DateTime.now().year; i++) i];
    List<int> months = [for (int i = 1; i <= 12; i++) i];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // StatefulBuilder 추가
          builder: (context, setState) {
            return AlertDialog(
              title: Text('날짜 범위 입력'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: DropdownButton<int>(
                          hint: Text('시작 연도'),
                          value: startYear,
                          onChanged: (int? newValue) {
                            setState(() {
                              startYear = newValue;
                            });
                          },
                          items: years.map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value'),
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: DropdownButton<int>(
                          hint: Text('시작 월'),
                          value: startMonth,
                          onChanged: (int? newValue) {
                            setState(() {
                              startMonth = newValue;
                            });
                          },
                          items: months.map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value'),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: DropdownButton<int>(
                          hint: Text('종료 연도'),
                          value: endYear,
                          onChanged: (int? newValue) {
                            setState(() {
                              endYear = newValue;
                            });
                          },
                          items: years.map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value'),
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: DropdownButton<int>(
                          hint: Text('종료 월'),
                          value: endMonth,
                          onChanged: (int? newValue) {
                            setState(() {
                              endMonth = newValue;
                            });
                          },
                          items: months.map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value'),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // 취소 시 닫기
                  },
                  child: Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    if (startYear != null && startMonth != null && endYear != null && endMonth != null) {
                      setState(() {
                        startDate = DateTime(startYear!, startMonth!, 1);
                        endDate = DateTime(endYear!, endMonth!, 1);
                        filterData(); // 날짜 선택 후 필터링
                      });
                      Navigator.of(context).pop();
                    } else {
                      // 입력값이 유효하지 않으면 에러 처리
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('시작 날짜나 종료 날짜가 제대로 선택되지 않았습니다.')),
                      );
                    }
                  },
                  child: Text('확인'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void filterData() {
    setState(() {
      filteredTodos = widget.todos.where((todo) {
        return todo.title.toLowerCase().contains(searchQuery.toLowerCase()) &&
            todo.userEmail == widget.userEmail; // 유저 이메일 필터링 추가
      }).toList();
      filteredNutritions = widget.nutritions.where((nutrition) {
        return nutrition.name.toLowerCase().contains(searchQuery.toLowerCase()) &&
            nutrition.userEmail == widget.userEmail; // 유저 이메일 필터링
      }).toList();
      if (startDate != null && endDate != null) {
        filteredTodos = filteredTodos.where((todo) => todo.date.isAfter(startDate!) && todo.date.isBefore(endDate!)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('검색'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(labelText: '검색'),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value; // 필터링 변수 업데이트
                        filterData(); // 데이터 필터링
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: () => _enterDateRange(context), // 캘린더 아이콘 클릭 시 날짜 선택
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredTodos.isEmpty && filteredNutritions.isEmpty
                ? Center(child: Text('검색 결과가 없습니다.')) // 검색 결과가 없을 때 메시지 표시
                : ListView.builder(
              itemCount: filteredTodos.length + filteredNutritions.length,
              itemBuilder: (context, index) {
                if (index < filteredTodos.length) {
                  final todo = filteredTodos[index];
                  return ListTile(
                    title: Text(todo.title),
                    subtitle: Text('완료 여부: ${todo.isDone ? "완료" : "미완료"}'),
                  );
                } else {
                  final nutrition = filteredNutritions[index - filteredTodos.length];
                  return ListTile(
                    title: Text(nutrition.name),
                    subtitle: Text('총 복용량: ${nutrition.totalDosage}mg'),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class StatisticsPage extends StatefulWidget {
  final List<Todo> todos;
  final List<Nutrition> nutritions; // Nutrition 리스트 추가

  StatisticsPage({required this.todos, required this.nutritions});

  @override
  _StatisticsPageState createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  DateTime? startDate;
  DateTime? endDate;
  double completionRate = 0.0;
  List<Map<String, dynamic>> ntakendosagepercent = []; //name에 해당하는 taken값(페센트 값으로)

  @override
  void initState() {
    super.initState();
  }

  void _selectDateRange(BuildContext context) async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDateRange: DateTimeRange(
        start: startDate ?? DateTime.now(),
        end: endDate ?? DateTime.now(),
      ),
    );
    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
        _calculateStatistics();
      });
    }
  }
  void _calculateStatistics() {
    if (startDate == null || endDate == null) return;

    // 할 일 완료율 계산 (기존 코드와 동일)
    int totalTasks = 0;
    int completedTasks = 0;
    for (var todo in widget.todos) {
      if (todo.date.isAfter(startDate!) && todo.date.isBefore(endDate!)) {
        totalTasks++;
        if (todo.isDone) completedTasks++;
      }
    }
    completionRate = (totalTasks > 0) ? (completedTasks / totalTasks) * 100 : 0;

    // 영양제 섭취율 계산
    ntakendosagepercent.clear();
    for (var nutrition in widget.nutritions) {
      double totalDosage = 0.0;
      double takenDosage = 0.0;

      nutrition.takenDosageByDate.forEach((date, dosage) {
        DateTime parsedDate = DateTime.parse(date);
        if (parsedDate.isAfter(startDate!) && parsedDate.isBefore(endDate!)) {
          takenDosage += dosage;
          totalDosage += nutrition.totalDosage;
        }
      });

      if (totalDosage > 0) {
        double takendosagepercent = (takenDosage / totalDosage) * 100;
        ntakendosagepercent.add({
          'name': nutrition.name,
          'takendosagepercent': takendosagepercent,
        });
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('통계'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '기간 선택: ',
                  style: TextStyle(fontSize: 18),
                ),
                IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: () => _selectDateRange(context),
                ),
              ],
            ),
            SizedBox(height: 20),
            if (startDate != null && endDate != null) ...[
              Text(
                '선택한 기간: ${startDate!.toLocal().toIso8601String().substring(0, 10)} ~ ${endDate!.toLocal().toIso8601String().substring(0, 10)}',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 20),
              Text(
                '할 일 완료율: ${completionRate.toStringAsFixed(2)}%',
                style: TextStyle(fontSize: 24),
              ),
              SizedBox(height: 10),
              Text('영양제 섭취율:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Column(
                children: ntakendosagepercent.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item['name'], style: TextStyle(fontSize: 16)),
                      Text('${item['takendosagepercent'].toStringAsFixed(2)}%', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                )).toList(),
              ),
            ] else ...[
              Text(
                '날짜 범위를 선택해주세요.',
                style: TextStyle(fontSize: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}



class ReportPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('신고'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '오류 사항을 redguy0814@gmail.com으로 신고해 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final List<Todo> todos;
  final List<Nutrition> nutritions;
  final String userEmail;

  HomeScreen({required this.todos, required this.nutritions, required this.userEmail});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<Todo> todos;
  late List<Nutrition> nutriList;
  int _selectedPageIndex = 0; // 현재 선택된 페이지 인덱스

  @override
  void initState() {
    super.initState();
    todos = widget.todos; // 전달받은 todos 사용
    nutriList = widget.nutritions; // 전달받은 nutritions 사용
    String userEmail = FirebaseAuth.instance.currentUser!.email!; // 현재 로그인한 사용자의 이메일
    loadInitialData(userEmail); // 필요에 따라 초기 데이터 로드 메서드 호출 가능
  }

  Future<void> loadInitialData(String userEmail) async {
    // Firestore에서 Todo 데이터 로드 (사용자 이메일로 필터링)
    QuerySnapshot todoSnapshot = await FirebaseFirestore.instance
        .collection('todos')
        .where('userEmail', isEqualTo: userEmail) // 이메일로 필터링
        .get();

    todos = todoSnapshot.docs.map((doc) => Todo.fromMap(doc.data() as Map<String, dynamic>)).toList();

    // Firestore에서 Nutrition 데이터 로드 (사용자 이메일로 필터링)
    QuerySnapshot nutritionSnapshot = await FirebaseFirestore.instance
        .collection('nutrition')
        .where('userEmail', isEqualTo: userEmail) // 이메일로 필터링
        .get();

    nutriList = nutritionSnapshot.docs.map((doc) => Nutrition.fromMap(doc.data() as Map<String, dynamic>)).toList();

    setState(() {});
  }


  void showDownloadMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('엑셀 시트가 다운로드 완료되었습니다.')),
    );
  }

  void _navigateToSearch() {
    setState(() {
      _selectedPageIndex = 1;
    });
  }

  void _navigateToStatistics() {
    setState(() {
      _selectedPageIndex = 2;
    });
  }

  void _navigateToReport() {
    setState(() {
      _selectedPageIndex = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget currentPage;

    switch (_selectedPageIndex) {
      case 0:
        currentPage = Container(); // 기본값으로 빈 화면 표시
        break;
      case 1:
        currentPage = SearchPage(todos: todos, nutritions: nutriList, userEmail: widget.userEmail); // 검색 페이지 표시
        break;
      case 2:
        currentPage = StatisticsPage(todos: todos, nutritions: nutriList); // 통계 페이지 표시
        break;
      case 3:
        currentPage = ReportPage(); // 신고 페이지 표시
        break;
      default:
        currentPage = Container(); // 기본값으로 빈 화면 표시
        break;
    }

    return Scaffold(
      appBar :AppBar(
        title :Text ('나의 기록'),
        actions :[
          IconButton(
            icon :Icon(Icons.download),
            onPressed :showDownloadMessage,
          ),
        ],
      ),
      body :Column(
        children :[
          Row(
            mainAxisAlignment :MainAxisAlignment.spaceAround,
            children :[
              ElevatedButton(
                onPressed:_navigateToSearch,
                child :Text ('검색'),
              ),
              ElevatedButton(
                onPressed:_navigateToStatistics,
                child :Text ('통계'),
              ),
              ElevatedButton(
                onPressed:_navigateToReport,
                child :Text ('신고'),
              ),
            ],
          ),
          Expanded(child :currentPage), // 현재 선택된 페이지 표시
        ],
      ),
    );
  }
}

// 날짜 비교 유틸리티 함수
bool isSameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) {
    return false;
  }
  return a.year == b.year && a.month == b.month && a.day == b.day;
}