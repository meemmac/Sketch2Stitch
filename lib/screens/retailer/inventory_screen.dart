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

  InventoryItem({
    required this.name,
    required this.category,
    required this.sku,
    required this.price,
    required this.stock,
    required this.careLevel,
    required this.colors,
  });
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final items = <InventoryItem>[
    InventoryItem(
      name: "Georgette Fabric",
      category: "Fabric",
      sku: "TSH-001",
      price: 240,
      stock: 45,
      careLevel: "Medium Care",
      colors: ["White","Pink"],
    ),
  ];

  void showItemForm({InventoryItem? item}) {
    final name = TextEditingController(text: item?.name ?? "");
    final sku = TextEditingController(text: item?.sku ?? "");
    final price = TextEditingController(text: item?.price.toString() ?? "");
    final stock = TextEditingController(text: item?.stock.toString() ?? "");
    String category = item?.category ?? "Fabric";
    String care = item?.careLevel ?? "Low Care";

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
                        ));
                      }else{
                        item.name=name.text;
                        item.category=category;
                        item.sku=sku.text;
                        item.price=double.tryParse(price.text)??0;
                        item.stock=int.tryParse(stock.text)??0;
                        item.careLevel=care;
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
                    leading:const CircleAvatar(child:Icon(Icons.inventory_2)),
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
