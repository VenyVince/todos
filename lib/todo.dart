import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:table_calendar/table_calendar.dart';

class RepeatTypes {
  static const String daily = 'Daily';
  static const String weekly = 'Weekly';
  static const String monthly = 'Monthly';
  static const String yearly = 'Yearly';
  static const List<String> all = [daily, weekly, monthly, yearly];
}

// Todo 모델 클래스
class Todo {
  String id;
  String title;
  final DateTime date;
  String? memo;
  TimeOfDay? alarmTime;
  String repeatType;
  DateTime nextDate;
  bool isDone;
  String userEmail;

  Todo({
    this.id = '',
    required this.title,
    required this.date,
    this.memo,
    this.alarmTime,
    required this.repeatType,
    required this.nextDate,
    this.isDone = false,
    required this.userEmail,
  });

  Todo copyWith({
    String? title,
    DateTime? date,
    String? memo,
    TimeOfDay? alarmTime,
    String? repeatType,
    DateTime? nextDate,
    bool? isDone,
    String? userEmail,
  }) {
    return Todo(
      title: title ?? this.title,
      date: date ?? this.date,
      repeatType: repeatType ?? this.repeatType,
      nextDate: nextDate ?? this.nextDate,
      isDone: isDone ?? this.isDone,
      memo: memo ?? this.memo,
      alarmTime: alarmTime ?? this.alarmTime,
      userEmail: userEmail ?? this.userEmail,
    );
  }

