import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const DeliveryApp());
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تحویل بار',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      locale: const Locale('fa'),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: DeliveryScreen(),
      ),
    );
  }
}

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  List<DeliveryItem> _currentItems = [];
  List<DeliveryItem> _filteredItems = [];
  List<DeliveryManifest> _savedManifests = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _purchasePriceController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _packageSizeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSearching = false;
  String _selectedCurrency = 'تومان';
  String _selectedUnit = 'عددی';
  bool _isLoading = false;
  bool _isPackageUnit = false;
  bool _isViewingManifest = false;
  DeliveryManifest? _viewingManifest;

  @override
  void initState() {
    super.initState();
    _loadSavedManifests();
  }

  String _formatNumber(String value) {
    if (value.isEmpty) return '';
    final number = int.tryParse(value.replaceAll(',', ''));
    if (number == null) return value;
    return number.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  int _convertPrice(String priceStr) {
    if (priceStr.isEmpty) return 0;
    final cleanPrice = int.tryParse(priceStr.replaceAll(',', ''));
    if (cleanPrice == null) return 0;
    if (_selectedCurrency == 'ریال') {
      return cleanPrice;
    } else {
      return cleanPrice * 10;
    }
  }

  String _displayPrice(int price) {
    if (_selectedCurrency == 'ریال') {
      return '${_formatNumber(price.toString())} ریال';
    } else {
      return '${_formatNumber((price / 10).toString())} تومان';
    }
  }

  void _searchItems(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _filteredItems.clear();
      } else {
        _filteredItems.clear();
        _filteredItems.addAll(
          _currentItems.where((item) =>
              item.name.toLowerCase().contains(query.toLowerCase()) ||
              item.barcode.contains(query)),
        );
      }
    });
  }

  void _showBarcodeDialog() {
    final TextEditingController tempController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code, color: Colors.blue),
            SizedBox(width: 8),
            Text('وارد کردن بارکد'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'شماره بارکد را به صورت دستی وارد کنید:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tempController,
              decoration: const InputDecoration(
                labelText: 'شماره بارکد',
                border: OutlineInputBorder(),
                hintText: 'مثلاً 1234567890123',
                prefixIcon: Icon(Icons.qr_code),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              if (tempController.text.isNotEmpty) {
                setState(() {
                  _barcodeController.text = tempController.text;
                });

                final foundItems = _currentItems
                    .where((item) => item.barcode == tempController.text);
                if (foundItems.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'کالا با این بارکد قبلاً ثبت شده: ${foundItems.first.name}'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('بارکد ثبت شد، لطفاً اطلاعات کالا را کامل کنید'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                Navigator.pop(context);
              }
            },
            child: const Text('تایید'),
          ),
        ],
      ),
    );
  }

  void _addItem() {
    if (_formKey.currentState!.validate()) {
      try {
        int purchasePriceValue = 0;
        if (_purchasePriceController.text.isNotEmpty) {
          purchasePriceValue = _convertPrice(_purchasePriceController.text);
        }

        final quantity = int.parse(_quantityController.text);

        int realQuantity = quantity;
        String unitDisplay = _selectedUnit;
        int packageSize = 0;

        if (_selectedUnit == 'بسته‌ای') {
          if (_packageSizeController.text.isNotEmpty) {
            packageSize = int.parse(_packageSizeController.text);
            realQuantity = quantity * packageSize;
            unitDisplay = 'بسته‌ای (${_packageSizeController.text} عددی)';
          } else {
            unitDisplay = 'بسته‌ای';
          }
        }

        final newItem = DeliveryItem(
          name: _nameController.text,
          quantity: quantity,
          realQuantity: realQuantity,
          purchasePrice: purchasePriceValue,
          barcode: _barcodeController.text.isNotEmpty
              ? _barcodeController.text
              : DateTime.now().millisecondsSinceEpoch.toString(),
          date: DateTime.now().millisecondsSinceEpoch.toString(),
          currency: _selectedCurrency,
          unit: unitDisplay,
          packageSize: packageSize,
        );

        setState(() {
          _currentItems.add(newItem);

          if (_searchController.text.isNotEmpty) {
            _searchItems(_searchController.text);
          }
        });

        _clearControllers();
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('کالا با موفقیت اضافه شد ✅'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در افزودن کالا: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearControllers() {
    _nameController.clear();
    _quantityController.clear();
    _purchasePriceController.clear();
    _barcodeController.clear();
    _packageSizeController.clear();
    setState(() {
      _selectedUnit = 'عددی';
      _isPackageUnit = false;
    });
  }

  void _showAddDialog() {
    _clearControllers();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'اضافه کردن کالا',
          textAlign: TextAlign.center,
        ),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _barcodeController,
                        decoration: const InputDecoration(
                          labelText: 'شماره بارکد',
                          border: OutlineInputBorder(),
                          hintText: 'دستی وارد کنید',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt,
                            color: Colors.blue, size: 30),
                        onPressed: _showBarcodeDialog,
                        tooltip: 'وارد کردن بارکد',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'نام کالا',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفاً نام کالا را وارد کنید';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('واحد سنجش:'),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'عددی',
                            child: Text('عددی'),
                          ),
                          DropdownMenuItem(
                            value: 'کیلویی',
                            child: Text('کیلویی'),
                          ),
                          DropdownMenuItem(
                            value: 'بسته‌ای',
                            child: Text('بسته‌ای'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedUnit = value!;
                            _isPackageUnit = (value == 'بسته‌ای');
                            if (!_isPackageUnit) {
                              _packageSizeController.clear();
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantityController,
                  decoration: InputDecoration(
                    labelText:
                        'تعداد (${_selectedUnit == 'بسته‌ای' ? 'بسته' : _selectedUnit})',
                    border: const OutlineInputBorder(),
                    hintText: _selectedUnit == 'بسته‌ای'
                        ? 'تعداد بسته‌ها'
                        : 'تعداد را وارد کنید',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفاً تعداد را وارد کنید';
                    }
                    if (int.tryParse(value) == null) {
                      return 'لطفاً یک عدد معتبر وارد کنید';
                    }
                    return null;
                  },
                ),
                if (_isPackageUnit) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _packageSizeController,
                    decoration: const InputDecoration(
                      labelText: 'تعداد داخل هر بسته (اختیاری)',
                      border: OutlineInputBorder(),
                      hintText:
                          'مثلاً 10 - در صورت وارد نکردن، فقط بسته ثبت می‌شود',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('واحد پول:'),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCurrency,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'تومان',
                            child: Text('تومان'),
                          ),
                          DropdownMenuItem(
                            value: 'ریال',
                            child: Text('ریال'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCurrency = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _purchasePriceController,
                  decoration: InputDecoration(
                    labelText:
                        'قیمت خرید (${_selectedCurrency == 'تومان' ? 'تومان' : 'ریال'})',
                    border: const OutlineInputBorder(),
                    prefixText:
                        '${_selectedCurrency == 'تومان' ? 'تومان ' : 'ریال '}',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final formatted = _formatNumber(value);
                    if (formatted != value) {
                      _purchasePriceController.value = TextEditingValue(
                        text: formatted,
                        selection:
                            TextSelection.collapsed(offset: formatted.length),
                      );
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفاً قیمت خرید را وارد کنید';
                    }
                    final cleanValue = value.replaceAll(',', '');
                    if (int.tryParse(cleanValue) == null) {
                      return 'لطفاً یک عدد معتبر وارد کنید';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: _addItem,
            child: const Text('افزودن'),
          ),
        ],
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      if (_isSearching && _filteredItems.isNotEmpty) {
        final itemToRemove = _filteredItems[index];
        _currentItems.remove(itemToRemove);
        _filteredItems.removeAt(index);
        if (_filteredItems.isEmpty) {
          _isSearching = false;
          _searchController.clear();
        }
      } else {
        _currentItems.removeAt(index);
      }
    });
  }

  int get _totalPurchasePrice {
    int total = 0;
    for (var item in _currentItems) {
      total += item.purchasePrice * item.realQuantity;
    }
    return total;
  }

  void _submitDelivery() async {
    final TextEditingController dateController = TextEditingController();
    dateController.text = _getTodayDate();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ثبت نهایی تحویل بار'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('لطفاً تاریخ بارنامه را وارد کنید:'),
            const SizedBox(height: 16),
            TextFormField(
              controller: dateController,
              decoration: const InputDecoration(
                labelText: 'تاریخ (مثلاً ۱۴۰۴/۰۵/۱۵)',
                border: OutlineInputBorder(),
                hintText: '۱۴۰۴/۰۵/۱۵',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              keyboardType: TextInputType.datetime,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تعداد کل کالاها: ${_currentItems.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'مجموع قیمت خرید: ${_displayPrice(_totalPurchasePrice)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final manifestDate = dateController.text.isEmpty
                  ? _getTodayDate()
                  : dateController.text;

              final manifest = DeliveryManifest(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                date: manifestDate,
                items: List.from(_currentItems),
                totalPrice: _totalPurchasePrice,
                currency: _selectedCurrency,
                createdAt: DateTime.now().millisecondsSinceEpoch.toString(),
              );

              await _saveManifest(manifest);

              setState(() {
                _currentItems.clear();
                _filteredItems.clear();
                _searchController.clear();
                _isSearching = false;
              });

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('بارنامه ${manifestDate} با موفقیت ثبت شد ✅'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            child: const Text('ثبت نهایی'),
          ),
        ],
      ),
    );
  }

  String _getTodayDate() {
    final now = DateTime.now();
    final persianYear = now.year - 621;
    return '$persianYear/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveManifest(DeliveryManifest manifest) async {
    final prefs = await SharedPreferences.getInstance();
    final manifestsJson = _savedManifests.map((m) => m.toJson()).toList();
    manifestsJson.add(manifest.toJson());
    await prefs.setString('delivery_manifests', jsonEncode(manifestsJson));
    await prefs.setString('currency', _selectedCurrency);

    setState(() {
      _savedManifests.add(manifest);
    });
  }

  Future<void> _loadSavedManifests() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final manifestsJson = prefs.getString('delivery_manifests');
    final savedCurrency = prefs.getString('currency');

    if (savedCurrency != null) {
      _selectedCurrency = savedCurrency;
    }

    if (manifestsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(manifestsJson);
        setState(() {
          _savedManifests =
              decoded.map((item) => DeliveryManifest.fromJson(item)).toList();
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteManifest(DeliveryManifest manifest) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف بارنامه'),
        content: Text('آیا از حذف بارنامه تاریخ ${manifest.date} مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              setState(() {
                _savedManifests.remove(manifest);
              });

              final prefs = await SharedPreferences.getInstance();
              final manifestsJson =
                  _savedManifests.map((m) => m.toJson()).toList();
              await prefs.setString(
                  'delivery_manifests', jsonEncode(manifestsJson));

              Navigator.pop(context);

              if (_isViewingManifest && _viewingManifest?.id == manifest.id) {
                setState(() {
                  _isViewingManifest = false;
                  _viewingManifest = null;
                });
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('بارنامه تاریخ ${manifest.date} حذف شد ❌'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _viewManifest(DeliveryManifest manifest) {
    setState(() {
      _viewingManifest = manifest;
      _isViewingManifest = true;
    });
  }

  void _goBackToMain() {
    setState(() {
      _isViewingManifest = false;
      _viewingManifest = null;
    });
  }

  void _cancelDelivery() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('لغو عملیات'),
        content: const Text(
            'آیا از لغو این محموله مطمئن هستید؟\nهمه کالاها حذف خواهند شد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _currentItems.clear();
                _filteredItems.clear();
                _searchController.clear();
                _isSearching = false;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('محموله لغو شد ❌'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            },
            child: const Text('بله، لغو شود'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isViewingManifest
            ? 'بارنامه ${_viewingManifest!.date}'
            : 'برنامه تحویل بار'),
        actions: [
          if (!_isViewingManifest) ...[
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'افزودن کالا',
              onPressed: _showAddDialog,
            ),
          ],
          if (_isViewingManifest) ...[
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'حذف بارنامه',
              onPressed: () => _deleteManifest(_viewingManifest!),
            ),
          ],
        ],
        leading: _isViewingManifest
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBackToMain,
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isViewingManifest
              ? _buildManifestView()
              : _buildMainView(),
    );
  }

  Widget _buildMainView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'جستجوی کالا',
              hintText: 'نام یا بارکد کالا را وارد کنید...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchItems('');
                        setState(() {
                          _isSearching = false;
                        });
                      },
                    )
                  : null,
            ),
            onChanged: _searchItems,
          ),
        ),
        if (_isSearching)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${_filteredItems.length} نتیجه از ${_currentItems.length} کالا',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
        Expanded(
          child: _currentItems.isEmpty && _savedManifests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'هیچ کالا یا بارنامه‌ای وجود ندارد',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'برای افزودن کالا روی دکمه + کلیک کنید',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _currentItems.isNotEmpty
                      ? (_isSearching
                          ? _filteredItems.length
                          : _currentItems.length)
                      : _savedManifests.length,
                  itemBuilder: (context, index) {
                    if (_currentItems.isNotEmpty) {
                      final item = _isSearching
                          ? _filteredItems[index]
                          : _currentItems[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(color: Colors.blue),
                            ),
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.barcode.isNotEmpty)
                                Text(
                                  'بارکد: ${item.barcode}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              Text('واحد: ${item.unit}'),
                              Text(
                                  'تعداد: ${item.quantity}${item.packageSize > 0 ? ' (مجموع: ${item.realQuantity})' : ''}'),
                              Text(
                                'قیمت خرید: ${_displayPrice(item.purchasePrice)}',
                              ),
                              Text(
                                'مجموع خرید: ${_displayPrice(item.purchasePrice * item.realQuantity)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeItem(index),
                          ),
                        ),
                      );
                    } else {
                      final manifest = _savedManifests[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: const Icon(Icons.description,
                                color: Colors.green),
                          ),
                          title: Text(
                            'بارنامه ${manifest.date}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('تعداد کالاها: ${manifest.items.length}'),
                              Text(
                                  'مجموع: ${_displayPrice(manifest.totalPrice)}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility,
                                    color: Colors.blue),
                                onPressed: () => _viewManifest(manifest),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteManifest(manifest),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                ),
        ),
        if (_currentItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'مجموع قیمت خرید:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _displayPrice(_totalPurchasePrice),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _cancelDelivery,
                        child: const Text(
                          'لغو',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _submitDelivery,
                        child: const Text(
                          'ثبت نهایی',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildManifestView() {
    final manifest = _viewingManifest!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'تاریخ بارنامه:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(manifest.date),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'تعداد کالاها:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('${manifest.items.length}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'مجموع قیمت:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _displayPrice(manifest.totalPrice),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: manifest.items.length,
            itemBuilder: (context, index) {
              final item = manifest.items[index];
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                  title: Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.barcode.isNotEmpty)
                        Text(
                          'بارکد: ${item.barcode}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      Text('واحد: ${item.unit}'),
                      Text(
                          'تعداد: ${item.quantity}${item.packageSize > 0 ? ' (مجموع: ${item.realQuantity})' : ''}'),
                      Text(
                        'قیمت خرید: ${_displayPrice(item.purchasePrice)}',
                      ),
                      Text(
                        'مجموع خرید: ${_displayPrice(item.purchasePrice * item.realQuantity)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class DeliveryItem {
  final String name;
  final int quantity;
  final int realQuantity;
  final int purchasePrice;
  final String barcode;
  final String date;
  final String currency;
  final String unit;
  final int packageSize;

  DeliveryItem({
    required this.name,
    required this.quantity,
    required this.realQuantity,
    required this.purchasePrice,
    required this.barcode,
    required this.date,
    required this.currency,
    required this.unit,
    required this.packageSize,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'realQuantity': realQuantity,
      'purchasePrice': purchasePrice,
      'barcode': barcode,
      'date': date,
      'currency': currency,
      'unit': unit,
      'packageSize': packageSize,
    };
  }

  factory DeliveryItem.fromJson(Map<String, dynamic> json) {
    return DeliveryItem(
      name: json['name'],
      quantity: json['quantity'],
      realQuantity: json['realQuantity'] ?? json['quantity'],
      purchasePrice: json['purchasePrice'] ?? 0,
      barcode: json['barcode'],
      date: json['date'],
      currency: json['currency'] ?? 'تومان',
      unit: json['unit'] ?? 'عددی',
      packageSize: json['packageSize'] ?? 0,
    );
  }
}

class DeliveryManifest {
  final String id;
  final String date;
  final List<DeliveryItem> items;
  final int totalPrice;
  final String currency;
  final String createdAt;

  DeliveryManifest({
    required this.id,
    required this.date,
    required this.items,
    required this.totalPrice,
    required this.currency,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'items': items.map((item) => item.toJson()).toList(),
      'totalPrice': totalPrice,
      'currency': currency,
      'createdAt': createdAt,
    };
  }

  factory DeliveryManifest.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List)
        .map((item) => DeliveryItem.fromJson(item))
        .toList();
    return DeliveryManifest(
      id: json['id'],
      date: json['date'],
      items: itemsList,
      totalPrice: json['totalPrice'],
      currency: json['currency'] ?? 'تومان',
      createdAt: json['createdAt'],
    );
  }
}
