import 'package:flutter/material.dart';

class Todo {
  String title;
  final DateTime date;
  String? memo;
  TimeOfDay? alarmTime;
  String? repeat;
  bool isDone;

  Todo({
    required this.title,
    required this.date,
    this.memo,
    this.alarmTime,
    this.repeat,
    this.isDone = false,
  });
}

//원본
//class TodoPage extends StatefulWidget {
  //final DateTime selectedDate;

  //TodoPage({required this.selectedDate});

//콜백을 받아들이도록 수정
class TodoPage extends StatefulWidget {
  final DateTime selectedDate;
  final Function(Todo) onTodoAdded;
  final Function(Todo) onTodoRemoved;

  TodoPage({
    required this.selectedDate,
    required this.onTodoAdded,
    required this.onTodoRemoved,
  });


  @override
  _TodoPageState createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  // 초기 할 일 리스트
  final List<Todo> _todoList = [];

  @override
  Widget build(BuildContext context) {
    final filteredTodoList = _todoList.where((todo) => isSameDay(todo.date, widget.selectedDate)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Todo'),
      ),
      body: ListView.builder(
        itemCount: filteredTodoList.length,
        itemBuilder: (context, index) {
          final todo = filteredTodoList[index];
          return Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) {
              setState(() {
                _todoList.remove(todo);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${todo.title} 삭제됨')),
              );
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: EdgeInsets.symmetric(horizontal: 20),
              color: Colors.red,
              child: Icon(Icons.delete, color: Colors.white),
            ),
            child: ListTile(
              title: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  todo.title,
                  style: TextStyle(
                    decoration: todo.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              trailing: _buildTrailingButtons(todo),
              onTap: () => _showTodoDetails(context, todo),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNewTodoDialog(),
        child: Icon(Icons.add),
      ),
    );
  }


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
          onChanged: (bool? value) {
            setState(() {
              todo.isDone = value ?? false;
            });
          },
        ),
      ],
    );
  }

  // 할 일 수정
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
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // 할 일 상세보기
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
              _buildMemoField(todo),
              SizedBox(height: 10),
              _buildAlarmAndRepeatRow(todo),
              SizedBox(height: 20),
              _buildCompletionButton(todo),
              Divider(),
              _buildDeleteButton(todo),
            ],
          ),
        ),
      ),
    );
  }

  // 메모 입력 필드
  Widget _buildMemoField(Todo todo) {
    return TextFormField(
      initialValue: todo.memo,
      onChanged: (value) => setState(() {
        todo.memo = value.trim().isEmpty ? null : value;
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

  // 알람 시간 및 반복 설정 옵션
  Widget _buildAlarmAndRepeatRow(Todo todo) {
    return Row(
      children: [
        _buildAlarmOption(todo),
        SizedBox(width: 10),
        _buildRepeatOption(todo),
      ],
    );
  }

  // 알람 시간 선택
  Widget _buildAlarmOption(Todo todo) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectAlarmTime(context, todo),
        child: _buildOptionBox(
          icon: Icons.alarm,
          text: todo.alarmTime != null
              ? '${todo.alarmTime!.hour}:${todo.alarmTime!.minute}'
              : '알림 없음',
        ),
      ),
    );
  }

  // 반복 설정 선택
  Widget _buildRepeatOption(Todo todo) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectRepeatOption(context, todo),
        child: _buildOptionBox(
          icon: Icons.autorenew,
          text: todo.repeat ?? '반복 없음',
        ),
      ),
    );
  }

  // 공통 옵션 박스 위젯
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

  // 할 일 완료/취소 버튼
  Widget _buildCompletionButton(Todo todo) {
    return ElevatedButton.icon(
      onPressed: () {
        setState(() {
          todo.isDone = !todo.isDone;
        });
        Navigator.pop(context);
      },
      icon: Icon(todo.isDone ? Icons.check_circle : Icons.circle_outlined),
      label: Text(todo.isDone ? '완료 취소' : '완료로 표시'),
    );
  }

  // 삭제 버튼
  Widget _buildDeleteButton(Todo todo) {
    return ElevatedButton.icon(
      onPressed: () {
        setState(() {
          _todoList.remove(todo);
        });
        Navigator.pop(context);
      },
      icon: Icon(Icons.delete, color: Colors.red),
      label: Text('삭제'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.withOpacity(0.8),
      ),
    );
  }

  // 알람 시간 선택
  void _selectAlarmTime(BuildContext context, Todo todo) async {
    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: todo.alarmTime ?? TimeOfDay.now(),
    );

    if (selectedTime != null) {
      setState(() {
        todo.alarmTime = selectedTime;
      });
    }
  }

  // 반복 설정 선택
  void _selectRepeatOption(BuildContext context, Todo todo) async {
    String? selectedRepeat = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text('반복 설정'),
          children: <Widget>[
            _buildRepeatOptionDialog('매일'),
            _buildRepeatOptionDialog('매주'),
            _buildRepeatOptionDialog('매년'),
            _buildRepeatOptionDialog('반복 안함'),
            _buildRepeatOptionDialog('사용자화'),
          ],
        );
      },
    );

    if (selectedRepeat != null) {
      setState(() {
        todo.repeat = selectedRepeat;
      });
    }
  }

  // 반복 설정 옵션 다이얼로그 항목
  SimpleDialogOption _buildRepeatOptionDialog(String option) {
    return SimpleDialogOption(
      onPressed: () {
        Navigator.pop(context, option);
      },
      child: Text(option),
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
              onPressed: () {
                setState(() {
                  _todoList.add(Todo(
                    title: _controller.text,
                    date: widget.selectedDate,
                  ));
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

// 두 날짜가 동일한 날짜인지 확인하는 함수
bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
