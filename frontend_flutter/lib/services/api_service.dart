import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Base API service providing HTTP methods with auth headers and error handling.
class ApiService {
  // Android emulator uses 10.0.2.2 to reach host localhost
  // For physical device, use your machine's IP address
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  /// Get stored access token from SharedPreferences.
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Save access token to SharedPreferences.
  static Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  /// Clear access token (for logout).
  static Future<void> clearAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  /// Build common headers with optional auth.
  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  /// Parse API error response into user-friendly message.
  static String _parseError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body.containsKey('detail')) {
        final detail = body['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          return detail.map((e) => e['msg'] ?? e.toString()).join(', ');
        }
      }
    } catch (_) {}
    return 'Something went wrong (${response.statusCode})';
  }

  /// HTTP GET request.
  static Future<ApiResponse> get(String path, {bool auth = false}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: await _headers(auth: auth),
      );
      return ApiResponse.fromResponse(response);
    } on SocketException {
      return ApiResponse(
        success: false,
        statusCode: 0,
        error: 'Cannot connect to server. Make sure the backend is running.',
      );
    } catch (e) {
      return ApiResponse(success: false, statusCode: 0, error: e.toString());
    }
  }

  /// HTTP POST request.
  static Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: await _headers(auth: auth),
        body: body != null ? jsonEncode(body) : null,
      );
      return ApiResponse.fromResponse(response);
    } on SocketException {
      return ApiResponse(
        success: false,
        statusCode: 0,
        error: 'Cannot connect to server. Make sure the backend is running.',
      );
    } catch (e) {
      return ApiResponse(success: false, statusCode: 0, error: e.toString());
    }
  }

  /// HTTP PUT request.
  static Future<ApiResponse> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$path'),
        headers: await _headers(auth: auth),
        body: body != null ? jsonEncode(body) : null,
      );
      return ApiResponse.fromResponse(response);
    } on SocketException {
      return ApiResponse(
        success: false,
        statusCode: 0,
        error: 'Cannot connect to server. Make sure the backend is running.',
      );
    } catch (e) {
      return ApiResponse(success: false, statusCode: 0, error: e.toString());
    }
  }

  /// HTTP DELETE request.
  static Future<ApiResponse> delete(String path, {bool auth = true}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$path'),
        headers: await _headers(auth: auth),
      );
      return ApiResponse.fromResponse(response);
    } on SocketException {
      return ApiResponse(
        success: false,
        statusCode: 0,
        error: 'Cannot connect to server. Make sure the backend is running.',
      );
    } catch (e) {
      return ApiResponse(success: false, statusCode: 0, error: e.toString());
    }
  }
}

/// Wrapper for API responses with success/error handling.
class ApiResponse {
  final bool success;
  final int statusCode;
  final Map<String, dynamic>? data;
  final String? error;

  ApiResponse({
    required this.success,
    required this.statusCode,
    this.data,
    this.error,
  });

  factory ApiResponse.fromResponse(http.Response response) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    Map<String, dynamic>? data;
    String? error;

    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        data = body;
      }
    } catch (_) {}

    if (!isSuccess) {
      error = ApiService._parseError(response);
    }

    return ApiResponse(
      success: isSuccess,
      statusCode: response.statusCode,
      data: data,
      error: error,
    );
  }
}

// =============================================================================
// AUTH API SERVICE
// =============================================================================

/// Authentication API methods matching backend /auth endpoints.
class AuthApiService {
  /// POST /auth/phone/send-otp
  /// Sends OTP to phone number for signup.
  /// Returns: { session_token, expires_at, message }
  static Future<ApiResponse> sendPhoneOtp(String phone) async {
    return ApiService.post('/auth/phone/send-otp', body: {'phone': phone});
  }

  /// POST /auth/phone/verify-otp
  /// Verifies phone OTP during signup.
  /// Returns: { phone_verified_token, phone, message }
  static Future<ApiResponse> verifyPhoneOtp(
    String sessionToken,
    String otp,
  ) async {
    return ApiService.post(
      '/auth/phone/verify-otp',
      body: {'session_token': sessionToken, 'otp': otp},
    );
  }

