import 'package:flutter/material.dart';
import '../services/address_search_service.dart';

class AddressSearchWidget extends StatefulWidget {
  final String? initialAddress;
  final String hintText;
  final Function(AddressSearchResult) onAddressSelected;
  final VoidCallback? onCurrentLocationTap;
  final bool showCurrentLocationOption;

  const AddressSearchWidget({
    super.key,
    this.initialAddress,
    required this.hintText,
    required this.onAddressSelected,
    this.onCurrentLocationTap,
    this.showCurrentLocationOption = true,
  });

  @override
  State<AddressSearchWidget> createState() => _AddressSearchWidgetState();
}

class _AddressSearchWidgetState extends State<AddressSearchWidget> {
  final TextEditingController _controller = TextEditingController();
  final AddressSearchService _searchService = AddressSearchService();
  List<AddressSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      _controller.text = widget.initialAddress!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = _searchService.getPopularDestinations();
        _showResults = true;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showResults = true;
    });

    try {
      final results = await _searchService.searchAddresses(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  bool _shouldFetchPlaceDetails(AddressSearchResult result) {
    // Custom suggestions and test fixtures use short IDs, while Google place IDs are long.
    return result.placeId.isNotEmpty && result.placeId.length > 20;
  }

  void _onResultTap(AddressSearchResult result) async {
    setState(() {
      _controller.text = result.formattedAddress;
      _showResults = false;
    });

    // If this looks like a real Google place ID, fetch full details
    if (_shouldFetchPlaceDetails(result)) {
      final detailedResult = await _searchService.getPlaceDetails(result.placeId);
      if (detailedResult != null) {
        widget.onAddressSelected(detailedResult);
        return;
      }
    }

    widget.onAddressSelected(result);
  }

  void _onCurrentLocationTap() {
    setState(() {
      _controller.text = 'Current Location';
      _showResults = false;
    });
    if (widget.onCurrentLocationTap != null) {
      widget.onCurrentLocationTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _controller.clear();
                        setState(() {
                          _searchResults = [];
                          _showResults = false;
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: _onSearchChanged,
            onTap: () {
              if (_searchResults.isNotEmpty || _controller.text.isEmpty) {
                setState(() {
                  if (_controller.text.isEmpty) {
                    _searchResults = _searchService.getPopularDestinations();
                  }
                  _showResults = true;
                });
              }
            },
          ),
        ),
        if (_showResults) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Current location option
                if (widget.showCurrentLocationOption)
                  ListTile(
                    leading: const Icon(Icons.my_location, color: Colors.blue),
                    title: const Text('Current Location'),
                    subtitle: const Text('Use my current location'),
                    onTap: _onCurrentLocationTap,
                  ),
                
                // Loading indicator
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                
                // Popular destinations header (when showing suggestions)
                if (!_isSearching && _controller.text.isEmpty && _searchResults.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Popular Destinations',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),

                // Search results
                if (!_isSearching)
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        final isPopular = _controller.text.isEmpty;
                        return ListTile(
                          leading: Icon(
                            isPopular ? Icons.star : Icons.location_on, 
                            color: isPopular ? Colors.orange : Colors.grey,
                          ),
                          title: Text(
                            result.mainText ?? result.formattedAddress,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: result.secondaryText != null
                              ? Text(result.secondaryText!)
                              : null,
                          onTap: () => _onResultTap(result),
                        );
                      },
                    ),
                  ),
                
                // No results message (only for actual searches, not empty field)
                if (!_isSearching && _searchResults.isEmpty && _controller.text.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No results found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
