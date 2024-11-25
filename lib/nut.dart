import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material; // DateUtils 사용을 위한 import

// 영양제 정보를 저장하는 클래스
class Nutrition {
  String id; // 추가된 부분
  String name; // 영양제 이름
  int totalDosage; // 총 복용량 (mg)
  int count; // 섭취 개수
  double takenDosage; // 현재 복용량 (mg)
  DateTime date; // 날짜
  bool taken; // 전체 복용 여부
  Map<String, double> takenDosageByDate; // 날짜별 섭취량
  String userEmail; // 사용자 이메일
  List<int> repeatDays; // 반복 설정 (0: 월요일, ... 6: 일요일)

  Nutrition({
    required this.name,
    required this.totalDosage,
    required this.count,
    required this.userEmail,
    this.takenDosage = 0,
    this.repeatDays = const [], // 기본값: 반복 없음
    Map<String, double>? takenDosageByDate,
  }) : this.takenDosageByDate = takenDosageByDate ?? {};

  // 1개당 복용량 계산 (소수점 포함)
  double get dosagePerCount => totalDosage / count;

  factory Nutrition.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Nutrition(
      id: doc.id,
      name: data['name'],
      totalDosage: data['totalDosage'],
      count: data['count'],
      userEmail: data['userEmail'],
      repeatDays: List<int>.from(data['repeatDays'] ?? []),
      takenDosageByDate: Map<String, double>.from(data['takenDosageByDate'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'totalDosage': totalDosage,
      'count': count,
      'userEmail': userEmail,
      'repeatDays': repeatDays,
      'takenDosageByDate': takenDosageByDate,
    };
  }
}

// 영양제 페이지 위젯
class NutPage extends StatefulWidget {
  final DateTime selectedDate; // 선택된 날짜
  final Function(Nutrition) onNutritionAdded; // 영양제 추가 콜백
  final Function(Nutrition) onNutritionRemoved; // 영양제 삭제 콜백
  final String userEmail; // 사용자 이메일

  NutPage({
    required this.selectedDate,
    required this.onNutritionAdded,
    required this.onNutritionRemoved,
    required this.userEmail, // 추가된 부분
  });

  @override
  _NutPageState createState() => _NutPageState();
}

// 영양제 페이지 위젯
class NutPage extends StatefulWidget {
  final DateTime selectedDate; // 선택된 날짜
  final Function(Nutrition) onNutritionAdded; // 영양제 추가 콜백
  final Function(Nutrition) onNutritionRemoved; // 영양제 삭제 콜백
  final String userEmail; // 사용자 이메일

  NutPage({
    required this.selectedDate,
    required this.onNutritionAdded,
    required this.onNutritionRemoved,
    required this.userEmail,
  });

  @override
  _NutPageState createState() => _NutPageState();
}

// 영양제 페이지의 상태를 관리하는 클래스
class _NutPageState extends State<NutPage> {
  List<Nutrition> _nutritions = []; // 영양제 목록
  final TextEditingController _nutritionController = TextEditingController(); // 영양제 이름 입력 컨트롤러
  final TextEditingController _dosageController = TextEditingController(); // 총 복용량 입력 컨트롤러
  final TextEditingController _countController = TextEditingController(); // 섭취 개수 입력 컨트롤러
  final List<bool> _selectedDays = List.filled(7, false); // 월~일 선택 상태 저장

  @override
  void initState() {
    super.initState();
    _loadNutritions();
  }

  Future<void> _loadNutritions() async {
    final nutritionCollection = FirebaseFirestore.instance.collection('nutritions');
    QuerySnapshot snapshot = await nutritionCollection.where('userEmail', isEqualTo: widget.userEmail).get();

    setState(() {
      _nutritions = snapshot.docs.map((doc) => Nutrition.fromFirestore(doc)).toList();
    });
  }

  Future<void> _addNutritionToFirestore(Nutrition nutrition) async {
    final nutritionCollection = FirebaseFirestore.instance.collection('nutritions');

    try {
      DocumentReference docRef = await nutritionCollection.add(nutrition.toMap());
      setState(() {
        nutrition.id = docRef.id;
        _nutritions.add(nutrition);
      });
    } catch (e) {
      print("Error adding nutrition: $e");
    }
  }

  Future<void> _deleteNutritionFromFirestore(String nutritionId) async {
    final nutritionCollection = FirebaseFirestore.instance.collection('nutritions');

    try {
      await nutritionCollection.doc(nutritionId).delete();
      setState(() {
        _nutritions.removeWhere((nutrition) => nutrition.id == nutritionId);
      });
    } catch (e) {
      print("Error deleting nutrition: $e");
    }
  }

