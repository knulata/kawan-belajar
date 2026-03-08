import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/models/parent_data.dart';
import '../../core/models/student.dart';
import '../../core/services/whatsapp_service.dart';

class ParentSetupScreen extends StatefulWidget {
  const ParentSetupScreen({super.key});

  @override
  State<ParentSetupScreen> createState() => _ParentSetupScreenState();
}

class _ParentSetupScreenState extends State<ParentSetupScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final parentData = context.read<ParentDataProvider>();
    _phoneController.text = parentData.parentPhone ?? '';
    _nameController.text = parentData.parentName ?? '';
  }

  Future<void> _save() async {
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();

    if (phone.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi nama dan nomor HP orang tua ya!')),
      );
      return;
    }

    setState(() => _saving = true);
    final parentData = context.read<ParentDataProvider>();
    final student = context.read<StudentProvider>().student!;

    final formattedPhone = WhatsAppService.formatPhoneNumber(phone);
    await parentData.setParentInfo(phone: formattedPhone, name: name);

    // Send welcome message
    await WhatsAppService.sendAlert(
      parentPhone: formattedPhone,
      parentName: name,
      studentName: student.name,
      alertType: 'welcome',
      message:
          'Halo $name! Kawan Belajar sekarang terhubung. Anda akan menerima laporan belajar ${student.name} dan pengingat PR/ujian di WhatsApp ini.',
    );

    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp orang tua berhasil dihubungkan! ✅'),
          backgroundColor: Color(0xFF25D366),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Putuskan WhatsApp?'),
        content: const Text(
            'Orang tua tidak akan menerima laporan dan pengingat lagi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Putuskan', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await context.read<ParentDataProvider>().removeParent();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentData = context.watch<ParentDataProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        title: const Text('Pengaturan Orang Tua',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                FadeInDown(
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: Text('📱', style: TextStyle(fontSize: 56)),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Hubungkan WhatsApp Orang Tua',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Orang tua akan mendapat:\n• Laporan belajar harian\n• Pengingat PR & ujian\n• Notifikasi pencapaian anak',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),

                        // Parent name
                        TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Nama Orang Tua',
                            hintText: 'Contoh: Mama, Papa, Ibu Siti',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Phone number
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Nomor WhatsApp',
                            hintText: '08123456789',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            prefixText: '+62 ',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // WhatsApp alerts toggle
                        if (parentData.isParentLinked) ...[
                          SwitchListTile(
                            title: const Text('Pengingat PR/Ujian'),
                            subtitle: const Text(
                                'Kirim notifikasi saat ada PR atau ujian'),
                            value: parentData.whatsappAlertsEnabled,
                            onChanged: (v) =>
                                parentData.toggleWhatsappAlerts(v),
                            activeColor: const Color(0xFF25D366),
                          ),
                          const Divider(),
                        ],

                        const SizedBox(height: 16),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.message, color: Colors.white),
                            label: Text(
                              parentData.isParentLinked
                                  ? 'Perbarui'
                                  : 'Hubungkan WhatsApp',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),

                        if (parentData.isParentLinked) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _disconnect,
                            child: const Text(
                              'Putuskan WhatsApp',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
