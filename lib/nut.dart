import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Nutrition {
  String id;
  String name;
  int totalDosage;
  int count;
  double takenDosage;
  DateTime date;
  bool taken;
  String userEmail;


  Nutrition({
    this.id = '',
    required this.name,
    required this.totalDosage,
    required this.count,
    required this.date,
    this.takenDosage = 0,
    this.taken = false,
    required this.userEmail,
  });
  factory Nutrition.fromMap(Map<String, dynamic> data) {
    return Nutrition(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      totalDosage: data['totalDosage'] ?? 0,
      count: data['count'] ?? 0,
      userEmail: data['userEmail'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
    );
  }
  double get dosagePerCount => totalDosage / count;

  void updateTaken() {
    taken = takenDosage >= totalDosage;
  }

  factory Nutrition.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Nutrition(
      id: doc.id,
      name: data['name'],
      totalDosage: data['totalDosage'],
      count: data['count'],
      date: (data['date'] as Timestamp).toDate(),
      takenDosage: data['takenDosage'].toDouble(),
      taken: data['taken'],
      userEmail: data['userEmail'],

    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'totalDosage': totalDosage,
      'count': count,
      'takenDosage': takenDosage,
      'date': date,
      'taken': taken,
      'userEmail': userEmail,
    };
  }
}

class NutPage extends StatefulWidget {
  final DateTime selectedDate;
  final Function(Nutrition) onNutritionAdded;
  final Function(Nutrition) onNutritionRemoved;
  final String userEmail;

  NutPage({
    required this.selectedDate,
    required this.onNutritionAdded,
    required this.onNutritionRemoved,
    required this.userEmail,
  });

  @override
  _NutPageState createState() => _NutPageState();
}

class _NutPageState extends State<NutPage> {
  List<Nutrition> _nutritions = [];
  final TextEditingController _nutritionController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _countController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNutritions();
  }

  Future<void> _loadNutritions() async {
    final nutritionCollection = FirebaseFirestore.instance.collection('nutritions');
    QuerySnapshot snapshot = await nutritionCollection.where('userEmail',isEqualTo: widget.userEmail).get();

    setState(() {
      _nutritions = snapshot.docs
          .map((doc) => Nutrition.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> _addNutritionToFirestore(Nutrition nutrition) async {
    final nutritionCollection = FirebaseFirestore.instance.collection('nutritions');
    try {
      DocumentReference docRef = await nutritionCollection.add(nutrition.toMap());
      setState(() {
        nutrition.id = docRef.id;
      });
    } catch (e) {
      print("Error adding nutrition: $e");
    }
  }

  Future<void> _deleteNutritionFromFirestore(String nutritionId) async {
    final nutritionCollection = FirebaseFirestore.instance.collection('nutritions');
    try {
      await nutritionCollection.doc(nutritionId).delete();
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

  @override
  Widget build(BuildContext context) {
    final filteredNutritions = _nutritions.where((nutrition) =>
        DateUtils.isSameDay(nutrition.date, widget.selectedDate)).toList();
    double percentage = _calculatePercentage(filteredNutritions);

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
                return _buildNutritionItem(filteredNutritions[index]);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddNutritionDialog,
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildNutritionItem(Nutrition nutrition) {
    double percentage = (nutrition.takenDosage / nutrition.totalDosage) * 100;

    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        setState(() {
          _nutritions.remove(nutrition);
        });
        _deleteNutritionFromFirestore(nutrition.id);
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
                        onPressed: () => _takeDosage(nutrition),
                        child: Icon(Icons.add),
                        style: ElevatedButton.styleFrom(
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(12),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _removeDosage(nutrition),
                        child: Icon(Icons.remove),
                        style: ElevatedButton.styleFrom(
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () => _showNutritionDetails(context, nutrition),
                    child: Text('상세정보'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

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
            ],
          ),
        ),
      ),
    );
  }

  void _showAddNutritionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('영양제 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nutritionController,
                decoration: InputDecoration(labelText: '영양제 이름'),
              ),
              TextField(
                controller: _dosageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: '총 복용량 (mg)'),
              ),
              TextField(
                controller: _countController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: '개수'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('취소'),
            ),
            TextButton(
              onPressed: () {
                final name = _nutritionController.text;
                final totalDosage = int.tryParse(_dosageController.text) ?? 0;
                final count = int.tryParse(_countController.text) ?? 0;

                if (name.isNotEmpty && totalDosage > 0 && count > 0) {
                  final newNutrition = Nutrition(
                    name: name,
                    totalDosage: totalDosage,
                    count: count,
                    date: widget.selectedDate,
                    userEmail:  widget.userEmail,
                  );
                  _addNutritionToFirestore(newNutrition);
                  widget.onNutritionAdded(newNutrition);

                  setState(() {
                    _nutritions.add(newNutrition);
                  });

                  Navigator.pop(context);
                }
              },
              child: Text('추가'),
            ),
          ],
        );
      },
    );
  }

  void _takeDosage(Nutrition nutrition) {
    setState(() {
      nutrition.takenDosage += nutrition.dosagePerCount;
      nutrition.updateTaken();
    });
    _updateNutritionInFirestore(nutrition);
  }

  void _removeDosage(Nutrition nutrition) {
    setState(() {
      nutrition.takenDosage -= nutrition.dosagePerCount;
      nutrition.updateTaken();
    });
    _updateNutritionInFirestore(nutrition);
  }

  double _calculatePercentage(List<Nutrition> nutritions) {
    double totalDosage = 0;
    double takenDosage = 0;

    for (var nutrition in nutritions) {
      totalDosage += nutrition.totalDosage;
      takenDosage += nutrition.takenDosage;
    }

    return totalDosage == 0 ? 0 : (takenDosage / totalDosage) * 100;
  }
}