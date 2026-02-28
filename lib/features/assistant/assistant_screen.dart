import 'package:flutter/material.dart';
import 'package:project_test2/core/theme.dart';

class AssistantSheet extends StatelessWidget {
  const AssistantSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85, // تغطي 85% من الشاشة
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                Icon(Icons.smart_toy_rounded, color: AppTheme.primary, size: 30), // [cite: 1]
                     SizedBox(width: 10),
                     Text("AI Assistant", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          
          // Chat Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
            _buildBotMessage("Hello! I'm your university assistant. How can I help you regarding schedules, grades, or events today?"), // [cite: 3]
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10, runSpacing: 10,
                  children: [
                    _buildChip("📅 Academic Calendar"), // [cite: 3]
              _buildChip("🏛 Departments"), // [cite: 3]
                  _buildChip("🎨 Activities"), // [cite: 3]
                  ],
                ),
              ],
            ),
          ),

          // Input Field
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                    hintText: "Type your message...", // [cite: 3]
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: (){}),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotMessage(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200)),
          child: const Icon(Icons.smart_toy, color: Colors.purple),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topRight: Radius.circular(20), bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            ),
            child: Text(text, style: const TextStyle(height: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String label) {
    return ActionChip(
      label: Text(label),
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppTheme.primary),
      labelStyle: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
      onPressed: () {},
    );
  }
}