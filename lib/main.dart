import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class Bottle {
  String name;
  double price;
  double volume; // (L)
  double concentration; // (%)

  Bottle(this.name, this.price, this.volume, this.concentration);

  double pricePerGram() {
    return price / (volume * 1000 * (concentration / 100) * 0.789);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'volume': volume,
      'concentration': concentration,
    };
  }

  factory Bottle.fromMap(Map<dynamic, dynamic> map) {
    return Bottle(
      map['name'],
      map['price'],
      map['volume'],
      map['concentration'],
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('bottlesBox');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Budget Blackout',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.green,
      ),
      themeMode: ThemeMode.system,
      home: const MyHomePage(title: 'Budget Blackout'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Bottle> bottles = [];

  final box = Hive.box('bottlesBox');

  @override
  void initState() {
    super.initState();
    _loadBottles();
  }

  void _loadBottles() {
    final savedList = box.get('bottles', defaultValue: []);
    setState(() {
      bottles = (savedList as List)
          .map((e) => Bottle.fromMap(Map<dynamic, dynamic>.from(e)))
          .toList();
    });
  }

  void _saveBottles() {
    final listToSave = bottles.map((b) => b.toMap()).toList();
    box.put('bottles', listToSave);
  }

  void _deleteBottle(int index) {
    final removedBottle = bottles[index];
    setState(() {
      bottles.removeAt(index);
    });
    _saveBottles();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${removedBottle.name} removed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              bottles.insert(index, removedBottle);
            });
            _saveBottles();
          },
        ),
      ),
    );
  }

  void _showAddBottleDialog({Bottle? bottle, int? index}) {
    final nameController = TextEditingController(text: bottle?.name ?? '');
    final priceController = TextEditingController(
      text: bottle?.price.toString() ?? '',
    );
    final volumeController = TextEditingController(
      text: bottle?.volume.toString() ?? '',
    );
    final concentrationController = TextEditingController(
      text: bottle?.concentration.toString() ?? '',
    );

    final isEditing = bottle != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Bottle' : 'Add New Bottle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: volumeController,
                decoration: const InputDecoration(labelText: 'Bottle size (L)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: concentrationController,
                decoration: const InputDecoration(labelText: 'Alcohol %'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final bottleName = nameController.text.isEmpty
                    ? 'Bottle ${bottles.length + 1}'
                    : nameController.text;
                final bottlePrice = double.tryParse(priceController.text) ?? 0;
                final bottleVolume =
                    double.tryParse(volumeController.text) ?? 0;
                final bottleConcentration =
                    double.tryParse(concentrationController.text) ?? 0;

                if (bottlePrice <= 0 ||
                    bottleVolume <= 0 ||
                    bottleConcentration <= 0 ||
                    bottleConcentration > 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid values')),
                  );
                } else {
                  setState(() {
                    if (isEditing) {
                      bottles[index!].name = bottleName;
                      bottles[index].price = bottlePrice;
                      bottles[index].volume = bottleVolume;
                      bottles[index].concentration = bottleConcentration;
                    } else {
                      bottles.add(
                        Bottle(
                          bottleName,
                          bottlePrice,
                          bottleVolume,
                          bottleConcentration,
                        ),
                      );
                    }
                    bottles.sort(
                      (a, b) => a.pricePerGram().compareTo(b.pricePerGram()),
                    );
                  });
                  _saveBottles();
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: bottles.isEmpty
          ? Center(
              child: Text(
                'It seems like your list is empty.\nClick the + button to add a bottle.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            )
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Your bottles sorted by price per gram (cheapest first):',
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: bottles.length,
                    itemBuilder: (context, index) {
                      final bottle = bottles[index];
                      return Dismissible(
                        key: UniqueKey(),
                        onDismissed: (direction) => _deleteBottle(index),
                        child: ListTile(
                          title: Text(bottle.name),
                          subtitle: Text(
                            'Price per gram: \$${bottle.pricePerGram().toStringAsFixed(2)}\n\$${bottle.price} | ${bottle.volume} L | ${bottle.concentration}%',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _showAddBottleDialog(
                                  bottle: bottle,
                                  index: index,
                                ),
                                icon: const Icon(Icons.edit),
                              ),
                              IconButton(
                                onPressed: () => _deleteBottle(index),
                                icon: const Icon(Icons.delete),
                              ),
                            ],
                          ),
                          onTap: () => _showAddBottleDialog(
                            bottle: bottle,
                            index: index,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBottleDialog(),
        tooltip: 'Add Bottle',
        child: const Icon(Icons.add),
      ),
    );
  }
}
