import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import '../config/app_config.dart';

class AddressSearchResult {
  final String formattedAddress;
  final String placeId;
  final LatLng location;
  final String? mainText;
  final String? secondaryText;

  AddressSearchResult({
    required this.formattedAddress,
    required this.placeId,
    required this.location,
    this.mainText,
    this.secondaryText,
  });

  factory AddressSearchResult.fromPlaceAutocomplete(
      Map<String, dynamic> json) {
    return AddressSearchResult(
      formattedAddress: json['description'] ?? '',
      placeId: json['place_id'] ?? '',
      location: const LatLng(0, 0), // Will be filled later with place details
      mainText: json['structured_formatting']?['main_text'],
      secondaryText: json['structured_formatting']?['secondary_text'],
    );
  }

  factory AddressSearchResult.fromGeocoding(
      Placemark placemark, LatLng location) {
    String formattedAddress = '';
    List<String> parts = [];

    if (placemark.street != null) parts.add(placemark.street!);
    if (placemark.locality != null) parts.add(placemark.locality!);
    if (placemark.administrativeArea != null) {
      parts.add(placemark.administrativeArea!);
    }
    if (placemark.postalCode != null) parts.add(placemark.postalCode!);

    formattedAddress = parts.join(', ');

    return AddressSearchResult(
      formattedAddress: formattedAddress,
      placeId: '', // Geocoding doesn't provide place IDs
      location: location,
      mainText: placemark.street ?? placemark.name,
      secondaryText: [placemark.locality, placemark.administrativeArea]
          .where((e) => e != null)
          .join(', '),
    );
  }

  AddressSearchResult copyWith({
    String? formattedAddress,
    String? placeId,
    LatLng? location,
    String? mainText,
    String? secondaryText,
  }) {
    return AddressSearchResult(
      formattedAddress: formattedAddress ?? this.formattedAddress,
      placeId: placeId ?? this.placeId,
      location: location ?? this.location,
      mainText: mainText ?? this.mainText,
      secondaryText: secondaryText ?? this.secondaryText,
    );
  }
}