  /// POST /auth/register
  /// Creates new user after phone verification.
  /// Returns: { access_token, token_type, user: { ... } }
  static Future<ApiResponse> register({
    required String phoneVerifiedToken,
    required String fullName,
    required String gender,
    String? community,
  }) async {
    final body = <String, dynamic>{
      'phone_verified_token': phoneVerifiedToken,
      'full_name': fullName,
      'gender': gender,
    };
    if (community != null && community.isNotEmpty) {
      body['community'] = community;
    }
    return ApiService.post('/auth/register', body: body);
  }

  /// POST /auth/login/send-otp
  /// Sends OTP to registered phone for login.
  /// Returns: { session_token, expires_at, message }
  static Future<ApiResponse> loginSendOtp(String phone) async {
    return ApiService.post('/auth/login/send-otp', body: {'phone': phone});
  }

  /// POST /auth/login/verify-otp
  /// Verifies OTP for login.
  /// Returns: { access_token, token_type, user: { ... } }
  static Future<ApiResponse> loginVerifyOtp(
    String sessionToken,
    String otp,
  ) async {
    return ApiService.post(
      '/auth/login/verify-otp',
      body: {'session_token': sessionToken, 'otp': otp},
    );
  }
}

// =============================================================================
// RIDE API SERVICE
// =============================================================================

/// Ride API methods matching backend /rides endpoints.
class RideApiService {
  /// POST /rides — Create a new ride (driver).
  static Future<ApiResponse> createRide({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required String startAddress,
    required String endAddress,
    required String rideDate,
    required String rideTime,
    required int availableSeats,
    required String allowedGender,
    required String vehicleId,
    double? estimatedFare,
  }) async {
    return ApiService.post(
      '/rides/',
      auth: true,
      body: {
        'start_location': {'latitude': startLat, 'longitude': startLng},
        'end_location': {'latitude': endLat, 'longitude': endLng},
        'start_address': startAddress,
        'end_address': endAddress,
        'ride_date': rideDate,
        'ride_time': rideTime,
        'available_seats': availableSeats,
        'allowed_gender': allowedGender,
        'vehicle_id': vehicleId,
        if (estimatedFare != null) 'estimated_fare': estimatedFare,
      },
    );
  }

  /// GET /rides — List available rides.
  static Future<ApiResponse> listRides() async {
    return ApiService.get('/rides/', auth: true);
  }

  /// GET /rides/{rideId} — Get ride details.
  static Future<ApiResponse> getRide(String rideId) async {
    return ApiService.get('/rides/$rideId', auth: true);
  }

  /// PUT /rides/{rideId}/status — Update ride status.
  static Future<ApiResponse> updateRideStatus(
    String rideId,
    String status,
  ) async {
    return ApiService.put('/rides/$rideId/status', body: {'status': status});
  }

  /// POST /rides/{rideId}/request — Rider requests to join a ride.
  static Future<ApiResponse> requestJoinRide(
    String rideId, {
    double? pickupLat,
    double? pickupLng,
    String? pickupAddress,
  }) async {
    return ApiService.post(
      '/rides/$rideId/request',
      auth: true,
      body: {
        if (pickupLat != null) 'pickup_lat': pickupLat,
        if (pickupLng != null) 'pickup_lng': pickupLng,
        if (pickupAddress != null) 'pickup_address': pickupAddress,
      },
    );
  }

  /// GET /rides/{rideId}/requests — List pending requests (driver only).
  static Future<ApiResponse> getRideRequests(String rideId) async {
    return ApiService.get('/rides/$rideId/requests', auth: true);
  }

  /// PUT /rides/{rideId}/requests/{requestId} — Accept or reject a request.
  static Future<ApiResponse> handleRideRequest(
    String rideId,
    String requestId,
    String action,
  ) async {
    return ApiService.put(
      '/rides/$rideId/requests/$requestId',
      auth: true,
      body: {'action': action},
    );
  }

  /// POST /rides/{rideId}/verify-otp — Driver verifies pickup OTP.
  static Future<ApiResponse> verifyPickupOtp(
    String rideId,
    String otp, {
    String? participantId,
  }) async {
    return ApiService.post(
      '/rides/$rideId/verify-otp',
      auth: true,
      body: {
        'otp': otp,
        if (participantId != null) 'participant_id': participantId,
      },
    );
  }

