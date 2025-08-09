// ignore_for_file: unused_local_variable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trace/controllers/video_recommendation_controller.dart';

class CategoryFilterWidget extends StatelessWidget {
  final VideoRecommendationController controller;
  final double height;
  final bool showTitle;
  final VoidCallback? onFiltersChanged;

  const CategoryFilterWidget({
    Key? key,
    required this.controller,
    this.height = 100.0,
    this.showTitle = true,
    this.onFiltersChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTitle) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
            child: _buildTitle(context),
          ),
        ],
        SizedBox(
          height: height,
          child: Obx(() => _buildCategoriesList(context)),
        ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Categorias',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Obx(() {
          if (controller.filtersEnabled.value) {
            return TextButton.icon(
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Limpar Filtros'),
              onPressed: () {
                controller.clearAllFilters();
                if (onFiltersChanged != null) {
                  onFiltersChanged!();
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.secondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            );
          } else {
            return const SizedBox();
          }
        }),
      ],
    );
  }

  Widget _buildCategoriesList(BuildContext context) {
    // Obter categorias recomendadas se disponíveis
    List<String> categories = controller.getRecommendedCategories();

    // Adicionar outras categorias populares
    if (controller.availableCategories.isNotEmpty) {
      final sortedCategories = controller.availableCategories.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in sortedCategories) {
        if (categories.length >= 15) break; // Limitar a 15 categorias
        if (!categories.contains(entry.key) &&
            !controller.dislikedCategories.contains(entry.key)) {
          categories.add(entry.key);
        }
      }
    }

    if (categories.isEmpty) {
      return const Center(
        child: Text('Carregando categorias...'),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemBuilder: (context, index) {
        final category = categories[index];
        return _buildCategoryChip(context, category);
      },
    );
  }

  Widget _buildCategoryChip(BuildContext context, String category) {
    final isSelected = controller.activeFilters.contains(category);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Obx(
        () => FilterChip(
          label: Text(_formatCategoryName(category)),
          selected: controller.activeFilters.contains(category),
          onSelected: (selected) {
            controller.toggleCategoryFilter(category);
            if (onFiltersChanged != null) {
              onFiltersChanged!();
            }
          },
          avatar: _getCategoryIcon(category),
          backgroundColor: Theme.of(context).cardColor,
          selectedColor:
              Theme.of(context).colorScheme.secondary.withOpacity(0.3),
          checkmarkColor: Theme.of(context).colorScheme.secondary,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          labelStyle: TextStyle(
            color: controller.activeFilters.contains(category)
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: controller.activeFilters.contains(category)
                ? FontWeight.bold
                : FontWeight.normal,
          ),
          elevation: controller.activeFilters.contains(category) ? 2 : 1,
        ),
      ),
    );
  }

  // Formatar nome da categoria para exibição
  String _formatCategoryName(String category) {
    if (category.isEmpty) return 'Geral';

    // Primeira letra maiúscula, resto minúsculo
    return category[0].toUpperCase() + category.substring(1).toLowerCase();
  }

  // Obter ícone correspondente à categoria
  Widget? _getCategoryIcon(String category) {
    IconData iconData;

    switch (category.toLowerCase()) {
      case 'music':
      case 'música':
        iconData = Icons.music_note;
        break;
      case 'food':
      case 'comida':
        iconData = Icons.restaurant;
        break;
      case 'travel':
      case 'viagem':
        iconData = Icons.flight;
        break;
      case 'fitness':
      case 'workout':
        iconData = Icons.fitness_center;
        break;
      case 'comedy':
      case 'comédia':
        iconData = Icons.sentiment_very_satisfied;
        break;
      case 'news':
      case 'notícias':
        iconData = Icons.newspaper;
        break;
      case 'gaming':
      case 'jogos':
        iconData = Icons.sports_esports;
        break;
      case 'education':
      case 'educação':
        iconData = Icons.school;
        break;
      case 'fashion':
      case 'moda':
        iconData = Icons.shopping_bag;
        break;
      case 'tech':
      case 'tecnologia':
        iconData = Icons.devices;
        break;
      case 'sports':
      case 'esportes':
        iconData = Icons.sports_basketball;
        break;
      case 'beauty':
      case 'beleza':
        iconData = Icons.face;
        break;
      default:
        iconData = Icons.category;
        break;
    }

    return Icon(
      iconData,
      size: 18,
      color: Colors.grey[600],
    );
  }
}

// Widget para mostrar categorias em uma grade
class CategoryGridWidget extends StatelessWidget {
  final VideoRecommendationController controller;
  final VoidCallback? onFiltersChanged;

  const CategoryGridWidget({
    Key? key,
    required this.controller,
    this.onFiltersChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final allCategories = controller.availableCategories;

      if (allCategories.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      final sortedCategories = allCategories.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Filtrar por Categoria',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (controller.filtersEnabled.value)
                  TextButton.icon(
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Limpar Todos'),
                    onPressed: () {
                      controller.clearAllFilters();
                      if (onFiltersChanged != null) {
                        onFiltersChanged!();
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Obx(() => Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  children: sortedCategories.map((entry) {
                    final category = entry.key;
                    final count = entry.value;
                    final isSelected =
                        controller.activeFilters.contains(category);

                    return ActionChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatCategoryName(category),
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.secondary
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              count.toString(),
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          )
                        ],
                      ),
                      avatar: _getCategoryIcon(category),
                      backgroundColor: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.2)
                          : Theme.of(context).cardColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      elevation: isSelected ? 3 : 1,
                      onPressed: () {
                        controller.toggleCategoryFilter(category);
                        if (onFiltersChanged != null) {
                          onFiltersChanged!();
                        }
                      },
                    );
                  }).toList(),
                )),
          ],
        ),
      );
    });
  }

  // Formatar nome da categoria para exibição
  String _formatCategoryName(String category) {
    if (category.isEmpty) return 'Geral';

    // Primeira letra maiúscula, resto minúsculo
    return category[0].toUpperCase() + category.substring(1).toLowerCase();
  }

  // Obter ícone correspondente à categoria
  Widget? _getCategoryIcon(String category) {
    IconData iconData;

    switch (category.toLowerCase()) {
      case 'music':
      case 'música':
        iconData = Icons.music_note;
        break;
      case 'food':
      case 'comida':
        iconData = Icons.restaurant;
        break;
      case 'travel':
      case 'viagem':
        iconData = Icons.flight;
        break;
      case 'fitness':
      case 'workout':
        iconData = Icons.fitness_center;
        break;
      case 'comedy':
      case 'comédia':
        iconData = Icons.sentiment_very_satisfied;
        break;
      default:
        iconData = Icons.category;
        break;
    }

    return Icon(
      iconData,
      size: 18,
    );
  }
}
