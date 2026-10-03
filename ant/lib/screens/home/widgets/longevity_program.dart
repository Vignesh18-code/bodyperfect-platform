import 'package:flutter/material.dart';

class LongevityProgram {
  final String imagePath;
  final String title;
  final String? cardTitle;
  final String subtitle;
  final String description;
  final Color color;
  final IconData icon;

  const LongevityProgram({
    required this.imagePath,
    required this.title,
    this.cardTitle,
    required this.subtitle,
    required this.description,
    required this.color,
    this.icon = Icons.lens_blur_rounded,
  });

  static const catalog = [
    LongevityProgram(
      imagePath: 'assets/images/services/weightloss-slimming.jpg',
      title: 'Weightloss & Slimming',
      subtitle: 'Body & wellness',
      description:
          'Discuss your weight-management goals with the clinic team and explore a personalised consultation, including available slimming and body-contouring services.',
      color: Color(0xFF9C4DFF),
      icon: Icons.monitor_weight_outlined,
    ),
    LongevityProgram(
      imagePath: 'assets/images/services/beauty-aesthetics.jpg',
      title: 'Beauty & Aesthetics',
      subtitle: 'Skin & beauty',
      description:
          'Explore the clinic’s skin and aesthetic services. Share your concerns and preferences so the team can discuss suitable options at your consultation.',
      color: Color(0xFFF72585),
      icon: Icons.face_retouching_natural,
    ),
    LongevityProgram(
      imagePath: 'assets/images/services/pain-management.jpg',
      title: 'Pain Management',
      subtitle: 'Move with ease',
      description:
          'Book a consultation to discuss pain, movement and everyday comfort with the clinic team, including the assessment and care options available.',
      color: Color(0xFF4361EE),
      icon: Icons.accessibility_new_rounded,
    ),
    LongevityProgram(
      imagePath: 'assets/images/services/ayurveda.jpg',
      title: 'Ayurveda',
      subtitle: 'Traditional care',
      description:
          'Learn about the clinic’s Ayurveda services and discuss your wellness goals, health history and questions with the team before choosing a treatment.',
      color: Color(0xFF06B78A),
      icon: Icons.spa_outlined,
    ),
    LongevityProgram(
      imagePath: 'assets/images/services/gut-dna.jpg',
      title: 'Gut & DNA',
      subtitle: 'Personalised care',
      description:
          'Speak with the clinic team about gut-health and DNA-related services, what an assessment involves and how the available options relate to your goals.',
      color: Color(0xFF7055D8),
      icon: Icons.biotech_rounded,
    ),
    LongevityProgram(
      imagePath: 'assets/images/services/regenerative.jpg',
      title: 'Regenerative',
      subtitle: 'Explore options',
      description:
          'Ask the clinic team about its regenerative services, including PRP, exosome and stem-cell consultations. The clinician can explain suitability, potential risks and available options.',
      color: Color(0xFF9C4DFF),
      icon: Icons.join_inner_rounded,
    ),
    LongevityProgram(
      imagePath: 'assets/images/services/iv-therapy.jpg',
      title: 'IV Therapy',
      subtitle: 'Clinic consultation',
      description:
          'Speak with the clinic team about IV therapy options, your health history and what a consultation involves before deciding on a treatment.',
      color: Color(0xFF4361EE),
      icon: Icons.opacity_rounded,
    ),
    LongevityProgram(
      imagePath: 'assets/images/services/longevity.jpg',
      title: 'Longevity',
      subtitle: 'Long-term wellbeing',
      description:
          'Discuss your long-term wellness goals and the clinic’s longevity services. The team can explain the available assessments and help plan your consultation.',
      color: Color(0xFF06B78A),
      icon: Icons.favorite_border_rounded,
    ),
    LongevityProgram(
      imagePath: 'assets/images/services/lifestyle-care.jpg',
      title: 'Reverse Lifestyle Diseases',
      cardTitle: 'Lifestyle Diseases',
      subtitle: 'Lifestyle support',
      description:
          'Explore the clinic’s lifestyle-care service and discuss your health concerns, nutrition and daily routines with a clinician. Your consultation will help clarify appropriate next steps.',
      color: Color(0xFF7055D8),
      icon: Icons.health_and_safety_outlined,
    ),
    LongevityProgram(
      imagePath: 'assets/images/services/personal-training.png',
      title: 'Personal Training',
      subtitle: 'Fitness for you',
      description:
          'Meet the team to discuss your fitness goals, current activity level and personal-training options, including how to arrange a gym consultation.',
      color: Color(0xFF4361EE),
      icon: Icons.fitness_center_rounded,
    ),
    LongevityProgram(
      imagePath: 'assets/images/services/abb-diet-plan.jpg',
      title: 'Dr. Jaison’s ABB Diet Plan',
      cardTitle: 'ABB Diet Plan',
      subtitle: 'Nutrition care',
      description:
          'Learn about Dr. Jaison’s ABB Diet Plan and discuss your food preferences, routines and nutrition goals with the clinic team during a personalised consultation.',
      color: Color(0xFF06B78A),
      icon: Icons.restaurant_rounded,
    ),
    LongevityProgram(
      imagePath: 'assets/images/services/transformation-program.jpg',
      title: 'Dr. Jaison’s “20 KGs in 60 Days” Transformation Program',
      cardTitle: '20 KGs in 60 Days',
      subtitle: 'Dr. Jaison’s plan',
      description:
          'Ask about Dr. Jaison’s “20 KGs in 60 Days” program. Discuss eligibility, the proposed plan and realistic individual goals with the clinic team; the program name is not a guarantee of results.',
      color: Color(0xFFF72585),
      icon: Icons.track_changes_rounded,
    ),
  ];
}
