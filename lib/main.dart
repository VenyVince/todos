import 'package:firebase_auth/firebase_auth.dart';
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

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();

  static _MyAppState of(BuildContext context) => context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

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
      ),
      themeMode: _themeMode,
      home: const LoginScreen(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String userEmail;

  const MyHomePage({Key? key, required this.userEmail}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Todo> _todoList = [];

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
        userEmail: FirebaseAuth.instance.currentUser?.email ?? '',
      ),
      NutPage(
        selectedDate: _selectedDay!,
        userEmail: FirebaseAuth.instance.currentUser?.email ?? '',
      ),
      MyPage(todos: _todoList, nutritions: _nutritionList),
    ];
  }

  bool _isAllTodosCompletedForDay(DateTime day) {
    var todosForDay = _todoList.where((todo) => isSameDay(todo.date, day)).toList();
    return todosForDay.isNotEmpty && todosForDay.every((todo) => todo.isDone);
  }

  void _onTodoAdded(Todo todo) {
    setState(() {
      _todoList.add(todo);
      _updateMyPage();
    });
  }

  void _onTodoRemoved(Todo todo) {
    setState(() {
      _todoList.remove(todo);
      _updateMyPage();
    });
  }

  void _onNutritionAdded(Nutrition nutrition) {
    setState(() {
      _nutritionList.add(nutrition);
      _updateMyPage();
    });
  }

  void _onNutritionRemoved(Nutrition nutrition) {
    setState(() {
      _nutritionList.removeWhere((n) => n.id == nutrition.id);
      _updateMyPage();
    });
  }

  void _updateMyPage() {
    setState(() {
      _widgetOptions[2] = MyPage(todos: _todoList, nutritions: _nutritionList);
    });
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
          _widgetOptions[0] = TodoPage(
            selectedDate: selectedDay,
            onTodoAdded: _onTodoAdded,
            onTodoRemoved: _onTodoRemoved,
            onTodoListChanged: (List<Todo> updatedList) {
              setState(() {
                _todoList = updatedList;
              });
            },
            userEmail: FirebaseAuth.instance.currentUser?.email ?? '',
          );
          _widgetOptions[1] = NutPage(
            selectedDate: selectedDay,
            userEmail: FirebaseAuth.instance.currentUser?.email ?? '',
          );
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
        defaultBuilder: (context, day, focusedDay) {
          if (_isAllTodosCompletedForDay(day)) {
            return Container(
              margin: const EdgeInsets.all(4.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(color: Colors.black),
              ),
            );
          }
          return null;
        },
        markerBuilder: (context, date, events) {
          if (events.isNotEmpty) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final cellSize = constraints.maxWidth;
                final screenWidth = MediaQuery.of(context).size.width;

                // 화면 크기에 따라 마커 크기 비율 조정
                double markerSizeRatio;
                if (screenWidth < 360) {
                  markerSizeRatio = 0.22; // 매우 작은 화면
                } else if (screenWidth < 480) {
                  markerSizeRatio = 0.20; // 작은 화면
                } else if (screenWidth < 600) {
                  markerSizeRatio = 0.18; // 중소형 화면
                } else if (screenWidth < 720) {
                  markerSizeRatio = 0.16; // 중형 화면
                } else if (screenWidth < 1024) {
                  markerSizeRatio = 0.13; // 대형 화면
                } else if (screenWidth < 1200) {
                  markerSizeRatio = 0.10; // 매우 큰 화면
                } else {
                  markerSizeRatio = 0.07; // 초대형 화면
                }

                final markerSize = cellSize * markerSizeRatio;
                final fontSize = markerSize * 0.7; // 마커 크기의 50%로 폰트 크기 설정

                // 마커 크기의 최대값 설정 (픽셀 단위)
                final maxMarkerSize = 24.0;
                final finalMarkerSize = markerSize > maxMarkerSize ? maxMarkerSize : markerSize;

                return Positioned(
                  right: cellSize * 0.05,
                  top: cellSize * 0.05,
                  child: Container(
                    width: finalMarkerSize,
                    height: finalMarkerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFA500),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Text(
                          '${events.length}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
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