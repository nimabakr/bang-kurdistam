import 'package:flutter/material.dart';

import '../app_state.dart';
import '../domain/city.dart';
import '../services/city_location.dart';
import '../services/localization.dart';

class CityPickerScreen extends StatefulWidget {
  const CityPickerScreen({required this.state, super.key});

  final BangAppState state;

  @override
  State<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends State<CityPickerScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _isLocating = false;
  String? _locationError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = cities.where((city) => city.matches(_query)).toList()
      ..sort((a, b) {
        final aFavorite = widget.state.favoriteCityIds.contains(a.id);
        final bFavorite = widget.state.favoriteCityIds.contains(b.id);
        if (aFavorite != bFavorite) return aFavorite ? -1 : 1;
        return a.kurdishName.compareTo(b.kurdishName);
      });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.text('شار'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (_isLocating)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  tooltip: context.l10n.text('بەکارهێنانی شوێنی ئێستا'),
                  onPressed: _selectNearestCity,
                  icon: const Icon(Icons.my_location_rounded),
                ),
              IconButton(
                tooltip: context.l10n.text('داخستن'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: context.l10n.text(
                'گەڕان بە ناوی کوردی، عەرەبی یان ئینگلیزی',
              ),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: context.l10n.text('پاککردنەوە'),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (_locationError case final error?)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 10),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                context.l10n.text(error),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(context.l10n.text('هیچ شارێک نەدۆزرایەوە')),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final city = filtered[index];
                    final isSelected = city.id == widget.state.selectedCity.id;
                    final isFavorite = widget.state.favoriteCityIds.contains(
                      city.id,
                    );
                    return ListTile(
                      contentPadding: const EdgeInsetsDirectional.only(
                        start: 4,
                        end: 4,
                      ),
                      leading: Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.location_on_outlined,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        context.l10n.cityName(city),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(context.l10n.text(city.governorate)),
                      trailing: IconButton(
                        tooltip: isFavorite
                            ? context.l10n.text('لابردن لە دڵخوازەکان')
                            : context.l10n.text('زیادکردن بۆ دڵخوازەکان'),
                        onPressed: () async {
                          await widget.state.toggleFavorite(city);
                          if (mounted) setState(() {});
                        },
                        icon: Icon(
                          isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFavorite
                              ? Theme.of(context).colorScheme.tertiary
                              : null,
                        ),
                      ),
                      onTap: () async {
                        await widget.state.selectCity(city);
                        if (context.mounted) Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _selectNearestCity() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
    });
    try {
      final city = await CityLocation.nearestTimetabledCity();
      await widget.state.selectCity(city);
      if (mounted) Navigator.pop(context);
    } on CityLocationException catch (error) {
      if (mounted) setState(() => _locationError = error.message);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }
}
