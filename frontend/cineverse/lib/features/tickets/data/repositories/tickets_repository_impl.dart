import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../domain/entities/ticket_validation.dart';
import '../../domain/tickets_repository.dart';
import '../tickets_api.dart';

class TicketsRepositoryImpl implements TicketsRepository {
  TicketsRepositoryImpl(this._ticketsApi, this._failureMapper);

  final TicketsApi _ticketsApi;
  final FailureMapper _failureMapper;

  @override
  Future<TicketValidation> validate(String qrCodePayload) async {
    try {
      final model = await _ticketsApi.validate(qrCodePayload);
      return model.toEntity();
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }
}