  Future<void> _updateNutritionInFirestore(Nutrition nutrition) async {
    final nutritionCollection = FirebaseFirestore.instance.collection('nutritions');

    try {
      await nutritionCollection.doc(nutrition.id).update(nutrition.toMap());
    } catch (e) {
      print("Error updating nutrition: $e");
    }
  }

  List<Nutrition> _filterNutritionsForToday() {
    final today = widget.selectedDate.weekday - 1; // DateTime.weekday: 월요일=1, 일요일=7
    return _nutritions.where((nutrition) {
      return nutrition.repeatDays.contains(today) || nutrition.repeatDays.isEmpty;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // 선택된 날짜에 해당하는 영양제 필터링
    final filteredNutritions = _nutritions.where((nutrition) =>
        material.DateUtils.isSameDay(nutrition.date, widget.selectedDate)).toList();
    double percentage = _calculatePercentage(filteredNutritions); // 섭취율 계산

    final filteredNutritions = _filterNutritionsForToday();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '오늘의 영양제 섭취율: ${percentage.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredNutritions.length,
              itemBuilder: (context, index) {
                return _buildNutritionItem(filteredNutritions[index]); // 영양제 항목 표시
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddNutritionDialog, // 새 영양제 추가 다이얼로그 표시
        child: Icon(Icons.add),
      ),
    );
  }

  // 각 영양제 항목을 표시하는 위젯 생성
  Widget _buildNutritionItem(Nutrition nutrition) {
    double percentage = (nutrition.takenDosage / nutrition.totalDosage) * 100; // 섭취 비율 계산

    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        setState(() {
          _nutritions.remove(nutrition); // 스와이프 시 영양제 삭제
        });
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20),
        color: Colors.red,
        child: Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nutrition.name,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                '${nutrition.takenDosage.toStringAsFixed(2)}/${nutrition.totalDosage} mg (${nutrition.count}개 중 ${(nutrition.takenDosage / nutrition.dosagePerCount).toStringAsFixed(2)}개 복용)',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 4),
              LinearProgressIndicator(
                value: nutrition.takenDosage / nutrition.totalDosage,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              SizedBox(height: 2),
              Text(
                '${percentage.toStringAsFixed(1)}% 복용',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => _takeDosage(nutrition), // 복용 버튼 클릭 시
                        child: Icon(Icons.add), // + 아이콘
                        style: ElevatedButton.styleFrom(
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(12),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _removeDosage(nutrition), // 취소 버튼 클릭 시
                        child: Icon(Icons.remove), // - 아이콘
                        style: ElevatedButton.styleFrom(
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
  onPressed: () => _showNutritionDetails(context, nutrition), // 상세정보 버튼 클릭 시
  child: Text('상세정보'),
),
IconButton(
  icon: Icon(Icons.edit),
  onPressed: () => _showEditNutritionDialog(nutrition),
),
],
),
),
);
}

// 영양제 상세 정보를 표시하는 바텀 시트
void _showNutritionDetails(BuildContext context, Nutrition nutrition) {
  showModalBottomSheet(
    context: context,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    isScrollControlled: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.6,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nutrition.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('총 복용량 : ${nutrition.totalDosage} mg'),
            Text('섭취 개수 : ${nutrition.count}개'),
            Text('1개당 복용량 : ${nutrition.dosagePerCount.toStringAsFixed(2)} mg'),
            Text('현재 복용량 : ${nutrition.takenDosage.toStringAsFixed(2)} mg'),
            Text('복용한 개수 : ${(nutrition.takenDosage / nutrition.dosagePerCount).toStringAsFixed(2)}개'),
            SizedBox(height: 20),
            LinearProgressIndicator(
              value: nutrition.takenDosage / nutrition.totalDosage,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            SizedBox(height: 10),
            Text('${((nutrition.takenDosage / nutrition.totalDosage) * 100).toStringAsFixed(1)}% 복용',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _takeDosage(nutrition);
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.add), // + 아이콘
                  label: Text('1개 복용'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _removeDosage(nutrition);
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.remove), // - 아이콘
                  label: Text('1개 취소'),
                ),
              ],
            ),
            Divider(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _nutritions.remove(nutrition); // 영양제 삭제
                });
                Navigator.pop(context);
              },
              icon: Icon(Icons.delete, color: Colors.white),
              label: Text('삭제'),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
      ),
    ),
  );
}

