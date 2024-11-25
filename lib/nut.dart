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
  List<int> repeatDays; // 반복 설정 (0: 월요일, ... 6: 일요일)

  Nutrition({
    this.id = '',
    required this.name,
    required this.totalDosage,
    required this.count,
    required this.userEmail,
    this.repeatDays = const [], // 기본값: 반복 없음
    Map<String, double>? takenDosageByDate,
  }) : this.takenDosageByDate = takenDosageByDate ?? {};

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

class NutPage extends StatefulWidget {
  final DateTime selectedDate;
  final String userEmail;

  NutPage({required this.selectedDate, required this.userEmail});

  @override
  _NutPageState createState() => _NutPageState();
}

class _NutPageState extends State<NutPage> {
  List<Nutrition> _nutritions = [];
  final TextEditingController _nutritionController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _countController = TextEditingController();
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
    final dateString = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    double totalPercentage = _calculateTotalPercentage(dateString);

    final filteredNutritions = _filterNutritionsForToday();

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
              itemCount: filteredNutritions.length,
              itemBuilder: (context, index) {
                return _buildNutritionItem(filteredNutritions[index], dateString);
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
                  IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () => _showEditNutritionDialog(nutrition),
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: takenDosage / nutrition.totalDosage,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            Text('${percentage.toStringAsFixed(1)}% 복용', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  void _showAddNutritionDialog() {
    _nutritionController.clear();
    _dosageController.clear();
    _countController.clear();
    _selectedDays.fillRange(0, _selectedDays.length, false);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder:(context, setState) {
            return AlertDialog(
              title: Text('영양제 추가'),
              content:
              Column(mainAxisSize : MainAxisSize.min,
                children:[
                  TextField(controller:_nutritionController, decoration:
                  InputDecoration(labelText:'영양제 이름'),),
                  TextField(controller:_dosageController, keyboardType:
                  TextInputType.number, decoration:
                  InputDecoration(labelText:'총 복용량 (mg)'),),
                  TextField(controller:_countController, keyboardType:
                  TextInputType.number, decoration:
                  InputDecoration(labelText:'개수'),),
                  SizedBox(height :10,),
                  Text('반복 설정 (요일 선택)', style:
                  TextStyle(fontSize :16)),
                  Wrap(children :List.generate(7,(index){
                    return ChoiceChip(label:
                    Text(['월','화','수','목','금','토','일'][index]),
                      selected:_selectedDays[index],
                      onSelected:(bool selected){
                        setState((){_selectedDays[index] =
                            selected;});
                      },);
                  },),)
                ],),
              actions:[
                TextButton(onPressed :(){
                  Navigator.pop(context);
                }, child :Text('취소'),),
                TextButton(onPressed :(){
                  final name=_nutritionController.text;
                  final totalDosage=int.tryParse(_dosageController.text)
                      ??0;
                  final count=int.tryParse(_countController.text)
                      ??0;
                  if(name.isNotEmpty && totalDosage >0 && count >0){
                    final newNutrition=Nutrition(name:name,totalDosage:
                    totalDosage,count :count,userEmail:
                    widget.userEmail,repeatDays:
                    List.generate(7,(index)=>_selectedDays[index]
                        ? index:-1).where((day)=>day !=-1).toList(),);
                    _addNutritionToFirestore(newNutrition);
                    Navigator.pop(context);
                  }
                },child :Text('추가'),)
              ],);
          },
        );
      },
    );
  }

  void _showEditNutritionDialog(Nutrition nutrition) {
    _nutritionController.text = nutrition.name;
    _dosageController.text = nutrition.totalDosage.toString();
    _countController.text = nutrition.count.toString();
    _selectedDays.fillRange(0, _selectedDays.length, false);
    for (var day in nutrition.repeatDays) {
      _selectedDays[day] = true;
    }

    showDialog(
      context : context,
      builder:(context){
        return StatefulBuilder(builder:(context,setState){
          return AlertDialog(title:
          Text('영양제 수정'),
            content:
            Column(mainAxisSize :MainAxisSize.min,
              children:[
                TextField(controller:_nutritionController,
                  decoration:
                  InputDecoration(labelText:'영양제 이름'),),
                TextField(controller:_dosageController,
                  keyboardType:
                  TextInputType.number,
                  decoration:
                  InputDecoration(labelText:'총 복용량 (mg)'),),
                TextField(controller:_countController,
                  keyboardType:
                  TextInputType.number,
                  decoration:
                  InputDecoration(labelText:'개수'),),
                SizedBox(height :10,),
                Text('반복 설정 (요일 선택)', style:
                TextStyle(fontSize :16)),
                Wrap(children :
                List.generate(7,(index){
                  return ChoiceChip(label:
                  Text(['월','화','수','목','금','토','일'][index]),
                    selected:_selectedDays[index],
                    onSelected:(bool selected){
                      setState((){_selectedDays[index] =
                          selected;});
                    },);
                },),)
              ],),
            actions:[
              TextButton(onPressed :(){
                Navigator.pop(context);
              }, child :Text('취소'),),
              TextButton(onPressed :(){
                final name=_nutritionController.text;
                final totalDosage=int.tryParse(_dosageController.text)
                    ??0;
                final count=int.tryParse(_countController.text)
                    ??0;
                if(name.isNotEmpty && totalDosage >0 && count >0){
                  nutrition.name=name;
                  nutrition.totalDosage=totalDosage;
                  nutrition.count=count;
                  nutrition.repeatDays=List.generate(7,(index)=>
                  _selectedDays[index]?index:-1).where((day)=>
                  day !=-1).toList();
                  _updateNutritionInFirestore(nutrition);
                  Navigator.pop(context);
                }
              },child :Text('저장'),)
            ],);
        },);
      },
    );
  }

  double _calculateTotalPercentage(String dateString) {
    double totalTaken=0.0;
    double totalDosage=0.0;
    for(var nutrition in _nutritions){
      totalTaken+=nutrition.takenDosageByDate[dateString]??0;
      totalDosage+=nutrition.totalDosage;
    }
    return totalDosage >0 ? (totalTaken/totalDosage)*100 :0;
  }

  void _takeDosage(Nutrition nutrition,String dateString){
    setState((){
      nutrition.takenDosageByDate.update(dateString,(value)=>
      value +nutrition.dosagePerCount ,ifAbsent :()=>nutrition.dosagePerCount ,);
      _updateNutritionInFirestore(nutrition);
    });
  }

  void _removeDosage(Nutrition nutrition,String dateString){
    setState((){
      if(nutrition.takenDosageByDate.containsKey(dateString)){
        nutrition.takenDosageByDate.update(dateString,(value)=>
            (value-nutrition.dosagePerCount).clamp(0.0,double.infinity),);
        _updateNutritionInFirestore(nutrition);
      }
    });
  }
}