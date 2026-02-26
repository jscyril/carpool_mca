import 'api_service.dart';

/// API service for all ride-lifecycle operations.
class RidesApiService {
  // ── List open rides ───────────────────────────────────────────────

  static Future<ApiResponse> listOpenRides() async {
    return ApiService.get('/rides/', auth: true);
  }

  // ── Get ride detail ───────────────────────────────────────────────

  static Future<ApiResponse> getRide(String rideId) async {
    return ApiService.get('/rides/$rideId', auth: true);
  }

  // ── Create ride (driver) ──────────────────────────────────────────

  static Future<ApiResponse> createRide({
    required String vehicleId,
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
    double? estimatedFare,
  }) async {
    return ApiService.post(
      '/rides/',
      auth: true,
      body: {
        'vehicle_id': vehicleId,
        'start_location': {'latitude': startLat, 'longitude': startLng},
        'end_location': {'latitude': endLat, 'longitude': endLng},
        'start_address': startAddress,
        'end_address': endAddress,
        'ride_date': rideDate,
        'ride_time': rideTime,
        'available_seats': availableSeats,
        'allowed_gender': allowedGender,
        'estimated_fare': estimatedFare,
      },
    );
  }

  // ── Request to join ride (passenger) ─────────────────────────────

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

  // ── List pending join requests (driver) ──────────────────────────

  static Future<ApiResponse> listRideRequests(String rideId) async {
    return ApiService.get('/rides/$rideId/requests', auth: true);
  }

  // ── Accept/reject request (driver) ───────────────────────────────

  static Future<ApiResponse> handleRideRequest(
    String rideId,
    String requestId,
    String action, // 'accept' or 'reject'
  ) async {
    return ApiService.put(
      '/rides/$rideId/requests/$requestId',
      auth: true,
      body: {'action': action},
    );
  }

  // ── Update ride status (driver) ───────────────────────────────────

  static Future<ApiResponse> updateRideStatus(
    String rideId,
    String status,
  ) async {
    return ApiService.put(
      '/rides/$rideId/status',
      auth: true,
      body: {'status': status},
    );
  }

  // ── Verify pickup OTP (driver) ───────────────────────────────────

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

  // ── List participants (driver / passenger) ────────────────────────

  static Future<ApiResponse> listParticipants(String rideId) async {
    return ApiService.get('/rides/$rideId/participants', auth: true);
  }

  // ── Live tracking (passenger polls every 5s) ─────────────────────

  static Future<ApiResponse> getTrackingInfo(String rideId) async {
    return ApiService.get('/tracking/$rideId', auth: true);
  }

  /// Post driver's current GPS location
  static Future<ApiResponse> updateDriverLocation(
    String rideId, {
    required double lat,
    required double lng,
  }) async {
    return ApiService.post(
      '/tracking/$rideId/location',
      auth: true,
      body: {'latitude': lat, 'longitude': lng},
    );
  }

  // ── Fare estimation ───────────────────────────────────────────────

  static Future<ApiResponse> estimateFare({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    int numRiders = 1,
  }) async {
    return ApiService.get(
      '/fare/estimate?start_lat=$startLat&start_lng=$startLng'
      '&end_lat=$endLat&end_lng=$endLng&num_riders=$numRiders',
      auth: true,
    );
  }

  /// Get campus distance/fare matrix
  static Future<ApiResponse> getCampusMatrix() async {
    return ApiService.get('/fare/campus-matrix', auth: false);
  }

  // ── Ratings ───────────────────────────────────────────────────────

  static Future<ApiResponse> submitRating(
    String rideId, {
    required String rateeId,
    required int rating,
    String? comment,
  }) async {
    return ApiService.post(
      '/ratings/',
      auth: true,
      body: {
        'ride_id': rideId,
        'ratee_id': rateeId,
        'rating': rating,
        if (comment != null) 'comment': comment,
      },
    );
  }

  // ── SOS ───────────────────────────────────────────────────────────

