import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/profile_repository.dart';
import '../profile_api.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._profileApi, this._tokenStorage, this._failureMapper);

  final ProfileApi _profileApi;
  final TokenStorage _tokenStorage;
  final FailureMapper _failureMapper;

  @override
  Future<UserProfile?> fetchProfile() async {
    try {
      final model = await _profileApi.fetchProfile();
      return model.toEntity();
    } on DioException catch (e) {
      final failure = _failureMapper.map(e);
      if (failure is NotFoundFailure) return null;
      throw failure;
    }
  }

  @override
  Future<UserProfile> updateFavoriteGenres(List<String> favoriteGenres) async {
    try {
      final model = await _profileApi.updateFavoriteGenres(favoriteGenres);
      return model.toEntity();
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }

  @override
  Future<String?> currentEmail() => _tokenStorage.readEmail();
}
