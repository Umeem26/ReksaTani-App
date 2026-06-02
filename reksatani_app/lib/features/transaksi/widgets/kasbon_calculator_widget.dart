import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/kasbon_controller.dart';
import '../../../models/hive/petani_hive_model.dart';

class KasbonCalculatorWidget extends StatelessWidget {
  final List<PetaniHiveModel> daftarPetani;

  const KasbonCalculatorWidget({
    super.key,
    required this.daftarPetani,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<KasbonController>(
      builder: (context, controller, child) {
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Kalkulator Transaksi & Kasbon",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<PetaniHiveModel>(
                  value: controller.selectedPetani,
                  decoration: const InputDecoration(
                    labelText: "Pilih Petani",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: daftarPetani.map((p) {
                    return DropdownMenuItem(
                      value: p,
                      child: Text(p.namaPetani),
                    );
                  }).toList(),
                  onChanged: (val) => controller.setSelectedPetani(val),
                ),
                const SizedBox(height: 8),
                
                if (controller.selectedPetani != null)
                  Text(
                    "Sisa Kasbon Saat Ini: Rp ${controller.selectedPetani!.sisaHutangKasbon.toStringAsFixed(0)}",
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                  ),
                
                const SizedBox(height: 16),

                TextFormField(
                  initialValue: controller.berat > 0 ? controller.berat.toString() : "",
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Berat (Kg)",
                    border: OutlineInputBorder(),
                    suffixText: "kg",
                  ),
                  onChanged: (val) => controller.setBerat(double.tryParse(val) ?? 0),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  initialValue: controller.hargaPerKg > 0 ? controller.hargaPerKg.toString() : "",
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Harga per Kg",
                    border: OutlineInputBorder(),
                    prefixText: "Rp ",
                  ),
                  onChanged: (val) => controller.setHargaPerKg(double.tryParse(val) ?? 0),
                ),
                
                const Divider(height: 32, thickness: 1.5),

                _buildSummaryRow(
                  "Total Bayar", 
                  "Rp ${controller.totalBayar.toStringAsFixed(0)}",
                  isBold: true,
                  valueColor: Colors.green[700],
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  "Estimasi Sisa Kasbon", 
                  "Rp ${controller.sisaKasbonPetani.toStringAsFixed(0)}",
                  valueColor: Colors.orange[800],
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  "Sisa Uang Jalan Agen", 
                  "Rp ${controller.sisaUangJalanSetelah.toStringAsFixed(0)}",
                  valueColor: controller.sisaUangJalanSetelah < 0 ? Colors.red : Colors.blueGrey,
                ),

                if (controller.error != null && controller.selectedPetani != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      controller.error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(
          value, 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isBold ? 16 : 14,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