  static Future<ApiResponse> triggerSos(
    String rideId, {
    required double lat,
    required double lng,
  }) async {
    return ApiService.post(
      '/sos/trigger',
      auth: true,
      body: {
        'ride_id': rideId,
        'latitude': lat,
        'longitude': lng,
      },
    );
  }

  // ── Verification ──────────────────────────────────────────────────

  static Future<ApiResponse> sendEmailOtp(String email) async {
    return ApiService.post(
      '/verification/email/send-otp',
      auth: true,
      body: {'email': email},
    );
  }

  static Future<ApiResponse> verifyEmailOtp(
    String emailSessionToken,
    String otp,
  ) async {
    return ApiService.post(
      '/verification/email/verify-otp',
      auth: true,
      body: {'email_session_token': emailSessionToken, 'otp': otp},
    );
  }

  static Future<ApiResponse> submitIdentityVerification({
    required String documentUrl,
    String? collegeIdNumber,
  }) async {
    return ApiService.post(
      '/verification/identity/submit',
      auth: true,
      body: {
        'document_url': documentUrl,
        if (collegeIdNumber != null) 'college_id_number': collegeIdNumber,
      },
    );
  }

  static Future<ApiResponse> getIdentityStatus() async {
    return ApiService.get('/verification/identity/status', auth: true);
  }

  static Future<ApiResponse> submitDriverVerification({
    required String licenseDocumentUrl,
    String? licenseNumber,
  }) async {
    return ApiService.post(
      '/verification/driver/submit',
      auth: true,
      body: {
        'license_document_url': licenseDocumentUrl,
        if (licenseNumber != null) 'license_number': licenseNumber,
      },
    );
  }

  static Future<ApiResponse> getDriverVerificationStatus() async {
    return ApiService.get('/verification/driver/status', auth: true);
  }

  // ── User Profile ──────────────────────────────────────────────────

  static Future<ApiResponse> getMyProfile() async {
    return ApiService.get('/users/me', auth: true);
  }

  static Future<ApiResponse> updateMyProfile({
    String? fullName,
    String? email,
  }) async {
    return ApiService.put(
      '/users/me',
      auth: true,
      body: {
        if (fullName != null) 'full_name': fullName,
        if (email != null) 'email': email,
      },
    );
  }

  // ── Emergency Contacts ────────────────────────────────────────────

  static Future<ApiResponse> getEmergencyContacts() async {
    return ApiService.get('/emergency-contacts/', auth: true);
  }

  static Future<ApiResponse> addEmergencyContact({
    required String name,
    required String phone,
    String? relationship,
  }) async {
    return ApiService.post(
      '/emergency-contacts/',
      auth: true,
      body: {
        'name': name,
        'phone_number': phone,
        if (relationship != null) 'relationship': relationship,
      },
    );
  }

  static Future<ApiResponse> deleteEmergencyContact(String contactId) async {
    return ApiService.delete('/emergency-contacts/$contactId', auth: true);
  }

  // ── Vehicles ──────────────────────────────────────────────────────

  static Future<ApiResponse> getMyVehicles() async {
    return ApiService.get('/vehicles/', auth: true);
  }

  static Future<ApiResponse> addVehicle({
    required String vehicleNumber,
    required String vehicleType,
    required String model,
    String? color,
    int? seatingCapacity,
  }) async {
    return ApiService.post(
      '/vehicles/',
      auth: true,
      body: {
        'vehicle_number': vehicleNumber,
        'vehicle_type': vehicleType,
        'model': model,
        if (color != null) 'color': color,
        if (seatingCapacity != null) 'seating_capacity': seatingCapacity,
      },
    );
  }

  // ── Logout ────────────────────────────────────────────────────────

  static Future<void> logout() async {
    final refreshToken = await ApiService.getRefreshToken();
    if (refreshToken != null) {
      await ApiService.post(
        '/auth/logout',
        body: {'refresh_token': refreshToken},
      );
    }
    await ApiService.clearAll();
  }
}
