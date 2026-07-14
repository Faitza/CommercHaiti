import 'package:flutter/material.dart';

/// Paramètres Vendeur — Falexson MERCIVAL
/// Branch : feature/ui-settings
/// Path : lib/screens/settings/settings_screen.dart
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        title: const Text('Paramètres'),
      ),
      body: ListView(
        children: [
          _sectionTitle('Ma boutique'),
          _item(context, Icons.store_outlined, 'Infos boutique', () {}),
          _item(context, Icons.image_outlined, 'Logo', () {}),
          _item(context, Icons.location_on_outlined, 'Zones de livraison', () {}),
          const Divider(),
          _sectionTitle('Préférences'),
          _switchItem('Notifications', true, (_) {}),
          _switchItem('Mode sombre', false, (_) {
            // TODO : ThemeProvider.toggle()
          }),
          const Divider(),
          _sectionTitle('Compte'),
          _item(context, Icons.logout, 'Déconnexion', () {
            // TODO : AuthProvider.signOut()
          }, color: const Color(0xFFE63946)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(t.toUpperCase(),
            style: const TextStyle(fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF999999), letterSpacing: 1)),
      );

  Widget _item(BuildContext ctx, IconData icon, String label,
      VoidCallback onTap, {Color? color}) =>
      ListTile(
        tileColor: Colors.white,
        leading: Icon(icon, color: color ?? const Color(0xFF0D2B5E)),
        title: Text(label,
            style: TextStyle(color: color ?? const Color(0xFF1A1F36))),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
        onTap: onTap,
      );

  Widget _switchItem(String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        tileColor: Colors.white,
        title: Text(label),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF0D2B5E),
      );
}