// 새 영양제를 추가하는 다이얼로그를 표시하는 메서드
void _showAddNutritionDialog() {
  _nutritionController.clear();
  _dosageController.clear();
  _countController.clear();
  _selectedDays.fillRange(0, _selectedDays.length, false);

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("새 영양제 추가"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nutritionController,
              decoration: InputDecoration(labelText: "영양제 이름"),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _dosageController,
              decoration: InputDecoration(labelText: "총 복용량 (mg)"),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _countController,
              decoration: InputDecoration(labelText: "섭취 개수"),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 10),
            Text('반복 설정 (요일 선택)', style: TextStyle(fontSize: 16)),
            Wrap(
              children: List.generate(7, (index) {
                return ChoiceChip(
                  label: Text(['월', '화', '수', '목', '금', '토', '일'][index]),
                  selected: _selectedDays[index],
                  onSelected: (bool selected) {
                    setState(() {
                      _selectedDays[index] = selected;
                    });
                  },
                );
              }),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("취소"),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _nutritionController.text;
              final totalDosage = int.tryParse(_dosageController.text) ?? 0;
              final count = int.tryParse(_countController.text) ?? 0;

              if (name.isNotEmpty && totalDosage > 0 && count > 0) {
                final newNutrition = Nutrition(
                  name: name,
                  totalDosage: totalDosage,
                  count: count,
                  userEmail: widget.userEmail,
                  repeatDays:
                      List.generate(7, (index) => _selectedDays[index] ? index : -1).where((day) => day != -1).toList(),
                );
                _addNutritionToFirestore(newNutrition);
                Navigator.pop(context);
              }
            },
            child: Text("추가"),
          ),
        ],
      );
    },
  );
}

// 영양제 상세 정보를 표시하는 바텀 시트
void _showNutritionDetails(BuildContext context, Nutrition nutrition) {
  showModalBottomSheet(
    context : context,
    shape : RoundedRectangleBorder(borderRadius : BorderRadius.vertical(top : Radius.circular(20))),
    isScrollControlled : true,
    builder : (context) => FractionallySizedBox(
      heightFactor :0.6,
      child : Padding(
        padding : const EdgeInsets.all(20.0),
        child : Column(
          crossAxisAlignment : CrossAxisAlignment.start,
          children : [
            Text(nutrition.name, style : TextStyle(fontSize :24, fontWeight : FontWeight.bold)),
            SizedBox(height :10),
            Text('총 복용량 : ${nutrition.totalDosage} mg'),
            Text('섭취 개수 : ${nutrition.count}개'),
            Text('1개당 복용량 : ${nutrition.dosagePerCount.toStringAsFixed(2)} mg'),
            Text('현재 복용량 : ${nutrition.takenDosage.toStringAsFixed(2)} mg'),
            Text('복용한 개수 : ${(nutrition.takenDosage / nutrition.dosagePerCount).toStringAsFixed(2)}개'),
            SizedBox(height :20),
            LinearProgressIndicator(
              value : nutrition.takenDosage / nutrition.totalDosage,
              backgroundColor : Colors.grey[200],
              valueColor : AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            SizedBox(height :10),
            Text('${((nutrition.takenDosage / nutrition.totalDosage) *100).toStringAsFixed(1)}% 복용',
                style :TextStyle(fontSize :16, fontWeight : FontWeight.bold)),
            SizedBox(height :20),
            Row (
              mainAxisAlignment : MainAxisAlignment.spaceEvenly,
              children : [
                ElevatedButton.icon (
                  onPressed :() {
                    _takeDosage(nutrition);
                    Navigator.pop(context);
                  },
                  icon : Icon(Icons.add), // + 아이콘
                  label :Text('1개 복용'),
                ),
                ElevatedButton.icon (
                  onPressed :() {
                    _removeDosage(nutrition);
                    Navigator.pop(context);
                  },
                  icon : Icon(Icons.remove), // - 아이콘
                  label :Text('1개 취소'),
                ),
              ],
            ),
            Divider(height :30),
            ElevatedButton.icon (
              onPressed :(){
                setState(() {
                  _nutritions.remove(nutrition); // 영양제 삭제
                });
                Navigator.pop(context);
              },
              icon : Icon(Icons.delete, color : Colors.white),
              label :Text('삭제'),
              style :
              ElevatedButton.styleFrom(backgroundColor :
              Colors.red),
            ),
          ],
        ),
      ),
    ),
  );
}