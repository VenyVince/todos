import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


// Todo 모델 클래스
class Todo {
  String id;
  String title;
  final DateTime date;
  String? memo;
  TimeOfDay? alarmTime;
  String? repeat;
  bool isDone;
  List<String> repeatDays;
  String userEmail;

  Todo({
    this.id = '',
    required this.title,
    required this.date,
    this.memo,
    this.alarmTime,
    this.repeat,
    this.isDone = false,
    this.repeatDays = const [],
    required this.userEmail,
  });

  // Firestore DocumentSnapshot을 기반으로 Todo 객체 생성
  factory Todo.fromMap(Map<String, dynamic> data) {
    return Todo(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      memo: data['memo'],
      isDone: data['isDone'] ?? false,
      userEmail: data['userEmail'] ?? '',
    );
  }
  // Firestore에서 가져온 데이터를 Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': Timestamp.fromDate(date),  // DateTime을 Timestamp로 변환
      'memo': memo,
      'alarmTime': alarmTime != null
          ? {'hour': alarmTime!.hour, 'minute': alarmTime!.minute}
          : null,
      'repeat': repeat,
      'isDone': isDone,
      'userEmail': userEmail,
    };
  }

  // Firestore의 데이터를 Todo 객체로 변환
  static Todo fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Todo(
      id: doc.id,
      title: data['title'],
      date: (data['date'] as Timestamp).toDate(),
      memo: data['memo'],
      alarmTime: data['alarmTime'] != null
          ? TimeOfDay(
        hour: data['alarmTime']['hour'],
        minute: data['alarmTime']['minute'],
      )
          : null,
      repeat: data['repeat'],
      isDone: data['isDone'],
      userEmail: data['userEmail'] ?? '',
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
//알림 기능 관련 입력 위젯(텍스트필드랑 슬라이더 융합해놓음)
class AlarmTimeSelector extends StatefulWidget {
  final Todo todo;
  final Function(TimeOfDay) onTimeChanged; // 콜백 추가

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
    hourController = TextEditingController(
        text: widget.todo.alarmTime?.hour.toString() ?? '0');
    minuteController = TextEditingController(
        text: widget.todo.alarmTime?.minute.toString() ?? '0');
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
                decoration: InputDecoration(
                  labelText: '시 (0-23)',
                  hintText: '0',
                ),
                onChanged: (value) {
                  int hour = int.tryParse(value) ?? -1;
                  if (hour >= 0 && hour < 24) {
                    setState(() {
                      widget.todo.alarmTime =
                          TimeOfDay(hour: hour, minute: widget.todo.alarmTime
                              ?.minute ?? 0);
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
                decoration: InputDecoration(
                  labelText: '분 (0-59)',
                  hintText: '0',
                ),
                onChanged: (value) {
                  int minute = int.tryParse(value) ?? -1;
                  if (minute >= 0 && minute < 60) {
                    setState(() {
                      widget.todo.alarmTime = TimeOfDay(hour: widget.todo
                          .alarmTime?.hour ?? 0, minute: minute);
                      widget.onTimeChanged(widget.todo.alarmTime!); // 콜백 호출
                    });
                  }
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        // 현재 설정된 알람 시간 표시
        Text(
          '현재 설정된 알람 시간: ${hourController.text} 시 ${minuteController.text} 분',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _TodoPageState extends State<TodoPage> {
  // 할 일 목록 (Firestore에서 가져온 데이터 저장)
  List<Todo> _todoList = [];
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _loadTodos(); // 앱 시작 시 Firestore에서 데이터 불러오기
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
      DocumentReference docRef = await todoCollection.add(todo.toMap());
      setState(() {
        todo.id = docRef.id; // Firestore에서 생성된 ID를 Todo에 저장
      });
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

  // 할 일 항목의 우측 버튼 구성
  Widget _buildTrailingButtons(Todo todo) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.edit, color: Colors.blue),
          onPressed: () => _showEditTitleDialog(context, todo),
        ),
        Checkbox(
          value: todo.isDone,
          onChanged: (bool? value) async {
            setState(() {
              todo.isDone = value ?? false;
            });
            await _updateTodoInFirestore(todo);
            _updateTodoList();
          },
        ),
      ],
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
      onTap: () => _selectRepeatOption(context, todo), // 반복 옵션 선택 다이얼로그 호출
      child: _buildOptionBox(
        icon: Icons.repeat,
        text: todo.repeat ?? '반복 설정',
      ),
    );
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

  // 반복 옵션 선택기
  void _selectRepeatOption(BuildContext context, Todo todo) async {
    String? selectedRepeat = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text('반복 설정'),
          children: <Widget>[
            SimpleDialogOption(child: Text('매일'), onPressed: () => Navigator.pop(context, '매일')),
            SimpleDialogOption(child: Text('매주'), onPressed: () => Navigator.pop(context, '매주')),
            SimpleDialogOption(child: Text('매월'), onPressed: () => Navigator.pop(context, '매월')),
            SimpleDialogOption(child: Text('반복 안함'), onPressed: () => Navigator.pop(context, '반복 안함')),
          ],
        );
      },
    );

    if (selectedRepeat != null) {
      setState(() {
        todo.repeat = selectedRepeat == '반복 안함' ? null : selectedRepeat;

        if (selectedRepeat == '매일') {
          todo.repeatDays = ['월', '화', '수', '목', '금', '토', '일'];
        } else if (selectedRepeat == '매주') {
          // 요일 선택 다이얼로그 호출
          _selectWeekDays(context, todo);
        } else if (selectedRepeat == '매월') {
          todo.repeatDays = [];
        } else if (selectedRepeat == '반복 안함') {
          todo.repeatDays = [];
        }
      });

      await _updateTodoInFirestore(todo); // Firestore에서 할 일 업데이트
      _updateTodoList(); // Todo 리스트 업데이트 호출
    }
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
                    await _deleteTodoFromFirestore(todo.id);
                    setState(() {
                      _todoList.remove(todo);
                    });
                    _updateTodoList();
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                ),
                if (todo.repeat != null)
                  TextButton(
                    child: Text('일정에서 전체 삭제'),
                    onPressed: () async {
                      // 데이터베이스에서 관련된 모든 일정 삭제
                      List<Todo> relatedTodos = _todoList.where((t) =>
                      t.title == todo.title &&
                          t.repeat == todo.repeat &&
                          t.alarmTime == todo.alarmTime
                      ).toList();

                      for (var relatedTodo in relatedTodos) {
                        await _deleteTodoFromFirestore(relatedTodo.id);
                      }

                      setState(() {
                        _todoList.removeWhere((t) =>
                        t.title == todo.title &&
                            t.repeat == todo.repeat &&
                            t.alarmTime == todo.alarmTime
                        );
                      });
                      _updateTodoList();
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
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
                  );

                  try {
                    await _addTodoToFirestore(newTodo);
                    setState(() {
                      _todoList.add(newTodo);
                    });
                    _updateTodoList();
                    Navigator.of(context).pop();
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


// Todo 페이지의 UI를 구성하는 build 메서드

// Todo 항목의 반복 설정 텍스트를 반환하는 함수
  String _getRepeatText(Todo todo) {
    if (todo.repeat == null) return '반복 없음';
    if (todo.repeat == '매일') return '매일';
    if (todo.repeat == '매주') {
      return '매주 ${todo.repeatDays.join(', ')}';
    }
    if (todo.repeat == '매월') return '매월';
    return '반복 없음';
  }

  void _selectWeekDays(BuildContext context, Todo todo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('요일 선택'),
              content: Wrap(
                spacing: 5,
                children: ['월', '화', '수', '목', '금', '토', '일'].map((day) {
                  return FilterChip(
                    label: Text(day),
                    selected: todo.repeatDays.contains(day),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          todo.repeatDays.add(day);
                        } else {
                          todo.repeatDays.remove(day);
                        }
                        if (todo.repeatDays.isEmpty) {
                          todo.repeatDays.add(day); // 최소 하나의 요일은 선택되도록 함
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('확인'),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _updateTodoInFirestore(todo);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  SimpleDialogOption _buildRepeatOptionDialog(String option) {
    return SimpleDialogOption(
      onPressed: () {
        Navigator.pop(context, option);
      },
      child: Text(option),
    );
  }
}
