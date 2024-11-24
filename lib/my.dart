import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'todo.dart'; // Todo 클래스를 가져옵니다.
import 'nut.dart';  // Nutrition 클래스를 가져옵니다.

class MyPage extends StatelessWidget {
  final List<Todo> todos; // Todo 리스트
  final List<Nutrition> nutritions; // Nutrition 리스트

  MyPage({required this.todos, required this.nutritions}); // 생성자

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '나의 기록',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomeScreen(todos: todos, nutritions: nutritions), // HomeScreen에 todos와 nutritions 전달
    );
  }
}

class SearchPage extends StatefulWidget {
  final List<Todo> todos;
  final List<Nutrition> nutritions;

  SearchPage({required this.todos, required this.nutritions});

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

  void filterData() {
    setState(() {
      filteredTodos = widget.todos.where((todo) {
        return todo.title.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();

      filteredNutritions = widget.nutritions.where((nutrition) {
        return nutrition.name.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();

      if (startDate != null && endDate != null) {
        filteredTodos = filteredTodos.where((todo) =>
        todo.date.isAfter(startDate!) && todo.date.isBefore(endDate!)).toList();
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    // 시작 날짜와 종료 날짜를 선택할 수 있는 다이얼로그 표시
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
        startDate = picked.start; // 시작 날짜 업데이트
        endDate = picked.end;     // 종료 날짜 업데이트
        filterData();             // 날짜 선택 후 데이터 필터링
      });
    }
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
                  onPressed: () => _selectDate(context), // 캘린더 아이콘 클릭 시 날짜 선택
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

class StatisticsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('통계'),
      ),
      body: Center(
        child: Text('통계 기능이 여기에 구현됩니다.'),
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
        child: Text('신고 기능이 여기에 구현됩니다.'),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final List<Todo> todos; // Todo 리스트
  final List<Nutrition> nutritions; // Nutrition 리스트

  HomeScreen({required this.todos, required this.nutritions}); // 생성자

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
    loadInitialData(); // 필요에 따라 초기 데이터 로드 메서드 호출 가능
  }

  Future<void> loadInitialData() async {
    // Firestore에서 Todo 데이터 로드 (필요 시)
    QuerySnapshot todoSnapshot = await FirebaseFirestore.instance.collection('todos').get();
    todos = todoSnapshot.docs.map((doc) => Todo.fromMap(doc.data() as Map<String, dynamic>)).toList();

    // Firestore에서 Nutrition 데이터 로드 (필요 시)
    QuerySnapshot nutritionSnapshot = await FirebaseFirestore.instance.collection('nutrition').get();
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
        currentPage = SearchPage(todos: todos, nutritions: nutriList); // 검색 페이지 표시
        break;
      case 2:
        currentPage = StatisticsPage(); // 통계 페이지 표시
        break;
      case 3:
        currentPage = ReportPage(); // 신고 페이지 표시
        break;
      default:
        currentPage = Container(); // 기본값으로 빈 화면 표시
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('나의 기록'),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            onPressed: showDownloadMessage,
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
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
          Expanded(child : currentPage), // 현재 선택된 페이지 표시
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