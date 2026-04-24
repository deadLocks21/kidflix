import 'package:flutter/material.dart';
import 'package:kidflix/core/application/dtos/catalog_row.dto.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/ui/pages/home/widgets/movie_card.widget.dart';

/// One horizontal row of [MovieCard]s, prefixed with a row label.
class CatalogRowWidget extends StatelessWidget {
  final CatalogRowDto row;
  final void Function(MovieDto movie) onMovieTap;

  const CatalogRowWidget({
    super.key,
    required this.row,
    required this.onMovieTap,
  });

  static const double _rowHeight = 300;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              row.label,
              style: theme.textTheme.titleLarge,
            ),
          ),
          SizedBox(
            height: _rowHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: row.movies.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final movie = row.movies[i];
                return MovieCard(
                  movie: movie,
                  onTap: () => onMovieTap(movie),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