  /// GET /rides/{rideId}/participants — List confirmed participants.
  static Future<ApiResponse> getRideParticipants(String rideId) async {
    return ApiService.get('/rides/$rideId/participants', auth: true);
  }

  /// GET /tracking/{rideId} — Get tracking info for live screen.
  static Future<ApiResponse> getTrackingInfo(String rideId) async {
    return ApiService.get('/tracking/$rideId', auth: true);
  }
}

// =============================================================================
// USER API SERVICE
// =============================================================================

/// User profile API methods matching backend /users endpoints.
class UserApiService {
  /// GET /users/me — Get current user profile.
  static Future<ApiResponse> getMyProfile() async {
    return ApiService.get('/users/me', auth: true);
  }

  /// PUT /users/me — Update user profile.
  static Future<ApiResponse> updateProfile({
    String? fullName,
    String? community,
    String? profilePhotoUrl,
    String? gender,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (community != null) body['community'] = community;
    if (profilePhotoUrl != null) body['profile_photo_url'] = profilePhotoUrl;
    if (gender != null) body['gender'] = gender;
    return ApiService.put('/users/me', auth: true, body: body);
  }
}

// =============================================================================
// VEHICLE API SERVICE
// =============================================================================

/// Vehicle API methods matching backend /vehicles endpoints.
class VehicleApiService {
  /// GET /vehicles — List current user's vehicles.
  static Future<ApiResponse> getMyVehicles() async {
    return ApiService.get('/vehicles/', auth: true);
  }

  /// POST /vehicles — Add a new vehicle.
  static Future<ApiResponse> addVehicle({
    required String vehicleType,
    required String vehicleNumber,
  }) async {
    return ApiService.post(
      '/vehicles/',
      auth: true,
      body: {'vehicle_type': vehicleType, 'vehicle_number': vehicleNumber},
    );
  }

  /// DELETE /vehicles/{vehicleId} — Delete a vehicle.
  static Future<ApiResponse> deleteVehicle(String vehicleId) async {
    return ApiService.delete('/vehicles/$vehicleId', auth: true);
  }
}

// =============================================================================
// DRIVER PROFILE API SERVICE
// =============================================================================

/// Driver profile API methods matching backend /driver-profiles endpoints.
class DriverProfileApiService {
  /// POST /driver-profiles — Create a driver profile.
  static Future<ApiResponse> createDriverProfile({
    required String vehicleId,
    required int dailySeatLimit,
  }) async {
    return ApiService.post(
      '/driver-profiles/',
      auth: true,
      body: {'vehicle_id': vehicleId, 'daily_seat_limit': dailySeatLimit},
    );
  }

  /// GET /driver-profiles/me — Get own driver profile.
  static Future<ApiResponse> getMyDriverProfile() async {
    return ApiService.get('/driver-profiles/me', auth: true);
  }

  /// PUT /driver-profiles/me — Update driver profile.
  static Future<ApiResponse> updateDriverProfile({
    String? vehicleId,
    int? dailySeatLimit,
    bool? isDriverActive,
  }) async {
    final body = <String, dynamic>{};
    if (vehicleId != null) body['vehicle_id'] = vehicleId;
    if (dailySeatLimit != null) body['daily_seat_limit'] = dailySeatLimit;
    if (isDriverActive != null) body['is_driver_active'] = isDriverActive;
    return ApiService.put('/driver-profiles/me', auth: true, body: body);
  }
}

// =============================================================================
// FARE API SERVICE
// =============================================================================

/// Fare API methods matching backend /fare endpoints.
class FareApiService {
  /// GET /fare/estimate — Estimate fare between two points.
  static Future<ApiResponse> estimateFare({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    int numRiders = 1,
  }) async {
    final query =
        '?start_lat=$startLat&start_lng=$startLng'
        '&end_lat=$endLat&end_lng=$endLng'
        '&num_riders=$numRiders';
    return ApiService.get('/fare/estimate$query', auth: false);
  }

  /// GET /fare/campus-matrix — Get full campus distance/fare matrix.
  static Future<ApiResponse> getCampusMatrix() async {
    return ApiService.get('/fare/campus-matrix', auth: false);
  }
}
