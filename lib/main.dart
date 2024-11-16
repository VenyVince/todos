import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'todo.dart';
import 'nut.dart';
import 'my.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'All Care',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // 다크 모드의 다른 테마 설정
      ),
      themeMode: ThemeMode.system, // 시스템 설정에 따라 테마 변경
      home: const MyHomePage(),
      // home: const LoginScreen(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Todo> _todoList = [];

  // 추가: Todo와 Nutrition 리스트를 저장할 변수
  final List<Todo> _ontodoList = [];
  final List<Nutrition> _nutritionList = [];

  late List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _widgetOptions = [
      TodoPage(
        selectedDate: _selectedDay!,
        onTodoAdded: _onTodoAdded,
        onTodoRemoved: _onTodoRemoved,
        onTodoListChanged: (List<Todo> updatedList) {
          setState(() {
            _todoList = updatedList;
          });
        },
      ),
      NutPage(
        selectedDate: _selectedDay!,
        onNutritionAdded: _onNutritionAdded,
        onNutritionRemoved: _onNutritionRemoved,
      ),
      MyPage(todos: _todoList, nutritions: _nutritionList),
    ];
  }

  // Todo 추가 콜백
  void _onTodoAdded(Todo todo) {
    setState(() {
      _todoList.add(todo);
      _updateMyPage();
    });
  }

  // Todo 제거 콜백
  void _onTodoRemoved(Todo todo) {
    setState(() {
      _todoList.remove(todo);
      _updateMyPage();
    });
  }

  // Nutrition 추가 콜백
  void _onNutritionAdded(Nutrition nutrition) {
    setState(() {
      _nutritionList.add(nutrition);
      _updateMyPage();
    });
  }

  // Nutrition 제거 콜백
  void _onNutritionRemoved(Nutrition nutrition) {
    setState(() {
      _nutritionList.remove(nutrition);
      _updateMyPage();
    });
  }

  // MyPage 업데이트
  void _updateMyPage() {
    _widgetOptions[2] = MyPage(todos: _todoList, nutritions: _nutritionList);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Todo> _getEventsForDay(DateTime day) {
    return _todoList.where((todo) =>
    isSameDay(todo.date, day) && !todo.isDone
    ).toList();
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2010, 10, 16),
      lastDay: DateTime.utc(2030, 3, 14),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
          // Todo 페이지의 선택된 날짜 업데이트
          _widgetOptions[0] = TodoPage(
            selectedDate: selectedDay,
            onTodoAdded: _onTodoAdded,
            onTodoRemoved: _onTodoRemoved,
            onTodoListChanged: (List<Todo> updatedList) {
              setState(() {
                _todoList = updatedList;
              });
            },
          );
          // Nut 페이지의 선택된 날짜 업데이트
          _widgetOptions[1] = NutPage(
            selectedDate: selectedDay,
            onNutritionAdded: _onNutritionAdded,
            onNutritionRemoved: _onNutritionRemoved,);
        });
      },
      onFormatChanged: (format) {
        if (_calendarFormat != format) {
          setState(() {
            _calendarFormat = format;
          });
        }
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
      },
      eventLoader: (day) {
        return _getEventsForDay(day);
      },
      calendarStyle: CalendarStyle(
        defaultTextStyle: const TextStyle(color: Colors.black),
        todayDecoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        selectedDecoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        defaultDecoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.withOpacity(0.1),
        ),
        weekendDecoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.withOpacity(0.1),
        ),
        outsideDecoration: const BoxDecoration(shape: BoxShape.circle),
        markerDecoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekendStyle: TextStyle(color: Colors.red),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          if (events.isNotEmpty) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return Positioned(
                  right: constraints.maxWidth * 0.1, // 날짜 셀 너비의 10% 지점에 위치
                  top: constraints.maxHeight * 0.1,  // 날짜 셀 높이의 10% 지점에 위치
                  child: Container(
                    width: constraints.maxWidth * 0.06,  // 날짜 셀 너비의 10%로 축소
                    height: constraints.maxWidth * 0.1, // 정사각형 모양 유지
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFA500), // 주황색
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${events.length}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: constraints.maxWidth * 0.1, // 날짜 셀 너비의 6%로 축소
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Care'),
        elevation: 0,
      ),
      body: Column(
        children: <Widget>[
          if (_selectedIndex != 2) _buildCalendar(),
          Expanded(
            child: Center(
              child: _widgetOptions.elementAt(_selectedIndex),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.check),
            label: 'Todo',
          ),
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.pills),
            label: 'Nutrition',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'My',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}

bool isSameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) {
    return false;
  }
  return a.year == b.year && a.month == b.month && a.day == b.day;
}