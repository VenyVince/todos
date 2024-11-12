import 'package:flutter/material.dart';

class Nutrition {
  String name;
  String dosage;
  int count;
  bool taken;
  DateTime date;

  Nutrition({
    required this.name,
    required this.dosage,
    required this.count,
    required this.date,
    this.taken = false,
  });
}
//원본
//class NutPage extends StatefulWidget {
  //final DateTime selectedDate;

  //NutPage({required this.selectedDate});

//콜백을 받아드리도록 수정
class NutPage extends StatefulWidget {
  final DateTime selectedDate;
  final Function(Nutrition) onNutritionAdded;
  final Function(Nutrition) onNutritionRemoved;

  NutPage({
    required this.selectedDate,
    required this.onNutritionAdded,
    required this.onNutritionRemoved,
  });


  @override
  _NutPageState createState() => _NutPageState();
}

class _NutPageState extends State<NutPage> {
  final List<Nutrition> _nutritions = [];

  final TextEditingController _nutritionController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _countController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final filteredNutritions = _nutritions.where((nutrition) => isSameDay(nutrition.date, widget.selectedDate)).toList();
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
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        setState(() {
          _nutritions.remove(nutrition);
        });
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20),
        color: Colors.red,
        child: Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        title: Text(
          nutrition.name,
          style: TextStyle(
            decoration: nutrition.taken ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text('${nutrition.dosage} - ${nutrition.count}정'),
        trailing: Checkbox(
          value: nutrition.taken,
          onChanged: (bool? value) {
            setState(() {
              nutrition.taken = value ?? false;
            });
          },
        ),
        leading: CircleAvatar(
          backgroundColor: Colors.green,
          child: Text(
            nutrition.name[0],
            style: TextStyle(color: Colors.white),
          ),
        ),
        onTap: () => _showNutritionDetails(context, nutrition),
      ),
    );
  }

  void _showNutritionDetails(BuildContext context, Nutrition nutrition) {
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
              Text(nutrition.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text('복용량: ${nutrition.dosage}'),
              Text('섭취 개수: ${nutrition.count}정'),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    nutrition.taken = !nutrition.taken;
                  });
                  Navigator.pop(context);
                },
                icon: Icon(nutrition.taken ? Icons.check_circle : Icons.circle_outlined),
                label: Text(nutrition.taken ? '섭취 취소' : '섭취 완료'),
              ),
              Divider(),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _nutritions.remove(nutrition);
                  });
                  Navigator.pop(context);
                },
                icon: Icon(Icons.delete, color: Colors.white),
                label: Text('삭제'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
                decoration: InputDecoration(labelText: "복용량"),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _countController,
                decoration: InputDecoration(labelText: "섭취 개수"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("취소"),
            ),
            ElevatedButton(
              onPressed: () {
                _addNutrition();
                Navigator.of(context).pop();
              },
              child: Text("추가"),
            ),
          ],
        );
      },
    );
  }

  void _addNutrition() {
    if (_nutritionController.text.isNotEmpty &&
        _dosageController.text.isNotEmpty &&
        _countController.text.isNotEmpty) {
      setState(() {
        _nutritions.add(Nutrition(
          name: _nutritionController.text,
          dosage: _dosageController.text,
          count: int.parse(_countController.text),
          date: widget.selectedDate,
        ));
        _nutritionController.clear();
        _dosageController.clear();
        _countController.clear();
      });
    }
  }

  double _calculatePercentage(List<Nutrition> nutritions) {
    if (nutritions.isEmpty) return 0.0;
    int takenCount = nutritions.where((n) => n.taken).length;
    return takenCount / nutritions.length * 100;
  }
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