class AddressSearchService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';

  // Use your *production* Vercel domain here
  static const String _proxyUrl =
      'https://cavpool-website.vercel.app/api';

  final Logger _logger = Logger();

  String get _googleApiKey => AppConfig.googleMapsApiKey;

  // Search for addresses using Google Places Autocomplete API
  Future<List<AddressSearchResult>> searchAddresses(String query) async {
    if (query.isEmpty) return [];

    try {
      List<AddressSearchResult> results = [];

      // First, check for campus landmarks and popular destinations
      final campusResults = _searchCampusLocations(query);
      results.addAll(campusResults);

      // Then try flexible search (includes establishments, landmarks, etc.)
      final flexibleResults = await _searchFlexible(query);
      results.addAll(flexibleResults);

      // Remove duplicates and limit results
      final uniqueResults = _removeDuplicateResults(results);
      
      // If we have good results, return them
      if (uniqueResults.isNotEmpty) {
        return uniqueResults.take(8).toList(); // Limit to 8 results
      }

      // Fallback to address only search
      return await _searchAddressesOnly(query);
    } catch (e) {
      _logger.e('Error searching addresses: $e');
      return [];
    }
  }

  // Search Grounds landmarks and popular destinations
  List<AddressSearchResult> _searchCampusLocations(String query) {
    final lowercaseQuery = query.toLowerCase();
    final matches = <AddressSearchResult>[];

    // UVA Grounds landmarks and popular destinations
    final campusLocations = {
      'rotunda': AddressSearchResult(
        formattedAddress: 'The Rotunda, University of Virginia, Charlottesville, VA',
        placeId: 'uva_rotunda',
        location: const LatLng(38.0356, -78.5034),
        mainText: 'The Rotunda',
        secondaryText: 'University of Virginia',
      ),
      'alderman library': AddressSearchResult(
        formattedAddress: 'Alderman Library, University of Virginia, Charlottesville, VA',
        placeId: 'uva_alderman',
        location: const LatLng(38.0374, -78.5057),
        mainText: 'Alderman Library',
        secondaryText: 'University of Virginia',
      ),
      'newcomb hall': AddressSearchResult(
        formattedAddress: 'Newcomb Hall, University of Virginia, Charlottesville, VA',
        placeId: 'uva_newcomb',
        location: const LatLng(38.0366, -78.5054),
        mainText: 'Newcomb Hall',
        secondaryText: 'Student Activities Building',
      ),
      'rice hall': AddressSearchResult(
        formattedAddress: 'Rice Hall, University of Virginia, Charlottesville, VA',
        placeId: 'uva_rice',
        location: const LatLng(38.0319, -78.5099),
        mainText: 'Rice Hall',
        secondaryText: 'School of Engineering',
      ),
      'barracks road': AddressSearchResult(
        formattedAddress: 'Barracks Road Shopping Center, Charlottesville, VA',
        placeId: 'barracks_road',
        location: const LatLng(38.0481, -78.5264),
        mainText: 'Barracks Road Shopping Center',
        secondaryText: 'Shopping & Dining',
      ),
      'downtown mall': AddressSearchResult(
        formattedAddress: 'Downtown Mall, Charlottesville, VA',
        placeId: 'downtown_mall',
        location: const LatLng(38.0293, -78.4767),
        mainText: 'Downtown Mall',
        secondaryText: 'Historic Pedestrian Mall',
      ),
      'hospital': AddressSearchResult(
        formattedAddress: 'UVA Health System, Charlottesville, VA',
        placeId: 'uva_hospital',
        location: const LatLng(38.0341, -78.4968),
        mainText: 'UVA Health System',
        secondaryText: 'University Hospital',
      ),
      'airport': AddressSearchResult(
        formattedAddress: 'Charlottesville Albemarle Airport, Charlottesville, VA',
        placeId: 'cville_airport',
        location: const LatLng(38.1386, -78.4529),
        mainText: 'Charlottesville Airport',
        secondaryText: 'CHO Airport',
      ),
      'walmart': AddressSearchResult(
        formattedAddress: 'Walmart Supercenter, Rio Road, Charlottesville, VA',
        placeId: 'walmart_rio',
        location: const LatLng(38.0676, -78.4543),
        mainText: 'Walmart (Rio Road)',
        secondaryText: 'Grocery & Shopping',
      ),
      'target': AddressSearchResult(
        formattedAddress: 'Target, Barracks Road, Charlottesville, VA',
        placeId: 'target_barracks',
        location: const LatLng(38.0465, -78.5242),
        mainText: 'Target (Barracks Road)',
        secondaryText: 'Shopping',
      ),
    };

    // Find matching locations
    for (final entry in campusLocations.entries) {
      if (entry.key.contains(lowercaseQuery) || 
          entry.value.mainText!.toLowerCase().contains(lowercaseQuery)) {
        matches.add(entry.value);
      }
    }

    return matches;
  }

  // Remove duplicate results based on similar addresses or coordinates
  List<AddressSearchResult> _removeDuplicateResults(List<AddressSearchResult> results) {
    final unique = <AddressSearchResult>[];
    final seenAddresses = <String>{};
    
    for (final result in results) {
      final key = result.formattedAddress.toLowerCase();
      if (!seenAddresses.contains(key)) {
        seenAddresses.add(key);
        unique.add(result);
      }
    }
    
    return unique;
  }

  // Flexible search that includes establishments, landmarks, and addresses
  Future<List<AddressSearchResult>> _searchFlexible(String query) async {
    try {
      late final Uri url;

      if (kIsWeb) {
        // Use proxy endpoint on web to avoid CORS
        url = Uri.parse(
          '$_proxyUrl/places/autocomplete'
          '?input=${Uri.encodeComponent(query)}'
          '&components=country:us'
          '&location=38.0336,-78.5080'  // UVA coordinates for bias
          '&radius=50000',  // 50km radius around UVA
        );
      } else {
        // Use direct API on mobile
        url = Uri.parse(
          '$_baseUrl/place/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&key=$_googleApiKey'
          '&components=country:us'
          '&location=38.0336,-78.5080'  // UVA coordinates for bias
          '&radius=50000',  // 50km radius around UVA
        );
      }

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          return predictions
              .map(
                (prediction) =>
                    AddressSearchResult.fromPlaceAutocomplete(prediction),
              )
              .toList();
        } else {
          _logger.w('Google Places API flexible search error: ${data['status']}');
          return [];
        }
      } else {
        _logger.e('HTTP error in flexible search: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      _logger.e('Error in flexible search: $e');
      return [];
    }
  }

  // Address-only search as fallback
  Future<List<AddressSearchResult>> _searchAddressesOnly(String query) async {
    try {
      late final Uri url;

      if (kIsWeb) {
        // Use proxy endpoint on web to avoid CORS
        url = Uri.parse(
          '$_proxyUrl/places/autocomplete'
          '?input=${Uri.encodeComponent(query)}'
          '&types=address'
          '&components=country:us',
        );
      } else {
        // Use direct API on mobile
        url = Uri.parse(
          '$_baseUrl/place/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&key=$_googleApiKey'
          '&types=address'
          '&components=country:us',
        );
      }

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          return predictions
              .map(
                (prediction) =>
                    AddressSearchResult.fromPlaceAutocomplete(prediction),
              )
              .toList();
        } else {
          _logger.w('Google Places API address search error: ${data['status']}');
          return [];
        }
      } else {
        _logger.e('HTTP error in address search: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      _logger.e('Error in address search: $e');
      return [];
    }
  }

  // Get place details including coordinates for a place ID
  Future<AddressSearchResult?> getPlaceDetails(String placeId) async {
    try {
      late final Uri url;

      if (kIsWeb) {
        // Use proxy endpoint on web to avoid CORS
        url = Uri.parse(
          '$_proxyUrl/places/details'
          '?place_id=${Uri.encodeComponent(placeId)}'
          '&fields=geometry,formatted_address,name',
        );
      } else {
        // Use direct API on mobile
        url = Uri.parse(
          '$_baseUrl/place/details/json'
          '?place_id=$placeId'
          '&key=$_googleApiKey'
          '&fields=geometry,formatted_address,name',
        );
      }

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final result = data['result'];
          final geometry = result['geometry']['location'];

          return AddressSearchResult(
            formattedAddress: result['formatted_address'] ?? '',
            placeId: placeId,
            location: LatLng(
              geometry['lat']?.toDouble() ?? 0.0,
              geometry['lng']?.toDouble() ?? 0.0,
            ),
            mainText: result['name'],
            secondaryText: result['formatted_address'],
          );
        } else {
          _logger.w('Google Places Details API error: ${data['status']}');
          return null;
        }
      } else {
        _logger.e('HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.e('Error getting place details: $e');
      return null;
    }
  }

  // Reverse geocode coordinates to get address
  Future<AddressSearchResult?> getAddressFromCoordinates(
      LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        return AddressSearchResult.fromGeocoding(placemarks.first, location);
      }
      return null;
    } catch (e) {
      _logger.e('Error reverse geocoding: $e');
      return null;
    }
  }

  // Get coordinates from address string using basic geocoding
  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        final location = locations.first;
        return LatLng(location.latitude, location.longitude);
      }
      return null;
    } catch (e) {
      _logger.e('Error geocoding address: $e');
      return null;
    }
  }

  // Search for popular places near a location
  Future<List<AddressSearchResult>> searchNearbyPlaces({
    required LatLng location,
    String type = 'establishment',
    int radius = 5000,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/place/nearbysearch/json'
        '?location=${location.latitude},${location.longitude}'
        '&radius=$radius'
        '&type=$type'
        '&key=$_googleApiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          return results.map((place) {
            final geometry = place['geometry']['location'];
            return AddressSearchResult(
              formattedAddress: place['vicinity'] ?? '',
              placeId: place['place_id'] ?? '',
              location: LatLng(
                geometry['lat']?.toDouble() ?? 0.0,
                geometry['lng']?.toDouble() ?? 0.0,
              ),
              mainText: place['name'],
              secondaryText: place['vicinity'],
            );
          }).toList();
        }
      }
      return [];
    } catch (e) {
      _logger.e('Error searching nearby places: $e');
      return [];
    }
  }

  // Get popular destination suggestions
  List<AddressSearchResult> getPopularDestinations() {
    return [
      AddressSearchResult(
        formattedAddress: 'The Rotunda, University of Virginia, Charlottesville, VA',
        placeId: 'uva_rotunda',
        location: const LatLng(38.0356, -78.5034),
        mainText: 'The Rotunda',
        secondaryText: 'University of Virginia',
      ),
      AddressSearchResult(
        formattedAddress: 'Barracks Road Shopping Center, Charlottesville, VA',
        placeId: 'barracks_road',
        location: const LatLng(38.0481, -78.5264),
        mainText: 'Barracks Road Shopping Center',
        secondaryText: 'Shopping & Dining',
      ),
      AddressSearchResult(
        formattedAddress: 'Downtown Mall, Charlottesville, VA',
        placeId: 'downtown_mall',
        location: const LatLng(38.0293, -78.4767),
        mainText: 'Downtown Mall',
        secondaryText: 'Historic Pedestrian Mall',
      ),
      AddressSearchResult(
        formattedAddress: 'Charlottesville Albemarle Airport, Charlottesville, VA',
        placeId: 'cville_airport',
        location: const LatLng(38.1386, -78.4529),
        mainText: 'Charlottesville Airport',
        secondaryText: 'CHO Airport',
      ),
      AddressSearchResult(
        formattedAddress: 'UVA Health System, Charlottesville, VA',
        placeId: 'uva_hospital',
        location: const LatLng(38.0341, -78.4968),
        mainText: 'UVA Health System',
        secondaryText: 'University Hospital',
      ),
    ];
  }
}