  factory Todo.fromMap(String id, Map<String, dynamic> map) {
    return Todo(
      id: id,
      title: map['title'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      memo: map['memo'] ?? '',
      repeatType: map['repeatType'] ?? RepeatTypes.daily,
      nextDate: DateTime.parse(map['nextDate']),
      isDone: map['isDone'] ?? false,
      userEmail: map['userEmail'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': Timestamp.fromDate(date),
      'memo': memo,
      'alarmTime': alarmTime != null
          ? {'hour': alarmTime!.hour, 'minute': alarmTime!.minute}
          : null,
      'repeatType': repeatType,
      'nextDate': nextDate.toIso8601String(),
      'isDone': isDone,
      'userEmail': userEmail,
    };
  }

  DateTime getNextDate() {
    switch (repeatType) {
      case RepeatTypes.daily:
        return nextDate.add(Duration(days: 1));
      case RepeatTypes.weekly:
        return nextDate.add(Duration(days: 7));
      case RepeatTypes.monthly:
        try {
          return DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
        } catch (e) {
          return DateTime(nextDate.year, nextDate.month + 1, 0);
        }
      case RepeatTypes.yearly:
        return DateTime(nextDate.year + 1, nextDate.month, nextDate.day);
      default:
        throw Exception('Unknown repeat type');
    }
  }

  static Todo fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Todo(
      id: doc.id,
      title: data['title'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      memo: data['memo'] ?? '',
      alarmTime: data['alarmTime'] != null
          ? TimeOfDay(
          hour: data['alarmTime']['hour'] ?? 0,
          minute: data['alarmTime']['minute'] ?? 0)
          : null,
      repeatType: data['repeatType'] ?? RepeatTypes.daily,
      nextDate: DateTime.parse(data['nextDate']),
      isDone: data['isDone'] ?? false,
      userEmail: data['userEmail'] ?? '',
    );
  }
}

// Firestore 서비스 클래스
class FirestoreService {
  final CollectionReference todosCollection =
  FirebaseFirestore.instance.collection('todos');

  Future<void> addTodo(Todo todo) async {
    await todosCollection.add(todo.toMap());

    if (todo.repeatType.isNotEmpty) {
      DateTime nextDate = todo.getNextDate();
      Todo nextTodo = todo.copyWith(nextDate: nextDate, isDone: false);
      await todosCollection.add(nextTodo.toMap());
    }
  }

  Stream<List<Todo>> getTodos() {
    return todosCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Todo.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  Future<void> updateTodo(Todo todo) async {
    await todosCollection.doc(todo.id).update(todo.toMap());

    if (todo.repeatType.isNotEmpty) {
      DateTime nextDate = todo.getNextDate();
      Todo nextTodo = todo.copyWith(nextDate: nextDate, isDone: false);
      await todosCollection.add(nextTodo.toMap());
    }
  }

  Future<void> deleteTodo(String id) async {
    await todosCollection.doc(id).delete();
  }
}

// 알람 시간 선택 위젯
class AlarmTimeSelector extends StatefulWidget {
  final Todo todo;
  final Function(TimeOfDay) onTimeChanged;

  AlarmTimeSelector({required this.todo, required this.onTimeChanged});

  @override
  _AlarmTimeSelectorState createState() => _AlarmTimeSelectorState();
}

class _AlarmTimeSelectorState extends State<AlarmTimeSelector> {
  late TextEditingController hourController;
  late TextEditingController minuteController;

  @override
  void initState() {
    super.initState();
    hourController = TextEditingController(text: widget.todo.alarmTime?.hour.toString() ?? '0');
    minuteController = TextEditingController(text: widget.todo.alarmTime?.minute.toString() ?? '0');
  }

  @override
  void dispose() {
    hourController.dispose();
    minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                maxLength: 2,
                decoration: InputDecoration(labelText: '시 (0-23)', hintText: '0'),
                onChanged: (value) {
                  int hour = int.tryParse(value) ?? -1;
                  if (hour >= 0 && hour < 24) {
                    setState(() {
                      widget.todo.alarmTime = TimeOfDay(hour: hour, minute: widget.todo.alarmTime?.minute ?? 0);
                      widget.onTimeChanged(widget.todo.alarmTime!);
                    });
                  }
                },
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                maxLength: 2,
                decoration: InputDecoration(labelText: '분 (0-59)', hintText: '0'),
                onChanged: (value) {
                  int minute = int.tryParse(value) ?? -1;
                  if (minute >= 0 && minute < 60) {
                    setState(() {
                      widget.todo.alarmTime = TimeOfDay(hour: widget.todo.alarmTime?.hour ?? 0, minute: minute);
                      widget.onTimeChanged(widget.todo.alarmTime!);
                    });
                  }
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Text('현재 설정된 알람 시간: ${hourController.text} 시 ${minuteController.text} 분', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class TodoPage extends StatefulWidget {
  final DateTime selectedDate;
  final Function(Todo) onTodoAdded;
  final Function(Todo) onTodoRemoved;
  final Function(List<Todo>) onTodoListChanged; // 할 일 목록 변경 콜백
  final String userEmail;

  TodoPage({
    required this.selectedDate,
    required this.onTodoAdded,
    required this.onTodoRemoved,
    required this.onTodoListChanged,
    required this.userEmail,
  });

  @override
  _TodoPageState createState() => _TodoPageState();
}


class _TodoPageState extends State<TodoPage> {
  // 할 일 목록 (Firestore에서 가져온 데이터 저장)
  List<Todo> _todoList = [];
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _loadTodos(); // Firestore에서 데이터 불러오기
  }

  // 알람 시간 선택 다이얼로그
  Future<void> _showAlarmSettingDialog(Todo todo) async {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('알람 시간 설정'),
          content: AlarmTimeSelector(
            todo: todo,
            onTimeChanged: (newTime) {
              setState(() {
                todo.alarmTime = newTime;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }

  void _updateTodoList() {
    widget.onTodoListChanged(_todoList);
    setState(() {});
  }
  // firebase에 변경사항 반영
  Future<void> _updateTodoInFirestore(Todo todo) async {
    final todoCollection = FirebaseFirestore.instance.collection('todos');
    try {
      await todoCollection.doc(todo.id).update(todo.toMap());
    } catch (e) {
      print("Error updating todo: $e");
    }
  }

  // Firestore에서 할 일 목록 읽기
  Future<void> _loadTodos() async {
    final todoCollection = FirebaseFirestore.instance.collection('todos');
    QuerySnapshot snapshot = await todoCollection
        .where('userEmail', isEqualTo: widget.userEmail) // 현재 사용자의 Todo 가져오기
        .get();
    setState(() {
      _todoList = snapshot.docs
          .map((doc) => Todo.fromFirestore(doc))  // Firestore 데이터 Todo 객체로 변환
          .toList();
      _updateTodoList();
    });
    widget.onTodoListChanged(_todoList);
  }

  // Firestore에 할 일 추가
  Future<void> _addTodoToFirestore(Todo todo) async {
    final todoCollection = FirebaseFirestore.instance.collection('todos');
    try {
      // Firestore에 할 일 추가
      DocumentReference docRef = await todoCollection.add(todo.toMap());
      // Firestore에서 생성된 ID를 Todo에 저장
      setState(() {
        todo.id = docRef.id;
      });
      // 반복 유형에 따라 다음 할 일 생성
      if (todo.repeatType.isNotEmpty) {
        DateTime nextDate = todo.getNextDate();
        Todo nextTodo = todo.copyWith(nextDate: nextDate, isDone: false);
        await todoCollection.add(nextTodo.toMap()); // 다음 발생의 todo 추가
      }
    } catch (e) {
      print("Error adding todo: $e");
    }
  }

  // Firestore에서 할 일 삭제
  Future<void> _deleteTodoFromFirestore(String todoId) async {
    final todoCollection = FirebaseFirestore.instance.collection('todos');
    try {
      await todoCollection.doc(todoId).delete();
    } catch (e) {

      print("Error deleting todo: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTodoList = _todoList.where((todo) =>
        isSameDay(todo.date, widget.selectedDate)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Todo'),
      ),
      body: ListView.builder(
        itemCount: filteredTodoList.length,
        itemBuilder: (context, index) {
          final todo = filteredTodoList[index];
          return ListTile(
            title: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                todo.title,
                style: TextStyle(
                  decoration: todo.isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditTitleDialog(context, todo), // 수정 다이얼로그 호출
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    // 삭제 확인 다이얼로그
                    bool? confirmDelete = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('삭제 확인'),
                        content: Text('${todo.title}을(를) 삭제하시겠습니까?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false), // 취소
                            child: Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true), // 삭제
                            child: Text('삭제'),
                          ),
                        ],
                      ),
                    );

                    if (confirmDelete == true) {
                      setState(() {
                        _todoList.remove(todo);
                      });
                      widget.onTodoRemoved(todo);
                      await _deleteTodoFromFirestore(todo.id);
                      _updateTodoList();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${todo.title} 삭제됨')),
                      );
                    }
                  },
                ),
              ],
            ),
            onTap: () => _showTodoDetails(context, todo),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNewTodoDialog(),
        child: Icon(Icons.add),
      ),
    );
  }


  // 제목 수정 다이얼로그
  void _showEditTitleDialog(BuildContext context, Todo todo) {
    TextEditingController _controller = TextEditingController(text: todo.title);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('타이틀 수정'),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(hintText: '새로운 타이틀'),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('취소'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('수정'),
              onPressed: () {
                setState(() {
                  todo.title = _controller.text;
                });
                _updateTodoList();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // 할 일 상세 보기
  void _showTodoDetails(BuildContext context, Todo todo) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.5,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(todo.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              _buildMemoField(todo), // 메모 필드
              SizedBox(height: 10),
              _buildAlarmAndRepeatRow(todo), // 알람 및 반복 설정 UI를 행으로 묶기
              SizedBox(height: 20),
              _buildCompletionButton(todo), // 완료 버튼
              Divider(),
              _buildDeleteButton(todo), // 삭제 버튼
            ],
          ),
        ),
      ),
    );
  }
  //반복설정 ui
  Future<void> _showRepeatSettingDialog(Todo todo) async {
    String selectedRepeat = todo.repeatType; // 반복 유형을 Todo에서 가져옴

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('반복 설정'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 반복 주기 선택
                  DropdownButton<String>(
                    value: selectedRepeat,
                    items: RepeatTypes.all.map((option) => DropdownMenuItem(
                      value: option,
                      child: Text(option),
                    )).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedRepeat = value!;
                      });
                    },
                  ),
                  SizedBox(height: 10),
                  Text("현재 선택된 반복 유형: $selectedRepeat"), // 현재 선택된 반복 정보 표시
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), // 취소 버튼
                  child: Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      todo.repeatType = selectedRepeat; // 선택된 반복 유형 저장
                    });
                    Navigator.pop(context); // 다이얼로그 닫기
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



