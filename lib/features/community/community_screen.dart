import 'package:flutter/material.dart';
import 'package:project_test2/core/theme.dart';
import '../../core/animations.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          "Community Hub",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.textMain,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85, 
              children: [
                FadeInAnimation(
                  delay: 100,
                  child: _buildFancyCard("Student\nAffairs", Icons.assignment_ind_rounded, AppTheme.info),
                ),
                FadeInAnimation(
                  delay: 200,
                  child: _buildFancyCard("Campus\nActivities", Icons.local_activity_rounded, AppTheme.warning),
                ),
                FadeInAnimation(
                  delay: 300,
                  child: _buildFancyCard("Youth\nCare", Icons.volunteer_activism_rounded, AppTheme.accent),
                ),
                FadeInAnimation(
                  delay: 400,
                  child: _buildFancyCard("My\nDepartment", Icons.domain_rounded, AppTheme.secondary),
                ),
              ],
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Study Groups",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMain,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "+ Create",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildListDelegate([
              FadeInAnimation(
                delay: 500,
                child: _buildGroupTile("Flutter Developers", "35 Members • Active", AppTheme.info),
              ),
              FadeInAnimation(
                delay: 600,
                child: _buildGroupTile("Data Structs Exam", "12 Members • 2h ago", AppTheme.success),
              ),
              FadeInAnimation(
                delay: 700,
                child: _buildGroupTile("Graduation Project 25", "5 Members • Private", AppTheme.error),
              ),
              const SizedBox(height: 100),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildFancyCard(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: color),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: Text(
              title, 
              textAlign: TextAlign.center, 
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                height: 1.3,
                color: AppTheme.textMain,
              ),
              maxLines: 2, 
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTile(String name, String details, Color iconColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [iconColor.withOpacity(0.2), iconColor.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.groups_rounded, color: iconColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppTheme.textTertiary,
          ),
        ],
      ),
    );
  }
}