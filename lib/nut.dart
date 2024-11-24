import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Nutrition {
  String id;
  String name;
  int totalDosage;
  int count;
  Map<String, double> takenDosageByDate;
  String userEmail;

  Nutrition({
    this.id = '',
    required this.name,
    required this.totalDosage,
    required this.count,
    required this.userEmail,
    Map<String, double>? takenDosageByDate,
  }) : this.takenDosageByDate = takenDosageByDate ?? {};

  double get dosagePerCount => totalDosage / count;
  factory Nutrition.fromMap(Map<String, dynamic> data) {
    return Nutrition(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      totalDosage: data['totalDosage'] ?? 0,
      count: data['count'] ?? 0,
      userEmail: data['userEmail'] ?? '',
    );
  }
  factory Nutrition.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Nutrition(
      id: doc.id,
      name: data['name'],
      totalDosage: data['totalDosage'],
      count: data['count'],
      userEmail: data['userEmail'],
      takenDosageByDate: Map<String, double>.from(data['takenDosageByDate'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'totalDosage': totalDosage,
      'count': count,
      'userEmail': userEmail,
      'takenDosageByDate': takenDosageByDate,
    };
  }
}

class NutPage extends StatefulWidget {
  final DateTime selectedDate;
  final String userEmail;

  NutPage({
    required this.selectedDate,
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
    QuerySnapshot snapshot = await nutritionCollection.where('userEmail', isEqualTo: widget.userEmail).get();

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

  @override
  Widget build(BuildContext context) {
    final dateString = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    double totalPercentage = _calculateTotalPercentage(dateString);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '오늘의 영양제 섭취율: ${totalPercentage.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          LinearProgressIndicator(
            value: totalPercentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _nutritions.length,
              itemBuilder: (context, index) {
                return _buildNutritionItem(_nutritions[index], dateString);
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

  Widget _buildNutritionItem(Nutrition nutrition, String dateString) {
    double takenDosage = nutrition.takenDosageByDate[dateString] ?? 0;
    double percentage = (takenDosage / nutrition.totalDosage) * 100;

    return Dismissible(
      key: Key(nutrition.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _deleteNutritionFromFirestore(nutrition.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20),
        color: Colors.red,
        child: Icon(Icons.delete, color: Colors.white),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(nutrition.name),
              subtitle: Text('${takenDosage.toStringAsFixed(2)}/${nutrition.totalDosage} mg'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.remove),
                    onPressed: () => _removeDosage(nutrition, dateString),
                  ),
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () => _takeDosage(nutrition, dateString),
                  ),
                ],
              ),
              onTap: () => _showNutritionDetails(context, nutrition, dateString),
            ),
            SizedBox(height: 4), // ListTile과 ProgressIndicator 사이의 간격
            LinearProgressIndicator(
              value: takenDosage / nutrition.totalDosage,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            SizedBox(height: 4), // ProgressIndicator 아래의 간격
            Text(
              '${percentage.toStringAsFixed(1)}% 복용',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  void _showNutritionDetails(BuildContext context, Nutrition nutrition, String dateString) {
    double takenDosage = nutrition.takenDosageByDate[dateString] ?? 0;
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
              Text('현재 복용량 : ${takenDosage.toStringAsFixed(2)} mg'),
              Text('복용한 개수 : ${(takenDosage / nutrition.dosagePerCount).toStringAsFixed(2)}개'),
              SizedBox(height: 20),
              LinearProgressIndicator(
                value: takenDosage / nutrition.totalDosage,
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
                    userEmail: widget.userEmail,
                  );
                  _addNutritionToFirestore(newNutrition);

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

  void _takeDosage(Nutrition nutrition, String dateString) {
    setState(() {
      double currentDosage = nutrition.takenDosageByDate[dateString] ?? 0;
      nutrition.takenDosageByDate[dateString] = currentDosage + nutrition.dosagePerCount;
    });
    _updateNutritionInFirestore(nutrition);
  }

  void _removeDosage(Nutrition nutrition, String dateString) {
    setState(() {
      double currentDosage = nutrition.takenDosageByDate[dateString] ?? 0;
      if (currentDosage >= nutrition.dosagePerCount) {
        nutrition.takenDosageByDate[dateString] = currentDosage - nutrition.dosagePerCount;
      }
    });
    _updateNutritionInFirestore(nutrition);
  }

  double _calculateTotalPercentage(String dateString) {
    double totalDosage = 0;
    double totalTakenDosage = 0;

    for (var nutrition in _nutritions) {
      totalDosage += nutrition.totalDosage;
      totalTakenDosage += nutrition.takenDosageByDate[dateString] ?? 0;
    }

    return totalDosage == 0 ? 0 : (totalTakenDosage / totalDosage) * 100;
  }
}