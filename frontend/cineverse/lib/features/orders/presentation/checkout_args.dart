import '../../seats/domain/entities/seat.dart';

/// Argumentos passados via `extra` da navegação do mapa de assentos para o
/// checkout — o `partnerId` só existe em `GET /sessions/nearby`, por isso
/// precisa ser carregado adiante em vez de buscado de novo. `movieId` e
/// `sessionDatetime` seguem pelo mesmo motivo, até a confirmação de compra
/// (FE-39): o pedido devolvido pelo servidor só traz `sessionId`.
class CheckoutArgs {
  const CheckoutArgs({
    required this.sessionId,
    required this.partnerId,
    required this.priceCentsPerSeat,
    required this.movieId,
    required this.sessionDatetime,
    required this.seats,
  });

  final int sessionId;
  final int partnerId;
  final int priceCentsPerSeat;
  final int movieId;
  final DateTime sessionDatetime;
  final List<Seat> seats;
}
