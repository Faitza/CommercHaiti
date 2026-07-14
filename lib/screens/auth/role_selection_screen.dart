import 'package:flutter/material.dart';

/// Choix du rôle — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/screens/auth/role_selection_screen.dart
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole; // 'seller' ou 'customer'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Vous êtes ?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D2B5E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choisissez votre profil pour continuer',
                style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 40),

              // Carte Vendeur
              _RoleCard(
                titre: 'Vendeur',
                description: 'Je vends des produits et gère ma boutique',
                icon: Icons.storefront_outlined,
                selected: _selectedRole == 'seller',
                onTap: () => setState(() => _selectedRole = 'seller'),
              ),
              const SizedBox(height: 16),

              // Carte Client
              _RoleCard(
                titre: 'Client',
                description: 'Je cherche des produits et passe des commandes',
                icon: Icons.shopping_bag_outlined,
                selected: _selectedRole == 'customer',
                onTap: () => setState(() => _selectedRole = 'customer'),
              ),

              const Spacer(),

              // Bouton Continuer
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedRole != null
                        ? const Color(0xFF0D2B5E)
                        : const Color(0xFFCCCCCC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _selectedRole == null
                      ? null
                      : () {
                          Navigator.pushNamed(
                            context,
                            '/auth',
                            arguments: {'role': _selectedRole},
                          );
                        },
                  child: const Text(
                    'Continuer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String titre;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.titre,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEEF3FB) : Colors.white,
          border: Border.all(
            color: selected ? const Color(0xFF0D2B5E) : const Color(0xFFCCCCCC),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF0D2B5E)
                    : const Color(0xFFF2F4F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : const Color(0xFF0D2B5E),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? const Color(0xFF0D2B5E)
                          : const Color(0xFF1A1F36),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF0D2B5E),
              ),
          ],
        ),
      ),
    );
  }
}