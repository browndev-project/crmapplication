class NearbyStaffUser {
  final String userId;
  final String name;
  final String? email;
  final String? phone;
  final double? lat;
  final double? lng;
  final double distance;
  final String? lastSeen;
  final String? systemRole;
  final String? lastAddress;

  NearbyStaffUser({
    required this.userId,
    required this.name,
    this.email,
    this.phone,
    this.lat,
    this.lng,
    required this.distance,
    this.lastSeen,
    this.systemRole,
    this.lastAddress,
  });

  factory NearbyStaffUser.fromJson(Map<String, dynamic> json) {
    // Robustly handle location which might be a Map or List
    final locationData = json['location'] ?? json['currentLocation'];
    final Map<String, dynamic>? location = locationData is Map<String, dynamic> ? locationData : null;
    final List? locationList = locationData is List ? locationData : null;
    
    final coords = location?['coordinates'] ?? locationList;
    
    double? latitude;
    double? longitude;

    if (coords is List && coords.length >= 2) {
      longitude = (coords[0] as num?)?.toDouble();
      latitude = (coords[1] as num?)?.toDouble();
    } else if (location != null) {
      latitude = (location['latitude'] ?? location['lat'])?.toDouble();
      longitude = (location['longitude'] ?? location['lng'])?.toDouble();
    }

    return NearbyStaffUser(
      userId: json['userId'] ?? json['_id'] ?? '',
      name: json['name'] ?? 'Unknown',
      email: json['email'],
      phone: json['phone'] ?? json['phoneNo'],
      lat: latitude,
      lng: longitude,
      distance: (json['distance'] ?? 0).toDouble(),
      lastSeen: json['lastSeen'],
      systemRole: json['systemRole'],
      lastAddress: location?['address'] ?? [location?['address1'], location?['city'], location?['state']].where((e) => e != null && e.toString().isNotEmpty).join(', '),
    );
  }
}

class StaffLocationUser {
  final String id;
  final String name;
  final String? email;
  final String? phoneNo;
  final String systemRole;
  final double? lat;
  final double? lng;
  final String? lastSeen;
  final String? groupName;
  final String? teamName;
  final String? lastAddress;

  StaffLocationUser({
    required this.id,
    required this.name,
    this.email,
    this.phoneNo,
    required this.systemRole,
    this.lat,
    this.lng,
    this.lastSeen,
    this.groupName,
    this.teamName,
    this.lastAddress,
  });

  factory StaffLocationUser.fromJson(Map<String, dynamic> json) {
    // Check both 'location' and 'currentLocation'
    final location = (json['location'] ?? json['currentLocation']) as Map<String, dynamic>?;
    final coords = location?['coordinates'];

    double? latitude;
    double? longitude;

    if (coords is List && coords.length >= 2) {
      // GeoJSON [lng, lat]
      longitude = (coords[0] as num?)?.toDouble();
      latitude = (coords[1] as num?)?.toDouble();
    } else if (coords is Map) {
      latitude = (coords['lat'] ?? coords['latitude'])?.toDouble();
      longitude = (coords['lng'] ?? coords['longitude'])?.toDouble();
    } else if (location != null) {
      latitude = (location['lat'] ?? location['latitude'])?.toDouble();
      longitude = (location['lng'] ?? location['longitude'])?.toDouble();
    }

    return StaffLocationUser(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'Unknown',
      email: json['email'],
      phoneNo: json['phoneNo'] ?? json['phone'],
      systemRole: json['systemRole'] ?? '',
      lat: latitude,
      lng: longitude,
      lastSeen: json['lastSeen'] ?? json['updatedAt'],
      groupName: json['group'] is Map ? json['group']['name'] : json['groupName'],
      teamName: json['team'] is Map ? json['team']['name'] : json['teamName'],
      lastAddress: location?['address'] ?? [location?['address1'], location?['city'], location?['state']].where((e) => e != null && e.toString().isNotEmpty).join(', '),
    );
  }
}
