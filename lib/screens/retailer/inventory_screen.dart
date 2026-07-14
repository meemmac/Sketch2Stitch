import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: InventoryScreen()));

class InventoryItem {
  String name;
  String category;
  String sku;
  double price;
  int stock;
  String careLevel;
  List<String> colors;
  String imagePath;

  InventoryItem({
    required this.name,
    required this.category,
    required this.sku,
    required this.price,
    required this.stock,
    required this.careLevel,
    required this.colors,
    required this.imagePath,
  });
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const productImages = [
    'assets/images/gorgette.jpg',
    'assets/images/gorgeous.jpg',
    'assets/images/fab.jpg',
    'assets/images/fab2.jpg',
    'assets/images/silk.jpg',
    'assets/images/lace.jpg',
    'assets/images/embroidery.jpg',
    'assets/images/textile.jpg',
  ];

  final items = <InventoryItem>[
    InventoryItem(
      name: "Georgette Fabric",
      category: "Fabric",
      sku: "TSH-001",
      price: 240,
      stock: 45,
      careLevel: "Medium Care",
      colors: ["White","Pink"],
      imagePath: 'assets/images/gorgette.jpg',
    ),
  ];

  void showItemForm({InventoryItem? item}) {
    final name = TextEditingController(text: item?.name ?? "");
    final sku = TextEditingController(text: item?.sku ?? "");
    final price = TextEditingController(text: item?.price.toString() ?? "");
    final stock = TextEditingController(text: item?.stock.toString() ?? "");
    String category = item?.category ?? "Fabric";
    String care = item?.careLevel ?? "Low Care";
    String selectedImage = item?.imagePath ?? productImages.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (c,setM){
        return Padding(
          padding: EdgeInsets.only(
            left:16,right:16,top:20,
            bottom:MediaQuery.of(context).viewInsets.bottom+20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:[
                Text(item==null?"Add Inventory Item":"Edit Inventory Item",
                  style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
                const SizedBox(height:20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Product Image",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height:10),
                SizedBox(
                  height: 106,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: productImages.length,
                    separatorBuilder: (_, __) => const SizedBox(width:10),
                    itemBuilder: (_, index) {
                      final imagePath = productImages[index];
                      final isSelected = selectedImage == imagePath;

                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setM(() => selectedImage = imagePath),
                        child: Container(
                          width: 96,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(imagePath, fit: BoxFit.cover),
                              if (isSelected)
                                Container(
                                  alignment: Alignment.topRight,
                                  padding: const EdgeInsets.all(6),
                                  child: CircleAvatar(
                                    radius: 12,
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    child: const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height:20),
                TextField(controller:name,decoration:const InputDecoration(labelText:"Item Name")),
                TextField(controller:sku,decoration:const InputDecoration(labelText:"SKU")),
                DropdownButtonFormField(
                  value: category,
                  items:["Fabric","Design Element","Accessory"]
                      .map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
                  onChanged:(v)=>setM(()=>category=v.toString()),
                  decoration:const InputDecoration(labelText:"Category"),
                ),
                TextField(controller:price,keyboardType:TextInputType.number,
                  decoration:const InputDecoration(labelText:"Price")),
                TextField(controller:stock,keyboardType:TextInputType.number,
                  decoration:const InputDecoration(labelText:"Stock")),
                DropdownButtonFormField(
                  value: care,
                  items:["Low Care","Medium Care","High Care","Delicate","Dry Clean Only"]
                      .map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
                  onChanged:(v)=>setM(()=>care=v.toString()),
                  decoration:const InputDecoration(labelText:"Care Level"),
                ),
                const SizedBox(height:20),
                ElevatedButton(
                  onPressed:(){
                    setState(() {
                      if(item==null){
                        items.add(InventoryItem(
                          name:name.text,
                          category:category,
                          sku:sku.text,
                          price:double.tryParse(price.text)??0,
                          stock:int.tryParse(stock.text)??0,
                          careLevel:care,
                          colors:["White"],
                          imagePath:selectedImage,
                        ));
                      }else{
                        item.name=name.text;
                        item.category=category;
                        item.sku=sku.text;
                        item.price=double.tryParse(price.text)??0;
                        item.stock=int.tryParse(stock.text)??0;
                        item.careLevel=care;
                        item.imagePath=selectedImage;
                      }
                    });
                    Navigator.pop(context);
                  },
                  child:Text(item==null?"Add Item":"Update Item"),
                )
              ]
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar:AppBar(title:const Text("Inventory")),
      floatingActionButton:FloatingActionButton(
        onPressed:()=>showItemForm(),
        child:const Icon(Icons.add),
      ),
      body:Padding(
        padding:const EdgeInsets.all(16),
        child:Column(children:[
          Row(children:[
            Expanded(child:_summary("Items",items.length.toString())),
            const SizedBox(width:8),
            Expanded(child:_summary("Low Stock",
              items.where((e)=>e.stock<10).length.toString())),
          ]),
          const SizedBox(height:16),
          TextField(decoration:InputDecoration(
            hintText:"Search...",
            prefixIcon:const Icon(Icons.search),
            border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)),
          )),
          const SizedBox(height:16),
          Expanded(
            child:ListView.builder(
              itemCount:items.length,
              itemBuilder:(c,i){
                final item=items[i];
                return Card(
                  child:ListTile(
                    leading:CircleAvatar(
                      backgroundImage: AssetImage(item.imagePath),
                      onBackgroundImageError: (_, __) {},
                      child: const SizedBox.shrink(),
                    ),
                    title:Text(item.name),
                    subtitle:Text("${item.category}\nCare: ${item.careLevel}\nStock: ${item.stock}"),
                    isThreeLine:true,
                    trailing:Row(
                      mainAxisSize:MainAxisSize.min,
                      children:[
                        IconButton(
                          icon:const Icon(Icons.edit),
                          onPressed:()=>showItemForm(item:item),
                        ),
                        IconButton(
                          icon:const Icon(Icons.delete,color:Colors.red),
                          onPressed:(){
                            setState(()=>items.removeAt(i));
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        ]),
      ),
    );
  }

  Widget _summary(String t,String v){
    return Card(
      child:Padding(
        padding:const EdgeInsets.all(16),
        child:Column(children:[
          Text(v,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
          Text(t),
        ]),
      ),
    );
  }
}
