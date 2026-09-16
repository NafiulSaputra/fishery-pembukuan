import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:excel/excel.dart' as ex;
import 'package:file_saver/file_saver.dart';
// BARU: Impor untuk mesin pembuat PDF dan cetak struk
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'transaction_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('transactionBox'); 
  runApp(const FisheryApp());
}

class FisheryApp extends StatelessWidget {
  const FisheryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fishery Pembukuan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

// --- HALAMAN LOGIN ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscurePassword = true;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.set_meal, size: 80, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              const Text('Fishery Pembukuan', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Silakan masuk (Login Pemilik)', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility), onPressed: () { setState(() { _obscurePassword = !_obscurePassword; }); }),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
                  onPressed: () {
                    String inputUsername = _usernameController.text.trim();
                    String inputPassword = _passwordController.text.trim();
                    if (inputUsername == 'Ade123' && inputPassword == '123456') {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen()));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal! Anda mengetik: "$inputUsername" dan "$inputPassword"'), backgroundColor: Colors.red));
                    }
                  },
                  child: const Text('MASUK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- KERANGKA LAYAR UTAMA ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [const DashboardPage(), const TransactionPage(), const ReportPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) { setState(() { _selectedIndex = index; }); },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Riwayat'),
          NavigationDestination(icon: Icon(Icons.insert_chart_outlined), selectedIcon: Icon(Icons.insert_chart), label: 'Laporan'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const TransactionFormPage()));
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// --- DASHBOARD REAL-TIME ---
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('transactionBox');

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Perikanan', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true, elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () { Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage())); })]
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box box, _) {
          final transactions = box.values.map((e) => TransactionModel.fromMap(e)).toList();

          double totalKgMasuk = 0;
          double totalKgKeluar = 0;
          double totalPendapatan = 0; 
          double totalPengeluaran = 0; 
          Map<String, double> stockMap = {};
          Map<String, String> categoryMap = {}; 

          for (var trx in transactions) {
            if (trx.type == 'Masuk') {
              totalKgMasuk += trx.weight;
              totalPengeluaran += trx.price;
              stockMap[trx.itemName] = (stockMap[trx.itemName] ?? 0) + trx.weight;
              categoryMap[trx.itemName] = trx.category;
            } else {
              totalKgKeluar += trx.weight;
              totalPendapatan += trx.price;
              stockMap[trx.itemName] = (stockMap[trx.itemName] ?? 0) - trx.weight;
            }
          }

          double saldoKas = totalPendapatan - totalPengeluaran;
          final recentTransactions = transactions.reversed.take(3).toList();

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text('Saldo Bersih Penjualan (Rp)', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7))),
                      const SizedBox(height: 8),
                      Text(saldoKas.toInt().toString(), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                      const Divider(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(children: [const Icon(Icons.arrow_downward, color: Colors.green, size: 28), const SizedBox(height: 8), Text('${totalKgMasuk.toInt()} kg', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const Text('Total Masuk', style: TextStyle(fontSize: 12, color: Colors.grey))]),
                          Column(children: [const Icon(Icons.arrow_upward, color: Colors.red, size: 28), const SizedBox(height: 8), Text('${totalKgKeluar.toInt()} kg', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const Text('Total Keluar', style: TextStyle(fontSize: 12, color: Colors.grey))]),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Stok Tersedia Saat Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              stockMap.isEmpty 
                ? const Center(child: Text('Belum ada stok barang.'))
                : Column(
                    children: stockMap.entries.where((entry) => entry.value > 0).map((entry) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.teal.withValues(alpha: 0.1), child: Icon(categoryMap[entry.key]!.contains('Udang') ? Icons.water : Icons.set_meal, color: Colors.teal)),
                          title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(categoryMap[entry.key] ?? ''),
                          trailing: Text('${entry.value.toInt()} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                        ),
                      );
                    }).toList(),
                  ),
              const SizedBox(height: 24),
              const Text('Aktivitas Terakhir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              recentTransactions.isEmpty
                ? const Center(child: Text('Belum ada aktivitas.'))
                : Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: recentTransactions.map((trx) {
                        bool isMasuk = trx.type == 'Masuk';
                        return Column(
                          children: [
                            ListTile(
                              leading: Icon(isMasuk ? Icons.download : Icons.upload, color: isMasuk ? Colors.green : Colors.red),
                              title: Text('${trx.itemName} (${trx.type})'),
                              subtitle: Text('${trx.date.day}/${trx.date.month} - Rp ${trx.price.toInt()}'),
                              trailing: Text('${isMasuk ? '+' : '-'}${trx.weight.toInt()} kg', style: TextStyle(color: isMasuk ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                            ),
                            if (trx != recentTransactions.last) const Divider(height: 1, indent: 16, endIndent: 16),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

// --- HALAMAN RIWAYAT TRANSAKSI (DIPERBARUI DENGAN FITUR CETAK STRUK) ---
class TransactionPage extends StatelessWidget {
  const TransactionPage({super.key});

  // Fungsi untuk membuat dan mencetak Struk Belanja PDF
  Future<void> _printReceipt(BuildContext context, TransactionModel trx) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Ukuran standar kertas kasir thermal (80mm)
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('PUSAT PEMBUKUAN FISHERY', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Center(
                child: pw.Text('Nota Resmi Penjualan Hasil Tambak', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Text('ID Resi : ${trx.id.substring(0, 8).toUpperCase()}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Tanggal : ${trx.date.day}/${trx.date.month}/${trx.date.year} ${trx.date.hour}:${trx.date.minute}', style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),
              
              // Rincian Item
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${trx.itemName} (${trx.weight.toInt()} Kg)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text('Rp ${trx.price.toInt()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),
              
              // Total Pembayaran
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL PEMBAYARAN:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text('Rp ${trx.price.toInt()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Center(
                child: pw.Text('Terima Kasih atas Kerjasamanya!', style: const pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
              ),
            ],
          );
        },
      ),
    );

    // Membuka pratinjau cetak (Print Preview)
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('transactionBox');
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Transaksi', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true, elevation: 0),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box box, _) {
          if (box.values.isEmpty) return const Center(child: Text('Belum ada transaksi.', style: TextStyle(fontSize: 16, color: Colors.grey)));
          final transactions = box.values.map((e) => TransactionModel.fromMap(e)).toList().reversed.toList();

          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final trx = transactions[index];
              bool isMasuk = trx.type == 'Masuk';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isMasuk ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                    child: Icon(isMasuk ? Icons.arrow_downward : Icons.arrow_upward, color: isMasuk ? Colors.green : Colors.red),
                  ),
                  title: Text('${trx.itemName} (${trx.category})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${trx.weight} Kg • ${trx.date.day}/${trx.date.month}/${trx.date.year}'),
                  // BARU: Tombol cetak struk hanya muncul jika transaksi bertipe 'Keluar' (Jual)
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Rp ${trx.price.toInt()}', style: TextStyle(fontWeight: FontWeight.bold, color: isMasuk ? Colors.green : Colors.red)),
                      if (!isMasuk) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.print, color: Colors.teal),
                          tooltip: 'Cetak Struk Belanja',
                          onPressed: () => _printReceipt(context, trx),
                        ),
                      ]
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- HALAMAN LAPORAN BUKU KAS DETAIL ---
class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  Future<void> _exportToExcel(BuildContext context, Box box) async {
    try {
      var excel = ex.Excel.createExcel();
      ex.Sheet sheet = excel['Buku Kas'];
      excel.setDefaultSheet('Buku Kas');

      ex.CellStyle headerStyle = ex.CellStyle(
        bold: true,
        horizontalAlign: ex.HorizontalAlign.Center,
        topBorder: ex.Border(borderStyle: ex.BorderStyle.Thin),
        bottomBorder: ex.Border(borderStyle: ex.BorderStyle.Thin),
        leftBorder: ex.Border(borderStyle: ex.BorderStyle.Thin),
        rightBorder: ex.Border(borderStyle: ex.BorderStyle.Thin),
      );

      ex.CellStyle dataStyle = ex.CellStyle(
        topBorder: ex.Border(borderStyle: ex.BorderStyle.Thin),
        bottomBorder: ex.Border(borderStyle: ex.BorderStyle.Thin),
        leftBorder: ex.Border(borderStyle: ex.BorderStyle.Thin),
        rightBorder: ex.Border(borderStyle: ex.BorderStyle.Thin),
      );

      sheet.merge(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), ex.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0));
      var titleCell = sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
      titleCell.value = ex.TextCellValue('LAPORAN BUKU KAS FISHERY');
      titleCell.cellStyle = ex.CellStyle(bold: true, horizontalAlign: ex.HorizontalAlign.Center);

      List<String> headers = ['TANGGAL', 'KETERANGAN', 'PEMASUKAN (Rp)', 'PENGELUARAN (Rp)', 'SALDO (Rp)'];
      sheet.appendRow(headers.map((e) => ex.TextCellValue(e)).toList());
      
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1)).cellStyle = headerStyle;
      }

      List<TransactionModel> transactions = box.values.map((e) => TransactionModel.fromMap(e)).toList();
      transactions.sort((a, b) => a.date.compareTo(b.date));
      double runningBalance = 0;
      int currentRowIndex = 2; 

      for (var trx in transactions) {
        double uangMasuk = 0;
        double uangKeluar = 0;
        
        if (trx.type == 'Keluar') { 
          uangMasuk = trx.price;
          runningBalance += uangMasuk;
        } else { 
          uangKeluar = trx.price;
          runningBalance -= uangKeluar;
        }

        sheet.appendRow([
          ex.TextCellValue('${trx.date.day}/${trx.date.month}/${trx.date.year}'),
          ex.TextCellValue('${trx.itemName} (${trx.type})'),
          ex.IntCellValue(uangMasuk.toInt()),
          ex.IntCellValue(uangKeluar.toInt()),
          ex.IntCellValue(runningBalance.toInt()),
        ]);

        for (int c = 0; c < 5; c++) {
          sheet.cell(ex.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: currentRowIndex)).cellStyle = dataStyle;
        }
        currentRowIndex++; 
      }

      sheet.setColumnWidth(0, 15.0); 
      sheet.setColumnWidth(1, 35.0); 
      sheet.setColumnWidth(2, 20.0); 
      sheet.setColumnWidth(3, 20.0); 
      sheet.setColumnWidth(4, 25.0); 

      var fileBytes = excel.save();
      if (fileBytes != null) {
        await FileSaver.instance.saveFile(
          name: 'Laporan_Kas_Fishery_${DateTime.now().millisecondsSinceEpoch}.xlsx',
          bytes: Uint8List.fromList(fileBytes),
          mimeType: MimeType.microsoftExcel,
        );
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil! Excel sudah dirapikan dengan garis tabel.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal Export: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('transactionBox');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buku Kas Detail', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export ke Excel',
            onPressed: () => _exportToExcel(context, box),
          )
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box box, _) {
          if (box.values.isEmpty) return const Center(child: Text('Belum ada data untuk laporan.', style: TextStyle(color: Colors.grey)));

          List<TransactionModel> transactions = box.values.map((e) => TransactionModel.fromMap(e)).toList();
          transactions.sort((a, b) => a.date.compareTo(b.date));

          List<DataRow> rows = [];
          double runningBalance = 0;

          for (var trx in transactions) {
            double uangMasuk = 0;
            double uangKeluar = 0;
            
            if (trx.type == 'Keluar') { 
              uangMasuk = trx.price;
              runningBalance += uangMasuk;
            } else { 
              uangKeluar = trx.price;
              runningBalance -= uangKeluar;
            }

            rows.add(DataRow(
              cells: [
                DataCell(Text('${trx.date.day}/${trx.date.month}/${trx.date.year}')),
                DataCell(Text('${trx.itemName} (${trx.type})')),
                DataCell(Text('Rp ${uangMasuk.toInt()}', style: const TextStyle(color: Colors.green))),
                DataCell(Text('Rp ${uangKeluar.toInt()}', style: const TextStyle(color: Colors.red))),
                DataCell(Text('Rp ${runningBalance.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold))),
              ]
            ));
          }

          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: DataTable(
                  columnSpacing: 24,
                  headingRowColor: WidgetStateProperty.all(Colors.teal.shade50),
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                  border: TableBorder.all(color: Colors.grey.shade300),
                  columns: const [
                    DataColumn(label: Text('TANGGAL')),
                    DataColumn(label: Text('KETERANGAN')),
                    DataColumn(label: Text('PEMASUKAN')),
                    DataColumn(label: Text('PENGELUARAN')),
                    DataColumn(label: Text('SALDO (Rp)')),
                  ],
                  rows: rows,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- HALAMAN FORM INPUT TRANSAKSI ---
class TransactionFormPage extends StatefulWidget {
  const TransactionFormPage({super.key});

  @override
  State<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends State<TransactionFormPage> {
  String _transactionType = 'Masuk';
  String? _selectedCategory;
  final List<String> _categories = ['Jenis Ikan', 'Jenis Udang', 'Jenis Molusca', 'Jenis Kerang'];
  
  final TextEditingController _itemNameController = TextEditingController(); 
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  @override
  void dispose() {
    _itemNameController.dispose();
    _weightController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Input Transaksi', style: TextStyle(fontSize: 18)), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Tipe Transaksi', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: ChoiceChip(label: const Center(child: Text('Ikan Masuk\n(Panen/Beli)', textAlign: TextAlign.center)), selected: _transactionType == 'Masuk', onSelected: (bool selected) { setState(() { _transactionType = 'Masuk'; }); }, selectedColor: Colors.green.shade200)),
                const SizedBox(width: 8),
                Expanded(child: ChoiceChip(label: const Center(child: Text('Ikan Keluar\n(Jual)', textAlign: TextAlign.center)), selected: _transactionType == 'Keluar', onSelected: (bool selected) { setState(() { _transactionType = 'Keluar'; }); }, selectedColor: Colors.red.shade200)),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Pilih Kategori Utama', border: OutlineInputBorder()),
              initialValue: _selectedCategory,
              items: _categories.map((String category) { return DropdownMenuItem(value: category, child: Text(category)); }).toList(),
              onChanged: (String? newValue) { setState(() { _selectedCategory = newValue; }); },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _itemNameController,
              decoration: const InputDecoration(labelText: 'Nama Spesifik (Contoh: Vaname, Bandeng)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _weightController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Berat (Kg)', border: OutlineInputBorder(), suffixText: 'Kg'))),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(controller: _priceController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Harga/Biaya (Rp)', border: OutlineInputBorder(), prefixText: 'Rp '))),
              ],
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
              onPressed: () {
                if (_selectedCategory == null || _itemNameController.text.isEmpty || _weightController.text.isEmpty || _priceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap isi semua kolom data!'), backgroundColor: Colors.red));
                  return;
                }
                double weight = double.tryParse(_weightController.text) ?? 0;
                double price = double.tryParse(_priceController.text) ?? 0;

                final newTransaction = TransactionModel(
                  id: const Uuid().v4(),
                  type: _transactionType,
                  category: _selectedCategory!,
                  itemName: _itemNameController.text,
                  weight: weight,
                  price: price,
                  date: DateTime.now(),
                );
                Hive.box('transactionBox').put(newTransaction.id, newTransaction.toMap());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data berhasil disimpan!'), backgroundColor: Colors.green));
              },
              child: const Text('SIMPAN TRANSAKSI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}