// 알람 및 반복 설정을 위한 행 위젯
  Widget _buildAlarmAndRepeatRow(Todo todo) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // 공간을 균등하게 분배
      children: [
        Expanded(child: _buildAlarmButton(todo)), // 알람 설정 버튼
        SizedBox(width: 10), // 버튼 사이의 간격
        Expanded(child: _buildRepeatButton(todo)), // 반복 설정 버튼
      ],
    );
  }

// 알림 설정 버튼 위젯
  Widget _buildAlarmButton(Todo todo) {
    return GestureDetector(
      onTap: () => _showAlarmSettingDialog(todo), // 알람 시간 설정 다이얼로그 호출
      child: _buildOptionBox(
        icon: Icons.alarm,
        text: todo.alarmTime != null
            ? '${todo.alarmTime!.hour}:${todo.alarmTime!.minute.toString().padLeft(2, '0')}'
            : '알람 시간',
      ),
    );
  }

// 반복 설정 버튼 위젯
  Widget _buildRepeatButton(Todo todo) {
    return GestureDetector(
      onTap: () => _showRepeatSettingDialog(todo), // 반복 옵션 선택 다이얼로그 호출
      child: _buildOptionBox(
        icon: Icons.repeat,
        text: todo.repeatType, // 반복 유형 표시
      ),
    );
  }

