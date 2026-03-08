import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/parent_data.dart';
import '../../core/models/student.dart';
import '../../core/services/whatsapp_service.dart';

class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({super.key});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _titleController = TextEditingController();
  String _selectedSubject = 'Matematika';
  String _selectedType = 'homework';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  bool _saving = false;

  final _subjects = [
    'Matematika',
    'Bahasa Indonesia',
    'Bahasa Mandarin',
    'IPA (Sains)',
    'IPS',
    'English',
    'PKN',
  ];

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tulis judul pengingat dulu ya!')),
      );
      return;
    }

    setState(() => _saving = true);

    final parentData = context.read<ParentDataProvider>();
    final student = context.read<StudentProvider>().student!;

    final reminder = ScheduledReminder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      subject: _selectedSubject,
      dueDate: _dueDate,
      type: _selectedType,
      whatsappEnabled: parentData.whatsappAlertsEnabled,
    );

    await parentData.addReminder(reminder);

    // Send WhatsApp notification if enabled
    if (parentData.isParentLinked && parentData.whatsappAlertsEnabled) {
      final typeLabel = _selectedType == 'test' ? 'Ujian' : 'PR';
      await WhatsAppService.scheduleReminder(
        parentPhone: parentData.parentPhone!,
        parentName: parentData.parentName!,
        studentName: student.name,
        title: title,
        subject: _selectedSubject,
        dueDate: _dueDate,
        type: _selectedType,
      );

      // Also send immediate notification
      final daysLeft = _dueDate.difference(DateTime.now()).inDays;
      await WhatsAppService.sendAlert(
        parentPhone: parentData.parentPhone!,
        parentName: parentData.parentName!,
        studentName: student.name,
        alertType: _selectedType,
        message:
            '$typeLabel baru untuk ${student.name}!\n\n'
            '📚 $_selectedSubject: $title\n'
            '📅 Tenggat: ${_dueDate.day}/${_dueDate.month}/${_dueDate.year}\n'
            '⏰ $daysLeft hari lagi\n\n'
            'Ingatkan ${student.name} untuk mempersiapkan ya!',
      );
    }

    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengingat berhasil ditambahkan! ✅'),
          backgroundColor: Color(0xFF7B1FA2),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        title: const Text('Tambah Pengingat',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                // Type selector
                Row(
                  children: [
                    Expanded(
                      child: _TypeButton(
                        icon: '📚',
                        label: 'PR',
                        selected: _selectedType == 'homework',
                        onTap: () =>
                            setState(() => _selectedType = 'homework'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TypeButton(
                        icon: '📝',
                        label: 'Ujian',
                        selected: _selectedType == 'test',
                        onTap: () => setState(() => _selectedType = 'test'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Title
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: _selectedType == 'test'
                        ? 'Nama Ujian'
                        : 'Judul PR',
                    hintText: _selectedType == 'test'
                        ? 'Contoh: Ulangan Harian Bab 3'
                        : 'Contoh: Latihan soal hal. 45',
                    prefixIcon: const Icon(Icons.edit_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                  ),
                ),
                const SizedBox(height: 16),

                // Subject
                DropdownButtonFormField<String>(
                  value: _selectedSubject,
                  decoration: InputDecoration(
                    labelText: 'Mata Pelajaran',
                    prefixIcon: const Icon(Icons.school_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                  ),
                  items: _subjects
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedSubject = v!),
                ),
                const SizedBox(height: 16),

                // Due date
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Tanggal',
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                    ),
                    child: Text(
                      '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // WhatsApp note
                if (context.watch<ParentDataProvider>().isParentLinked &&
                    context.watch<ParentDataProvider>().whatsappAlertsEnabled)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.message,
                            size: 16, color: Color(0xFF25D366)),
                        const SizedBox(width: 6),
                        Text(
                          'Orang tua akan diberi tahu via WhatsApp',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B1FA2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Simpan Pengingat',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600),
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
    _titleController.dispose();
    super.dispose();
  }
}

class _TypeButton extends StatelessWidget {
  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF3E5F5) : const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF7B1FA2)
                  : Colors.grey.withAlpha(50),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? const Color(0xFF7B1FA2)
                      : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