// 반복 설정 데이터를 반환하는 메서드
  dynamic getRepeatSettings(Todo todo) {
    if (todo.repeatType == RepeatTypes.weekly) {
      // 매주 반복하는 요일들 반환 (이 부분은 필요에 따라 추가적으로 구현)
      return "매주: ${todo.nextDate}"; // 예시로 다음 날짜 반환
    } else if (todo.repeatType == RepeatTypes.daily) {
      // 매일 반복하는 경우 오늘부터 1년간의 날짜 리스트 생성
      List<DateTime> dailyDates = [];
      DateTime currentDate = DateTime.now();
      for (int i = 0; i < 365; i++) {
        dailyDates.add(currentDate.add(Duration(days: i)));
      }
      return dailyDates; // 예시로 날짜 리스트 반환
    } else if (todo.repeatType == RepeatTypes.monthly) {
      DateTime currentDate = DateTime.now();
      return [DateTime(currentDate.year, currentDate.month, currentDate.day)];
    }
    return null; // 반복 없음일 경우 null 반환
  }


// 옵션 박스 스타일링 함수
  Widget _buildOptionBox({required IconData icon, required String text}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.blue),
          SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }



  // 메모 입력 필드
  Widget _buildMemoField(Todo todo) {
    return TextFormField(
      initialValue: todo.memo,
      onChanged: (value) => setState(() {
        todo.memo = value.trim().isEmpty ? null : value;
        _updateTodoList();
      }),
      decoration: InputDecoration(
        hintText: todo.memo?.isEmpty ?? true ? '메모' : '',
        hintStyle: TextStyle(color: Colors.grey),
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
      maxLines: 3,
    );
  }

  // 완료 버튼
  Widget _buildCompletionButton(Todo todo) {
    return ElevatedButton(
      onPressed: () async{
        setState(() {
          todo.isDone = !todo.isDone;
        });
        await _updateTodoInFirestore(todo);
        Navigator.pop(context);
      },
      child: Text(todo.isDone ? '완료 취소' : '완료하기'),
    );
  }

  // 할 일 삭제 버튼
  Widget _buildDeleteButton(Todo todo) {
    return ElevatedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('할 일 삭제'),
              content: Text('삭제하시겠습니까?'),
              actions: [
                TextButton(
                  child: Text('취소'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text('삭제'),
                  onPressed: () async {
                    await _deleteTodoFromFirestore(todo.id); // Firestore에서 할 일 삭제
                    setState(() {
                      _todoList.remove(todo); // 로컬 리스트에서 제거
                    });
                    _updateTodoList(); // Todo 목록 업데이트
                    Navigator.of(context).pop(); // 다이얼로그 닫기
                  },
                ),
                if (todo.repeatType.isNotEmpty) // 반복 유형이 있을 경우
                  TextButton(
                    child: Text('일정에서 전체 삭제'),
                    onPressed: () async {
                      // 데이터베이스에서 관련된 모든 일정 삭제
                      List<Todo> relatedTodos = _todoList.where((t) =>
                      t.title == todo.title &&
                          t.repeatType == todo.repeatType &&
                          t.alarmTime == todo.alarmTime
                      ).toList();

                      for (var relatedTodo in relatedTodos) {
                        await _deleteTodoFromFirestore(relatedTodo.id); // 관련된 Todo 삭제
                      }

                      setState(() {
                        _todoList.removeWhere((t) =>
                        t.title == todo.title &&
                            t.repeatType == todo.repeatType &&
                            t.alarmTime == todo.alarmTime
                        ); // 로컬 리스트에서 관련 Todo 제거
                      });
                      _updateTodoList(); // Todo 목록 업데이트
                      Navigator.of(context).pop(); // 다이얼로그 닫기
                    },
                  ),
              ],
            );
          },
        );
      },
      icon: Icon(Icons.delete, color: Colors.red),
      label: Text('삭제'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.withOpacity(0.8),
      ),
    );
  }

  // 새 할 일 추가 다이얼로그
  // 새 할 일 추가 다이얼로그
  void _addNewTodoDialog() {
    TextEditingController _controller = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('새 할 일 추가'),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(hintText: '할 일 제목'),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('취소'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('추가'),
              onPressed: () async {
                String title = _controller.text.trim();

                if (title.isNotEmpty) {
                  Todo newTodo = Todo(
                    title: title,
                    date: widget.selectedDate,
                    userEmail: widget.userEmail,
                    repeatType: RepeatTypes.daily, // 기본 반복 유형 설정 (필요에 따라 조정)
                    nextDate: DateTime.now(), // 다음 날짜 초기화 (필요에 따라 조정)
                  );

                  try {
                    await _addTodoToFirestore(newTodo);
                    setState(() {
                      _todoList.add(newTodo); // 새 Todo를 로컬 리스트에 추가
                    });
                    _updateTodoList(); // Todo 목록 업데이트
                    Navigator.of(context).pop(); // 다이얼로그 닫기
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('오류가 발생했습니다: $e'))
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('할 일 제목을 입력해주세요!'))
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month &&
        date1.day == date2.day;
  }
}
